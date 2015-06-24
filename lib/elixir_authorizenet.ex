defmodule AuthorizeNet do
  @moduledoc """
  Handles API requests and responses.
  """
  use AuthorizeNet.Helper.XML
  alias AuthorizeNet.Helper.Http, as: Http
  alias AuthorizeNet.Error.Connection, as: RequestError
  alias AuthorizeNet.Error.Connection, as: ConnectionError
  alias AuthorizeNet.Error.Operation, as: OperationError
  require Logger

  @uris sandbox: "https://apitest.authorize.net/xml/v1/request.api",
    production: "https://api.authorize.net/xml/v1/request.api"

  @doc """
  Makes a request to the Authorize.Net API. Adds authentication and parses
  response. On success will return an xmlElement record. See:
  http://www.erlang.org/doc/apps/xmerl/xmerl_ug.html

  @raises AuthorizeNet.OperationError,
    AuthorizeNet.ConnectionError,
    AuthorizeNet.RequestError
  """
  @spec req(Atom, Keyword.t) :: Record | no_return
  def req(requestType, parameters) do
    body = [{
      requestType,
      %{xmlns: "AnetApi/xml/v1/schema/AnetApiSchema.xsd"},
      [{:merchantAuthentication, auth}|parameters]
    }]
    case Http.req :post, uri, body do
      {:ok, 200, _headers, <<0xEF, 0xBB, 0xBF, body :: binary>>} ->
        {doc, _} = Exmerl.from_string body
        [result] = xml_value doc, "//messages/resultCode"
        if result === "Error" do
          codes = xml_value doc, "//code"
          texts = xml_value doc, "//text"
          raise OperationError, message: Enum.zip(codes, texts)
        end
        doc
      {:ok, status, headers, body} ->
        raise RequestError, message: {status, headers, body}
      error ->
        raise ConnectionError, message: error
    end
  end

  @doc """
  See: http://www.authorize.net/support/CIM_XML_guide.pdf under the section
  called "The validationMode Parameter".
  """
  @spec validation_mode() :: String.t
  def validation_mode() do
    case config :validation_mode do
      :live -> "liveMode"
      :test -> "testMode"
      :none -> "none"
    end
  end

  defp auth() do
    [name: login_id, transactionKey: transaction_key]
  end

  defp login_id() do
    config :login_id
  end

  defp transaction_key() do
    config :transaction_key
  end

  defp uri() do
    if Mix.env === :test do
      config :test_server_uri
    else
      @uris[config(:environment)]
    end
  end

  defp config(key) do
    Application.get_env :authorize_net, key
  end
end
