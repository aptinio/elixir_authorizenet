defmodule AuthorizeNetTest do
  use ExUnit.Case
  use Servito
  use AuthorizeNet.Test.Util
  use AuthorizeNet.Helper.XML
  require Logger

  setup do
    :ok
  end

  test "can raise connection error on network issues" do
    assert_raise AuthorizeNet.Error.Connection, &AuthorizeNet.Customer.get_all/0
  end

  test "can raise request error on server issues" do
    start_server fn(_bindings, _headers, _body, req, state) ->
      ret 404, [], "blah"
    end
    assert_raise AuthorizeNet.Error.Connection, &AuthorizeNet.Customer.get_all/0
    stop_server
  end

  test "can raise operation error on bad request" do
    start_server fn(_bindings, _headers, _body, req, state) ->
      serve_file "bad_auth"
    end
    assert_raise AuthorizeNet.Error.Operation, &AuthorizeNet.Customer.get_all/0
    stop_server
  end

  test "can send credentials" do
    request_assert "customer_profiles_get_all", "getCustomerProfileIdsRequest",
      fn() -> AuthorizeNet.Customer.get_all end,
      fn(body, msgs) ->
        msgs = if xml_find(body, "//merchantAuthentication") === [] do
          ["missing auth section"|msgs]
        else
          msgs
        end
        assert_fields body, msgs, [
          {"name", "login_id"},
          {"transactionKey", "transaction_key"}
        ]
      end,
      fn(result) -> assert [35934704] === result end
  end

  test "can get all customer profiles" do
    request_assert "customer_profiles_get_all", "getCustomerProfileIdsRequest",
      fn() -> AuthorizeNet.Customer.get_all end,
      fn(_body, msgs) -> msgs end,
      fn(result) -> assert [35934704] === result end
  end

  test "can get customer profile" do
    request_assert "customer_profile_get", "getCustomerProfileRequest",
      fn() -> AuthorizeNet.Customer.get 35934704 end,
      fn(body, msgs) ->
        assert_fields body, msgs, [{"customerProfileId", "35934704"}]
      end,
      fn(result) ->
        assert %AuthorizeNet.Customer{
          description: "description",
          email: "email2@host.com",
          id: "merchantId",
          profile_id: 35934704
        } === result
      end
  end

  test "cant get inexistant profile" do
    start_server fn(_bindings, _headers, _body, req, state) ->
      serve_file "get_inexistant_customer_profile"
    end
    try do
      AuthorizeNet.Customer.get 35934705
      flunk "expected to fail"
    rescue
      e in AuthorizeNet.Error.Operation ->
        assert e.message === [{"E00040", "The record cannot be found."}]
    end
    stop_server
  end

  test "can create customer profile" do
    request_assert "create_customer_profile", "createCustomerProfileRequest",
      fn() ->
        AuthorizeNet.Customer.create "merchantId", "description", "email@host.com"
      end,
      fn(body, msgs) ->
        assert_fields body, msgs, [
          {"merchantCustomerId", "merchantId"},
          {"description", "description"},
          {"email", "email@host.com"}
        ]
      end,
      fn(result) ->
        assert %AuthorizeNet.Customer{
          profile_id: 35934704,
          id: "merchantId",
          description: "description",
          email: "email@host.com"
        } === result
      end
  end

  test "cant create duplicated customer profile" do
    start_server fn(_bindings, _headers, _body, req, state) ->
      serve_file "create_duplicated_customer_profile"
    end
    try do
      AuthorizeNet.Customer.create "merchantId", "description", "email@host.com"
      flunk "expected to fail"
    rescue
      e in AuthorizeNet.Error.Operation ->
        assert e.message === [{"E00039", "A duplicate record with ID 35938239 already exists."}]
    end
    stop_server
  end

  test "can update customer profile" do
    request_assert "update_customer_profile", "updateCustomerProfileRequest",
      fn() ->
        AuthorizeNet.Customer.update(
          35934704, "merchantId2", "description2", "email2@host.com"
        )
      end,
      fn(body, msgs) ->
        assert_fields body, msgs, [
          {"description", "description2"},
          {"email", "email2@host.com"},
          {"merchantCustomerId", "merchantId2"},
          {"customerProfileId", "35934704"}
        ]
      end,
      fn(result) ->
        assert %AuthorizeNet.Customer{
          id: "merchantId2",
          description: "description2",
          email: "email2@host.com",
          profile_id: 35934704
        } === result
      end
  end

  test "can delete customer profile" do
    request_assert "delete_customer_profile", "deleteCustomerProfileRequest",
      fn() -> AuthorizeNet.Customer.delete 35934704 end,
      fn(body, msgs) ->
        assert_fields body, msgs, [{"customerProfileId", "35934704"}]
      end,
      fn(result) -> assert result === :ok end
  end

  test "can create invidual credit card payment profile" do
    address = AuthorizeNet.Address.new(
      "street", "city", "state", "zip", "country", "phone", "fax"
    )
    card = AuthorizeNet.Card.new "5424000000000015", "2015-08", "900"

    request_assert "create_payment_profile", "createCustomerPaymentProfileRequest",
      fn() ->
        AuthorizeNet.PaymentProfile.create_individual(
          35938239, "first", "last", "company", address, card
        )
      end,
      fn(body, msgs) ->
        assert_fields body, msgs, [
          {"cardCode", "900"},
          {"expirationDate", "2015-08"},
          {"cardNumber", "5424000000000015"},
          {"faxNumber", "fax"},
          {"phoneNumber", "phone"},
          {"country", "country"},
          {"zip", "zip"},
          {"state", "state"},
          {"city", "city"},
          {"address", "street"},
          {"company", "company"},
          {"lastName", "last"},
          {"firstName", "first"},
          {"customerType", "individual"},
          {"customerProfileId", "35938239"}
        ]
      end,
      fn(result) ->
        assert %AuthorizeNet.PaymentProfile{
          profile_id: 32500845,
          customer_id: 35938239,
          address: address,
          type: :individual,
          payment_type: card,
          company: "company",
          first_name: "first",
          last_name: "last"
        } === result
      end
  end

  test "can create business credit card payment profile" do
    address = AuthorizeNet.Address.new(
      "street", "city", "state", "zip", "country", "phone", "fax"
    )
    card = AuthorizeNet.Card.new "5424000000000015", "2015-08", "900"

    request_assert "create_payment_profile", "createCustomerPaymentProfileRequest",
      fn() ->
        AuthorizeNet.PaymentProfile.create_business(
          35938239, "first", "last", "company", address, card
        )
      end,
      fn(body, msgs) ->
        assert_fields body, msgs, [
          {"cardCode", "900"},
          {"expirationDate", "2015-08"},
          {"cardNumber", "5424000000000015"},
          {"faxNumber", "fax"},
          {"phoneNumber", "phone"},
          {"country", "country"},
          {"zip", "zip"},
          {"state", "state"},
          {"city", "city"},
          {"address", "street"},
          {"company", "company"},
          {"lastName", "last"},
          {"firstName", "first"},
          {"customerType", "business"},
          {"customerProfileId", "35938239"}
        ]
      end,
      fn(result) ->
        assert %AuthorizeNet.PaymentProfile{
          profile_id: 32500845,
          customer_id: 35938239,
          address: address,
          type: :business,
          payment_type: card,
          company: "company",
          first_name: "first",
          last_name: "last"
        } === result
      end
  end

  test "cant create account with invalid echeck type" do
    assert_raise ArgumentError, fn() ->
      AuthorizeNet.BankAccount.savings(
        "bank", "111", "222", "name", :whatever
      )
    end
  end

  test "can create savings bank account payment profile" do
    address = AuthorizeNet.Address.new(
      "street", "city", "state", "zip", "country", "phone", "fax"
    )
    account = AuthorizeNet.BankAccount.savings(
      "bank", "111", "222", "name", :ccd
    )

    request_assert "create_payment_profile", "createCustomerPaymentProfileRequest",
      fn() ->
        AuthorizeNet.PaymentProfile.create_individual(
          35938239, "first", "last", "company", address, account
        )
      end,
      fn(body, msgs) ->
        assert_fields body, msgs, [
          {"bankName", "bank"},
          {"echeckType", "CCD"},
          {"nameOnAccount", "name"},
          {"accountNumber", "222"},
          {"routingNumber", "111"},
          {"accountType", "savings"},
          {"country", "country"},
          {"zip", "zip"},
          {"state", "state"},
          {"city", "city"},
          {"address", "street"},
          {"company", "company"},
          {"lastName", "last"},
          {"firstName", "first"},
          {"customerType", "individual"},
          {"customerProfileId", "35938239"}
        ]
      end,
      fn(result) ->
        assert %AuthorizeNet.PaymentProfile{
          profile_id: 32500845,
          customer_id: 35938239,
          address: address,
          type: :individual,
          payment_type: account,
          company: "company",
          first_name: "first",
          last_name: "last"
        } === result
      end
  end

  test "can create checking bank account payment profile" do
    address = AuthorizeNet.Address.new(
      "street", "city", "state", "zip", "country", "phone", "fax"
    )
    account = AuthorizeNet.BankAccount.checking(
      "bank", "111", "222", "name", :web
    )

    request_assert "create_payment_profile", "createCustomerPaymentProfileRequest",
      fn() ->
        AuthorizeNet.PaymentProfile.create_individual(
          35938239, "first", "last", "company", address, account
        )
      end,
      fn(body, msgs) ->
        assert_fields body, msgs, [
          {"bankName", "bank"},
          {"echeckType", "WEB"},
          {"nameOnAccount", "name"},
          {"accountNumber", "222"},
          {"routingNumber", "111"},
          {"accountType", "checking"},
          {"country", "country"},
          {"zip", "zip"},
          {"state", "state"},
          {"city", "city"},
          {"address", "street"},
          {"company", "company"},
          {"lastName", "last"},
          {"firstName", "first"},
          {"customerType", "individual"},
          {"customerProfileId", "35938239"}
        ]
      end,
      fn(result) ->
        assert %AuthorizeNet.PaymentProfile{
          profile_id: 32500845,
          customer_id: 35938239,
          address: address,
          type: :individual,
          payment_type: account,
          company: "company",
          first_name: "first",
          last_name: "last"
        } === result
      end
  end

  test "can create business checking bank account payment profile" do
    address = AuthorizeNet.Address.new(
      "street", "city", "state", "zip", "country", "phone", "fax"
    )
    account = AuthorizeNet.BankAccount.business_checking(
      "bank", "111", "222", "name", :ppd
    )

    request_assert "create_payment_profile", "createCustomerPaymentProfileRequest",
      fn() ->
        AuthorizeNet.PaymentProfile.create_individual(
          35938239, "first", "last", "company", address, account
        )
      end,
      fn(body, msgs) ->
        assert_fields body, msgs, [
          {"bankName", "bank"},
          {"echeckType", "PPD"},
          {"nameOnAccount", "name"},
          {"accountNumber", "222"},
          {"routingNumber", "111"},
          {"accountType", "businessChecking"},
          {"country", "country"},
          {"zip", "zip"},
          {"state", "state"},
          {"city", "city"},
          {"address", "street"},
          {"company", "company"},
          {"lastName", "last"},
          {"firstName", "first"},
          {"customerType", "individual"},
          {"customerProfileId", "35938239"}
        ]
      end,
      fn(result) ->
        assert %AuthorizeNet.PaymentProfile{
          profile_id: 32500845,
          customer_id: 35938239,
          address: address,
          type: :individual,
          payment_type: account,
          company: "company",
          first_name: "first",
          last_name: "last"
        } === result
      end
  end

  defp assert_fields(xml, msgs, fields) do
    Enum.reduce fields, msgs, fn({k, v}, acc) ->
      if xml_value(xml, "//#{k}") === [v] do
          acc
      else
        ["wrong #{k}"|acc]
      end
    end
  end

  defp request_assert(
    file, request_type, request_fun, server_asserts_fun, client_asserts_fun
  ) do
    me = self
    start_server fn(_bindings, _headers, body, req, state) ->
      msgs = []
      msgs = case validate body do
        {:error, error} -> ["invalid schema: #{inspect error}"|msgs]
        :ok -> msgs
      end
      msgs = if xml_find(body, "//#{request_type}") === [] do
        ["missing request section"|msgs]
      else
        msgs
      end
      msgs = server_asserts_fun.(body, msgs)
      send me, msgs
      serve_file file
    end
    result = request_fun.()
    stop_server
    receive do
      [] -> client_asserts_fun.(result)
      x -> flunk "Something went wrong with the request: #{inspect x}"
    end
  end
end
