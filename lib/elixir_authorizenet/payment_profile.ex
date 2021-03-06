defmodule AuthorizeNet.PaymentProfile do
  @moduledoc """
  Handles customer payment profiles (http://developer.authorize.net/api/reference/index.html#manage-customer-profiles-create-customer-payment-profile).

  Copyright 2015 Marcelo Gornstein <marcelog@gmail.com>

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
  """
  use AuthorizeNet.Helper.XML
  alias AuthorizeNet.Address, as: Address
  alias AuthorizeNet.Card, as: Card
  alias AuthorizeNet.BankAccount, as: BankAccount
  alias AuthorizeNet, as: Main

  defstruct address: nil,
    customer_id: nil,
    type: nil,
    payment_type: nil,
    profile_id: nil

  @profile_type [
    individual: "individual",
    business: "business"
  ]

  @type t :: %AuthorizeNet.PaymentProfile{}
  @type payment_type :: BankAccount.t | Card.t
  @type profile_type :: :individual | :business

  @doc """
  Validates a payment profile by generating a test transaction. See:
  http://developer.authorize.net/api/reference/index.html#manage-customer-profiles-validate-customer-payment-profile
  """
  @spec valid?(Integer, Integer, String.t | nil) :: true | {false, term}
  def valid?(customer_id, profile_id, card_code \\ nil) do
    try do
      Main.req :validateCustomerPaymentProfileRequest, [
        customerProfileId: customer_id,
        customerPaymentProfileId: profile_id,
        cardCode: card_code,
        validationMode: Main.validation_mode
      ]
      true
    rescue
      e -> {false, e}
    end
  end

  @doc """
  Returns a Payment Profile. See:
  http://developer.authorize.net/api/reference/index.html#manage-customer-profiles-get-customer-payment-profile
  """
  @spec get(
    Integer, Integer, Keyword.t
  ) :: AuthorizeNet.PaymentProfile.t | no_return
  def get(customer_id, profile_id, options \\ []) do
    unmask_expiration_date = Enum.member? options, :unmask_expiration_date
    doc = Main.req :getCustomerPaymentProfileRequest, [
      customerProfileId: customer_id,
      customerPaymentProfileId: profile_id,
      unmaskExpirationDate: unmask_expiration_date
    ]
    from_xml doc, customer_id
  end

  @doc """
  Returns all payment profiles matching the given criteria. See:
  http://developer.authorize.net/api/reference/#customer-profiles-get-customer-payment-profile-list
  """
  @spec get_list(
    String.t, String.t, String.t, boolean, Integer, Integer
  ) :: [AuthorizeNet.PaymentProfile.t] | no_return
  def get_list(search_type, month, order_by, order_desc, limit, offset) do
    doc = Main.req :getCustomerPaymentProfileListRequest, [
      searchType: search_type,
      month: month,
      sorting: [
        orderBy: order_by,
        orderDescending: to_string(order_desc)
      ],
      paging: [
        limit: limit,
        offset: offset
      ]
    ]
    profiles = xml_find doc, ~x"//paymentProfile"l
    for p <- profiles do
      customer_id = xml_one_value_int p, "//customerProfileId"
      from_xml p, customer_id
    end
  end

  @doc """
  Deletes a Payment Profile. See:
  http://developer.authorize.net/api/reference/index.html#manage-customer-profiles-delete-customer-payment-profile
  """
  @spec delete(Integer, Integer) :: :ok | no_return
  def delete(customer_id, profile_id) do
    Main.req :deleteCustomerPaymentProfileRequest, [
      customerProfileId: customer_id,
      customerPaymentProfileId: profile_id
    ]
    :ok
  end

  @doc """
  Creates a payment profile for an "invidual". See:
  http://developer.authorize.net/api/reference/index.html#manage-customer-profiles-create-customer-payment-profile
  """
  @spec create_individual(
    Integer, AuthorizeNet.Address.t, AuthorizeNet.PaymentProfile.payment_type
  ) :: AuthorizeNet.PaymentProfile.t | no_return
  def create_individual(customer_id, address, payment_type) do
    create :individual, customer_id, nil, address, payment_type
  end

  @doc """
  Creates a payment profile for a "business". See:
  http://developer.authorize.net/api/reference/index.html#manage-customer-profiles-create-customer-payment-profile
  """
  @spec create_business(
    Integer, Address.t, AuthorizeNet.PaymentProfile.payment_type
  )  :: AuthorizeNet.PaymentProfile.t | no_return
  def create_business(customer_id, address, payment_type) do
    create :business, customer_id, nil, address, payment_type
  end

  @spec create(
    String.t, Integer, Integer,
    Address.t, AuthorizeNet.PaymentProfile.payment_type
  ) :: AuthorizeNet.PaymentProfile.t | no_return
  defp create(type, customer_id, profile_id, address, payment_type) do
    profile = new type, customer_id, profile_id, address, payment_type
    xml = to_xml profile
    doc = Main.req :createCustomerPaymentProfileRequest, xml
    profile_id = xml_one_value_int doc, "//customerPaymentProfileId"
    %AuthorizeNet.PaymentProfile{profile | profile_id: profile_id}
  end

  @spec new(
    String.t, Integer, Integer,
    Address.t, AuthorizeNet.PaymentProfile.payment_type
  ) :: AuthorizeNet.PaymentProfile.t | no_return
  defp new(type, customer_id, profile_id, address, payment_type) do
    case payment_type do
      %BankAccount{} -> :ok
      %Card{} -> :ok
      _ -> raise ArgumentError, "Only AuthorizeNet.BankAccount and " <>
        "AuthorizeNet.Card are supported as a payment_type"
    end
    %AuthorizeNet.PaymentProfile{
      type: type,
      address: address,
      customer_id: customer_id,
      payment_type: payment_type,
      profile_id: profile_id
    }
  end

  defp to_xml(profile) do
    payment = case profile.payment_type do
      %BankAccount{} -> BankAccount.to_xml profile.payment_type
      %Card{} -> Card.to_xml profile.payment_type
    end
    [
      customerProfileId: profile.customer_id,
      paymentProfile: [
        customerType: profile.type,
        billTo: Address.to_xml(profile.address),
        payment: payment
      ],
      validationMode: Main.validation_mode
    ]
  end

  @doc """
  Builds an PaymentProfile from an xmlElement record.
  """
  @spec from_xml(Record, Integer) :: AuthorizeNet.PaymentProfile.t
  def from_xml(doc, customer_id \\ nil) do
    type = case xml_one_value(doc, "//customerType") do
      nil -> nil
      type ->
        [{type, _}] = Enum.filter @profile_type, fn({_k, v}) ->
          v === type
        end
        type
    end
    payment = case xml_find doc, ~x"//creditCard"l do
      [] -> BankAccount.from_xml doc
      _ -> Card.from_xml doc
    end
    address = case xml_find doc, ~x"//billTo"l do
      [] -> nil
      _ -> Address.from_xml doc, customer_id
    end
    id = xml_one_value_int doc, "//customerPaymentProfileId"
    new(
      type,
      customer_id,
      id,
      address,
      payment
    )
  end
end