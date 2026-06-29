defmodule ExMicrosoftAzureStorage.Storage.Container do
  @moduledoc """
  Container
  """

  import ExMicrosoftAzureStorage.Storage.RequestBuilder
  import ExMicrosoftAzureStorage.Storage.Utilities, only: [to_bool: 1]
  import SweetXml

  alias ExMicrosoftAzureStorage.Storage
  alias ExMicrosoftAzureStorage.Storage.BlobPolicy
  alias ExMicrosoftAzureStorage.Storage.DateTimeUtils

  @type t :: %__MODULE__{container_name: String.t(), storage_context: map}

  @enforce_keys [:storage_context, :container_name]
  defstruct [:storage_context, :container_name]

  def new(%Storage{} = storage_context, container_name) when is_binary(container_name),
    do: %__MODULE__{storage_context: storage_context, container_name: container_name}

  defmodule Responses do
    @moduledoc false
    def list_containers_response,
      do: [
        max_results: ~x"/EnumerationResults/MaxResults/text()"s,
        next_marker: ~x"/EnumerationResults/NextMarker/text()"s,
        containers: [
          ~x"/EnumerationResults/Containers/Container"l,
          name: ~x"./Name/text()"s,
          properties: [
            ~x"./Properties",
            last_modified: transform_by(~x"./Last-Modified/text()"s, &DateTimeUtils.date_parse_rfc1123/1),
            e_tag: ~x"./Etag/text()"s,
            lease_status: ~x"./LeaseStatus/text()"s,
            lease_state: ~x"./LeaseState/text()"s,
            has_immutability_policy: transform_by(~x"./HasImmutabilityPolicy/text()"s, &to_bool/1),
            has_legal_hold: transform_by(~x"./HasLegalHold/text()"s, &to_bool/1)
          ]
        ]
      ]

    def list_blobs_response,
      do: [
        max_results: ~x"/EnumerationResults/MaxResults/text()"s,
        next_marker: ~x"/EnumerationResults/NextMarker/text()"s,
        blobs: [
          ~x"/EnumerationResults/Blobs/Blob"l,
          name: ~x"./Name/text()"s,
          tags: [~x"./Tags/TagSet/Tag"l, key: ~x"./Key/text()"s, value: ~x"./Value/text()"s],
          properties: [
            ~x"./Properties",
            etag: ~x"./Etag/text()"s,
            last_modified: transform_by(~x"./Last-Modified/text()"s, &DateTimeUtils.date_parse_rfc1123/1),
            content_length: ~x"./Content-Length/text()"i,
            content_type: ~x"./Content-Type/text()"s,
            content_encoding: ~x"./Content-Encoding/text()"s,
            content_language: ~x"./Content-Language/text()"s,
            content_md5: ~x"./Content-MD5/text()"s,
            content_disposition: ~x"./Content-Disposition/text()"s,
            cache_control: ~x"./Cache-Control/text()"s,
            blob_type: ~x"./BlobType/text()"s,
            access_tier: ~x"./AccessTier/text()"s,
            access_tier_inferred: transform_by(~x"./AccessTierInferred/text()"s, &to_bool/1),
            lease_status: ~x"./LeaseStatus/text()"s,
            lease_state: ~x"./LeaseState/text()"s,
            server_encrypted: transform_by(~x"./ServerEncrypted/text()"s, &to_bool/1)
          ]
        ]
      ]
  end

  def list_containers(%Storage{} = context) do
    # https://docs.microsoft.com/en-us/rest/api/storageservices/list-containers2
    response =
      context
      |> new_azure_storage_request()
      |> method(:get)
      |> url("/")
      |> add_param(:query, :comp, "list")
      |> sign_and_call(:blob_service)

    case response do
      %{status: status} when 400 <= status and status < 500 ->
        {:error, create_error_response(response)}

      %{status: 200} ->
        {:ok, create_success_response(response, xml_body_parser: &Responses.list_containers_response/0)}
    end
  end

  def create_container(%__MODULE__{storage_context: context, container_name: container_name}) do
    # https://docs.microsoft.com/en-us/rest/api/storageservices/create-container
    response =
      context
      |> new_azure_storage_request()
      |> method(:put)
      |> url("/#{container_name}")
      |> add_param(:query, :restype, "container")
      |> sign_and_call(:blob_service)

    case response do
      %{status: status} when 400 <= status and status < 500 ->
        {:error, create_error_response(response)}

      %{status: 201} ->
        {:ok, create_success_response(response)}
    end
  end

  @doc """
  Returns an existing container if found or creates a new one if not.
  """
  def ensure_container(container) do
    case create_container(container) do
      {:ok, %{status: 201} = response} -> {:ok, response}
      {:error, %{error_code: "ContainerAlreadyExists"} = response} -> {:ok, response}
      other -> other
    end
  end

  def get_container_properties(%__MODULE__{storage_context: context, container_name: container_name}) do
    # https://docs.microsoft.com/en-us/rest/api/storageservices/get-container-properties
    response =
      context
      |> new_azure_storage_request()
      |> method(:get)
      |> url("/#{container_name}")
      |> add_param(:query, :restype, "container")
      |> sign_and_call(:blob_service)

    case response do
      %{status: status} when 400 <= status and status < 500 ->
        {:error, create_error_response(response)}

      %{status: 200} ->
        {:ok, create_success_response(response)}
    end
  end

  def get_container_metadata(%__MODULE__{storage_context: context, container_name: container_name}) do
    # https://docs.microsoft.com/en-us/rest/api/storageservices/get-container-metadata

    response =
      context
      |> new_azure_storage_request()
      |> method(:head)
      |> url("/#{container_name}")
      |> add_param(:query, :restype, "container")
      |> add_param(:query, :comp, "metadata")
      |> sign_and_call(:blob_service)

    case response do
      %{status: status} when 400 <= status and status < 500 ->
        {:error, create_error_response(response)}

      %{status: 200} ->
        {:ok, create_success_response(response)}
    end
  end

  def get_container_acl(%__MODULE__{storage_context: context, container_name: container_name}) do
    # https://docs.microsoft.com/en-us/rest/api/storageservices/get-container-acl

    response =
      context
      |> new_azure_storage_request()
      |> method(:get)
      |> url("/#{container_name}")
      |> add_param(:query, :restype, "container")
      |> add_param(:query, :comp, "acl")
      |> sign_and_call(:blob_service)

    case response do
      %{status: status} when 400 <= status and status < 500 ->
        {:error, create_error_response(response)}

      %{status: 200} ->
        {:ok,
         response
         |> create_success_response()
         |> Map.put(:policies, process_body(response.body, [], &BlobPolicy.deserialize/1))}
    end
  end

  def set_container_acl_public_access_off(%__MODULE__{} = container), do: set_container_acl(container, :off)

  def set_container_acl_public_access_blob(%__MODULE__{} = container), do: set_container_acl(container, :blob)

  def set_container_acl_public_access_container(%__MODULE__{} = container), do: set_container_acl(container, :container)

  defp container_access_level_to_string(:off), do: nil
  defp container_access_level_to_string(:blob), do: "blob"
  defp container_access_level_to_string(:container), do: "container"

  def parse_access_level(nil), do: :off
  def parse_access_level("blob"), do: :blob
  def parse_access_level("container"), do: :container

  def set_container_acl(%__MODULE__{storage_context: context, container_name: container_name}, access_level)
      when is_atom(access_level) and access_level in [:off, :blob, :container] do
    # https://docs.microsoft.com/en-us/rest/api/storageservices/set-container-acl#remarks

    response =
      context
      |> new_azure_storage_request()
      |> method(:put)
      |> url("/#{container_name}")
      |> add_param(:query, :restype, "container")
      |> add_param(:query, :comp, "acl")
      |> add_header_if(
        container_access_level_to_string(access_level) != nil,
        "x-ms-blob-public-access",
        container_access_level_to_string(access_level)
      )
      |> sign_and_call(:blob_service)

    case response do
      %{status: status} when 400 <= status and status < 500 ->
        {:error, create_error_response(response)}

      %{status: 200} ->
        {:ok, create_success_response(response)}
    end
  end

  def set_container_acl(%__MODULE__{storage_context: context, container_name: container_name}, access_policies)
      when is_list(access_policies) do
    # https://docs.microsoft.com/en-us/rest/api/storageservices/set-container-acl#remarks

    response =
      context
      |> new_azure_storage_request()
      |> method(:put)
      |> url("/#{container_name}")
      |> add_param(:query, :restype, "container")
      |> add_param(:query, :comp, "acl")
      |> add_header("Content-Type", "application/xml")
      |> body(BlobPolicy.serialize(access_policies))
      |> sign_and_call(:blob_service)

    case response do
      %{status: status} when 400 <= status and status < 500 ->
        {:error, create_error_response(response)}

      %{status: 200} ->
        {:ok, create_success_response(response)}
    end
  end

  def delete_container(%__MODULE__{storage_context: context, container_name: container_name}) do
    # https://docs.microsoft.com/en-us/rest/api/storageservices/delete-container
    response =
      context
      |> new_azure_storage_request()
      |> method(:delete)
      |> url("/#{container_name}")
      |> add_param(:query, :restype, "container")
      |> sign_and_call(:blob_service)

    case response do
      %{status: status} when 400 <= status and status < 500 ->
        {:error, create_error_response(response)}

      %{status: 202} ->
        {:ok, create_success_response(response)}
    end
  end

  def list_blobs(
        %__MODULE__{storage_context: context, container_name: container_name},
        opts \\ [prefix: nil, delimiter: nil, marker: nil, maxresults: nil, timeout: nil, include: nil]
      ) do
    # https://docs.microsoft.com/en-us/rest/api/storageservices/list-blobs

    response =
      context
      |> new_azure_storage_request()
      |> method(:get)
      |> url("/#{container_name}")
      |> add_param(:query, :comp, "list")
      |> add_param(:query, :restype, "container")
      |> add_param_if(opts[:prefix] != nil, :query, :prefix, opts[:prefix])
      |> add_param_if(opts[:delimiter] != nil, :query, :delimiter, opts[:delimiter])
      |> add_param_if(opts[:marker] != nil, :query, :marker, opts[:marker])
      |> add_param_if(opts[:maxresults] != nil, :query, :maxresults, opts[:maxresults])
      |> add_param_if(opts[:timeout] != nil, :query, :timeout, opts[:timeout])
      |> add_param_if(opts[:include] != nil, :query, :include, opts[:include])
      |> sign_and_call(:blob_service)

    case response do
      %{status: status} when 400 <= status and status < 500 ->
        {:error, create_error_response(response)}

      %{status: 200} ->
        {:ok, create_success_response(response, xml_body_parser: &Responses.list_blobs_response/0)}
    end
  end

  defp process_body(nil, default_value, _process_fn), do: default_value
  defp process_body("", default_value, _process_fn), do: default_value
  defp process_body(body, _default_value, process_fn), do: process_fn.(body)
end
