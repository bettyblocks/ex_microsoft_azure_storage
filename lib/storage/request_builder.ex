defmodule ExMicrosoftAzureStorage.Storage.RequestBuilder do
  @moduledoc """
  RequestBuilder
  """

  import ExMicrosoftAzureStorage.Storage.Utilities, only: [to_bool: 1]
  import SweetXml

  alias ExMicrosoftAzureStorage.Storage
  alias ExMicrosoftAzureStorage.Storage.ApiVersion
  alias ExMicrosoftAzureStorage.Storage.Container
  alias ExMicrosoftAzureStorage.Storage.DateTimeUtils
  alias ExMicrosoftAzureStorage.Storage.RestClient

  defp json_library, do: Application.get_env(:azure, :json_library, Jason)

  def new_azure_storage_request(%Storage{} = storage), do: %{storage_context: storage}

  def method(request, m), do: Map.put_new(request, :method, m)

  def url(request, u), do: Map.put_new(request, :url, u)

  def body(request, body) do
    request
    |> add_header("Content-Length", "#{byte_size(body)}")
    |> Map.put(:body, body)
  end

  def add_header_content_md5(request) do
    body = Map.get(request, :body)
    md5 = :md5 |> :crypto.hash(body) |> Base.encode64()

    add_header(request, "Content-MD5", md5)
  end

  def add_header_if(request, false, _k, _v), do: request
  def add_header_if(request, true, k, v), do: add_header(request, k, v)

  # request |> Map.update!(:headers, &Map.merge(&1, headers))
  def add_header(%{headers: headers} = request, k, v) when headers != nil,
    do: Map.put(request, :headers, [{k, v} | headers])

  def add_header(request, k, v), do: Map.put(request, :headers, [{k, v}])

  def has_header?(%{headers: headers}, k), do: List.keymember?(headers, k, 0)
  def has_header?(_request, _k), do: false

  @prefix_x_ms_meta "x-ms-meta-"

  def add_header_x_ms_meta(request, %{} = kvp),
    do: Enum.reduce(kvp, request, fn {k, v}, r -> add_header(r, @prefix_x_ms_meta <> k, v) end)

  def add_optional_params(request, _, []), do: request

  def add_optional_params(request, definitions, [{key, value} | tail]) do
    case definitions do
      %{^key => location} ->
        request
        |> add_param(location, key, value)
        |> add_optional_params(definitions, tail)

      _ ->
        add_optional_params(request, definitions, tail)
    end
  end

  def add_param_if(request, false, _location, _key, _value), do: request

  def add_param_if(request, true, location, key, value), do: add_param(request, location, key, value)

  def add_param(request, :body, :body, value), do: Map.put(request, :body, value)

  def add_param(request, :body, key, value) do
    request
    |> Map.put_new_lazy(:body, &Tesla.Multipart.new/0)
    |> Map.update!(
      :body,
      &Tesla.Multipart.add_field(
        &1,
        key,
        json_library().encode!(value),
        headers: [{:"Content-Type", "application/json"}]
      )
    )
  end

  def add_param(request, :file, name, path) do
    request
    |> Map.put_new_lazy(:body, &Tesla.Multipart.new/0)
    |> Map.update!(:body, &Tesla.Multipart.add_file(&1, path, name: name))
  end

  def add_param(request, :form, name, value) do
    Map.update(request, :body, %{name => value}, &Map.put(&1, name, value))
  end

  def add_param(request, location, key, value) do
    Map.update(request, location, [{key, value}], &(&1 ++ [{key, value}]))
  end

  def add_param(request, :query, opts) when is_list(opts) do
    filtered_opts = only_non_empty_values(opts)

    new_q =
      case request[:query] do
        nil -> filtered_opts
        query -> query ++ filtered_opts
      end

    Map.put(request, :query, new_q)
  end

  defp only_non_empty_values(opts) when is_list(opts),
    do: opts |> Enum.filter(fn {_, value} -> value != nil && value != "" end) |> Enum.to_list()

  defp primary(account_name), do: String.replace(account_name, "-secondary", "")

  defp canonicalized_headers(headers) do
    headers
    |> Enum.map(fn {k, v} -> {String.downcase(k), v} end)
    |> Enum.filter(fn {k, _} -> String.starts_with?(k, "x-ms-") end)
    |> Enum.sort()
    |> Enum.map_join("\n", fn {k, v} -> "#{k}:#{v}" end)
  end

  def remove_empty_headers(%{headers: headers} = request) when is_list(headers) do
    new_headers =
      Enum.filter(headers, fn {_k, v} -> v != nil && String.length(v) > 0 end)

    Map.put(request, :headers, new_headers)
  end

  defp get_header(headers, name) do
    case for {k, v} <- headers, k == name, do: v do
      [result] -> result
      [] -> nil
    end
  end

  # https://docs.microsoft.com/en-us/rest/api/storageservices/authentication-for-the-azure-storage-services
  defp protect(
         %{
           method: method,
           url: url,
           query: query,
           headers: headers,
           storage_context:
             %Storage{is_development_factory: is_development_factory, account_key: account_key, aad_token_provider: nil} =
               storage_context
         } = data
       )
       when is_binary(account_key) and account_key != nil do
    canonicalized_headers = canonicalized_headers(headers)

    url =
      if is_development_factory do
        "/devstoreaccount1#{url}"
      else
        url
      end

    canonicalized_resource =
      case query do
        [] ->
          "/#{primary(storage_context.account_name)}#{url}"

        _ ->
          "/#{primary(storage_context.account_name)}#{url}\n" <>
            (query
             |> Enum.sort_by(& &1)
             |> Enum.map_join("\n", fn {k, v} -> "#{k}:#{v}" end))
      end

    string_to_sign =
      Enum.join(
        [
          method |> Atom.to_string() |> String.upcase(),
          get_header(headers, "Content-Encoding"),
          get_header(headers, "Content-Language"),
          get_header(headers, "Content-Length"),
          get_header(headers, "Content-MD5"),
          get_header(headers, "Content-Type"),
          get_header(headers, "Date"),
          get_header(headers, "If-Modified-Since"),
          get_header(headers, "If-Match"),
          get_header(headers, "If-None-Match"),
          get_header(headers, "If-Unmodified-Since"),
          get_header(headers, "Range"),
          canonicalized_headers,
          canonicalized_resource
        ],
        "\n"
      )

    signature =
      :sha256
      |> Storage.Crypto.hmac(Base.decode64!(account_key), string_to_sign)
      |> Base.encode64()

    add_header(data, "Authorization", "SharedKey #{primary(storage_context.account_name)}:#{signature}")
  end

  defp protect(
         %{storage_context: %Storage{account_key: nil, aad_token_provider: aad_token_provider}, uri: uri} = request
       ) do
    token =
      uri
      |> trim_uri_for_aad_request()
      |> aad_token_provider.()

    add_header(request, "Authorization", "Bearer #{token}")
  end

  defp trim_uri_for_aad_request(uri) when is_binary(uri) do
    %URI{host: host, scheme: scheme} = URI.parse(uri)

    "#{scheme}://#{host}"
  end

  def sign_and_call(%{storage_context: %Storage{} = storage_context} = request, service)
      when is_atom(service) and service in [:blob_service, :queue_service, :table_service] do
    uri = Storage.endpoint_url(storage_context, service)

    connection = RestClient.new(uri)

    add_content_type_header? = request.method == :put && !has_header?(request, "Content-Type")

    request
    |> add_header_if(add_content_type_header?, "Content-Type", "application/octet-stream")
    |> add_header("x-ms-date", DateTimeUtils.utc_now())
    |> add_header("x-ms-version", ApiVersion.get_api_version(:storage))
    |> remove_empty_headers()
    |> add_missing(:query, [])
    |> Map.put(:uri, uri)
    |> protect()
    |> Enum.to_list()
    |> then(&RestClient.request(connection, &1))
    |> elem(1)
  end

  def add_missing(map, key, value) do
    case map do
      %{^key => _} -> map
      %{} -> Map.put(map, key, value)
    end
  end

  defmodule Responses do
    @moduledoc false
    def error_response,
      do: [
        error_code: ~x"/Error/Code/text()"s,
        error_message: ~x"/Error/Message/text()"s,
        authentication_error_detail: ~x"/Error/AuthenticationErrorDetail/text()"s,
        query_parameter_name: ~x"/Error/QueryParameterName/text()"s,
        query_parameter_value: ~x"/Error/QueryParameterValue/text()"s
      ]
  end

  def identity(x), do: x

  def create_error_response(%{} = response) do
    response
    |> create_success_response(xml_body_parser: &__MODULE__.Responses.error_response/0)
    |> Map.update(:error_message, "", &String.split(&1, "\n"))
  end

  def create_success_response(response, opts \\ []) do
    Map.new()
    |> Map.put(:request_url, response.url)
    |> Map.put(:status, response.status)
    |> Map.put(:headers, response.headers)
    |> Map.put(:body, response.body)
    |> copy_response_headers_into_map()
    |> copy_x_ms_meta_headers_into_map()
    |> parse_body_and_update_response(opts)
  end

  defp parse_body_and_update_response(%{body: ""} = response, _), do: response

  defp parse_body_and_update_response(%{body: body} = response, opts) do
    case Keyword.get(opts, :xml_body_parser) do
      nil ->
        response

      xml_parser when is_function(xml_parser) ->
        Map.merge(response, xmap(body, xml_parser.()))
    end
  end

  @response_headers [
    {"Date", :date, &DateTimeUtils.date_parse_rfc1123/1},
    {"Last-Modified", :last_modified, &DateTimeUtils.date_parse_rfc1123/1},
    {"Expires", :expires, &DateTimeUtils.date_parse_rfc1123/1},
    {"ETag", :etag},
    {"Content-MD5", :content_md5},
    {"x-ms-client-request-id", :x_ms_client_request_id},
    {"x-ms-request-id", :x_ms_request_id},
    {"x-ms-lease-state", :x_ms_lease_state},
    {"x-ms-blob-type", :x_ms_blob_type},
    {"x-ms-lease-status", :x_ms_lease_status},
    {"x-ms-request-server-encrypted", :x_ms_request_server_encrypted, &to_bool/1},
    {"x-ms-delete-type-permanent", :x_ms_delete_type_permanent},
    {"x-ms-has-immutability-policy", :x_ms_has_immutability_policy, &to_bool/1},
    {"x-ms-has-legal-hold", :x_ms_has_legal_hold, &to_bool/1},
    {"x-ms-approximate-messages-count", :x_ms_approximate_messages_count, &String.to_integer/1},
    {"x-ms-error-code", :x_ms_error_code},
    {"x-ms-blob-public-access", :x_ms_blob_public_access, &Container.parse_access_level/1},
    {"x-ms-blob-cache-control", :x_ms_blob_cache_control},
    {"x-ms-cache-control", :x_ms_cache_control},
    {"x-ms-copy-status", :x_ms_copy_status}
  ]

  defp copy_response_headers_into_map(%{} = response) do
    Enum.reduce(@response_headers, response, fn x, response ->
      copy_response_header_into_map(response, x)
    end)
  end

  defp copy_response_header_into_map(response, {http_header, key_to_set}),
    do: copy_response_header_into_map(response, {http_header, key_to_set, &identity/1})

  defp copy_response_header_into_map(response, {http_header, key_to_set, transform})
       when is_map(response) and is_atom(key_to_set) and is_binary(http_header) and is_function(transform, 1) do
    http_header = String.downcase(http_header)

    case get_header(response.headers, http_header) do
      nil -> response
      val -> Map.put(response, key_to_set, transform.(val))
    end
  end

  defp copy_x_ms_meta_headers_into_map(response) do
    x_ms_meta =
      response.headers
      |> Enum.filter(fn {k, _v} -> String.starts_with?(k, @prefix_x_ms_meta) end)
      |> Map.new(fn {@prefix_x_ms_meta <> k, v} -> {k, v} end)

    if Enum.empty?(x_ms_meta) do
      response
    else
      Map.put(response, :x_ms_meta, x_ms_meta)
    end
  end
end
