defmodule ExMicrosoftAzureStorage.Storage.Queue do
  @moduledoc """
  Queue
  """

  import ExMicrosoftAzureStorage.Storage.RequestBuilder
  import SweetXml

  alias __MODULE__.Responses
  alias ExMicrosoftAzureStorage.Storage
  alias ExMicrosoftAzureStorage.Storage.DateTimeUtils

  @enforce_keys [:storage_context, :queue_name]
  defstruct [:storage_context, :queue_name]

  def new(%Storage{} = storage_context, queue_name) when is_binary(queue_name),
    do: %__MODULE__{storage_context: storage_context, queue_name: queue_name}

  defmodule Responses do
    @moduledoc false
    def put_message_response do
      [
        message_id: ~x"/QueueMessagesList/QueueMessage/MessageId/text()"s,
        pop_receipt: ~x"/QueueMessagesList/QueueMessage/PopReceipt/text()"s,
        insertion_time:
          transform_by(~x"/QueueMessagesList/QueueMessage/InsertionTime/text()"s, &DateTimeUtils.date_parse_rfc1123/1),
        expiration_time:
          transform_by(~x"/QueueMessagesList/QueueMessage/ExpirationTime/text()"s, &DateTimeUtils.date_parse_rfc1123/1),
        time_next_visible:
          transform_by(~x"/QueueMessagesList/QueueMessage/TimeNextVisible/text()"s, &DateTimeUtils.date_parse_rfc1123/1)
      ]
    end

    def get_message_response do
      [
        message_id: ~x"/QueueMessagesList/QueueMessage/MessageId/text()"s,
        pop_receipt: ~x"/QueueMessagesList/QueueMessage/PopReceipt/text()"s,
        insertion_time:
          transform_by(~x"/QueueMessagesList/QueueMessage/InsertionTime/text()"s, &DateTimeUtils.date_parse_rfc1123/1),
        expiration_time:
          transform_by(~x"/QueueMessagesList/QueueMessage/ExpirationTime/text()"s, &DateTimeUtils.date_parse_rfc1123/1),
        time_next_visible:
          transform_by(~x"/QueueMessagesList/QueueMessage/TimeNextVisible/text()"s, &DateTimeUtils.date_parse_rfc1123/1),
        dequeue_count: ~x"/QueueMessagesList/QueueMessage/DequeueCount/text()"s,
        message_text: transform_by(~x"/QueueMessagesList/QueueMessage/MessageText/text()"s, &Base.decode64!/1)
      ]
    end
  end

  def create_queue(%__MODULE__{storage_context: context, queue_name: queue_name}, opts \\ []) do
    # https://docs.microsoft.com/en-us/rest/api/storageservices/create-queue4

    #
    # QueueStorage.create_queue(queue, meta: %{"a" => "b", "c" => "d"})
    #
    # x-ms-meta-a: b
    # x-ms-meta-c: d
    #

    %{timeout: timeout, meta: meta} =
      case [timeout: 0, meta: %{}]
           |> Keyword.merge(opts)
           |> Map.new() do
        %{timeout: timeout, meta: meta} when 0 <= timeout and timeout <= 30 and is_map(meta) ->
          %{timeout: timeout, meta: meta}
      end

    response =
      context
      |> new_azure_storage_request()
      |> method(:put)
      |> url("/#{queue_name}")
      |> add_param_if(timeout > 0, :query, :timeout, timeout)
      |> add_header_x_ms_meta(meta)
      |> sign_and_call(:queue_service)

    case response do
      %{status: status} when 400 <= status and status < 500 ->
        {:error, create_error_response(response)}

      %{status: status} when status == 201 or status == 204 ->
        {:ok, create_success_response(response)}
    end
  end

  def delete_queue(%__MODULE__{storage_context: context, queue_name: queue_name}, opts \\ []) do
    # https://docs.microsoft.com/en-us/rest/api/storageservices/delete-queue3
    %{timeout: timeout} =
      case [timeout: 0]
           |> Keyword.merge(opts)
           |> Map.new() do
        %{timeout: timeout} when 0 <= timeout and timeout <= 30 -> %{timeout: timeout}
      end

    response =
      context
      |> new_azure_storage_request()
      |> method(:delete)
      |> url("/#{queue_name}")
      |> add_param_if(timeout > 0, :query, :timeout, timeout)
      |> sign_and_call(:queue_service)

    case response do
      %{status: status} when 400 <= status and status < 500 ->
        {:error, create_error_response(response)}

      %{status: status} when status == 201 or status == 204 ->
        {:ok, create_success_response(response)}
    end
  end

  def get_metadata(%__MODULE__{storage_context: context, queue_name: queue_name}, opts \\ []) do
    # https://docs.microsoft.com/en-us/rest/api/storageservices/get-queue-metadata

    %{timeout: timeout} =
      case [timeout: 0]
           |> Keyword.merge(opts)
           |> Map.new() do
        %{timeout: timeout} when 0 <= timeout and timeout <= 30 -> %{timeout: timeout}
      end

    response =
      context
      |> new_azure_storage_request()
      |> method(:get)
      |> url("/#{queue_name}")
      |> add_param(:query, :comp, "metadata")
      |> add_param_if(timeout > 0, :query, :timeout, timeout)
      |> sign_and_call(:queue_service)

    case response do
      %{status: status} when 400 <= status and status < 500 ->
        {:error, create_error_response(response)}

      %{status: 200} ->
        {:ok, create_success_response(response)}
    end
  end

  def set_queue_metadata(%__MODULE__{storage_context: context, queue_name: queue_name}, opts \\ []) do
    # https://docs.microsoft.com/en-us/rest/api/storageservices/set-queue-metadata

    #
    # QueueStorage.set_queue_metadata(queue, timeout: 3, meta: %{"a" => "b", "c" => "d"})
    #
    # x-ms-meta-a: b
    # x-ms-meta-c: d
    #

    %{timeout: timeout, meta: meta} =
      case [timeout: 0, meta: %{}]
           |> Keyword.merge(opts)
           |> Map.new() do
        %{timeout: timeout, meta: meta} when 0 <= timeout and timeout <= 30 and is_map(meta) ->
          %{timeout: timeout, meta: meta}
      end

    response =
      context
      |> new_azure_storage_request()
      |> method(:put)
      |> url("/#{queue_name}")
      |> add_param(:query, :comp, "metadata")
      |> add_param_if(timeout > 0, :query, :timeout, timeout)
      |> add_header_x_ms_meta(meta)
      |> sign_and_call(:queue_service)

    case response do
      %{status: status} when 400 <= status and status < 500 ->
        {:error, create_error_response(response)}

      %{status: status} when status == 201 or status == 204 ->
        {:ok, create_success_response(response)}
    end
  end

  @seconds_7_days 7 * 24 * 60 * 60

  def put_message(%__MODULE__{storage_context: context, queue_name: queue_name}, message, opts \\ [])
      when is_binary(message) do
    # https://docs.microsoft.com/en-us/rest/api/storageservices/put-message

    opts_with_default =
      [visibilitytimeout: 0, messagettl: 0]
      |> Keyword.merge(opts)
      |> Map.new()

    %{
      visibilitytimeout: visibilitytimeout,
      messagettl: messagettl
    } = visibility_timeout(opts_with_default)

    body = "<QueueMessage><MessageText>#{Base.encode64(message)}</MessageText></QueueMessage>"

    response =
      context
      |> new_azure_storage_request()
      |> method(:post)
      |> url("/#{queue_name}/messages")
      |> add_param_if(visibilitytimeout > 0, :query, :visibilitytimeout, visibilitytimeout)
      |> add_param_if(messagettl != 0, :query, :messagettl, messagettl)
      |> body(body)
      |> sign_and_call(:queue_service)

    case response do
      %{status: status} when 400 <= status and status < 500 ->
        {:error, create_error_response(response)}

      %{status: 201} ->
        {:ok, create_success_response(response, xml_body_parser: &Responses.put_message_response/0)}
    end
  end

  defp visibility_timeout(%{visibilitytimeout: visibilitytimeout, messagettl: messagettl})
       when visibilitytimeout >= 0 and visibilitytimeout <= @seconds_7_days and
              (messagettl == -1 or messagettl == 0 or (messagettl >= 1 and messagettl <= @seconds_7_days)) do
    %{
      visibilitytimeout: visibilitytimeout,
      messagettl: messagettl
    }
  end

  defp visibility_timeout(_) do
    raise ArgumentError,
      message: "Invalid visibility timeout given it should be within the range of 0 - #{@seconds_7_days} seconds."
  end

  def get_message(%__MODULE__{storage_context: context, queue_name: queue_name}, opts \\ []) do
    # https://docs.microsoft.com/en-us/rest/api/storageservices/get-messages

    opts_defaults = [numofmessages: 1, visibilitytimeout: 30, timeout: 0]

    %{
      numofmessages: numofmessages,
      visibilitytimeout: visibilitytimeout,
      timeout: timeout
    } =
      case opts_defaults
           |> Keyword.merge(opts)
           |> Map.new() do
        %{
          numofmessages: numofmessages,
          visibilitytimeout: visibilitytimeout,
          timeout: timeout
        }
        when is_integer(numofmessages) and numofmessages >= 1 and numofmessages <= 32 and
               (visibilitytimeout >= 1 and visibilitytimeout <= @seconds_7_days) ->
          %{
            numofmessages: numofmessages,
            visibilitytimeout: visibilitytimeout,
            timeout: timeout
          }
      end

    response =
      context
      |> new_azure_storage_request()
      |> method(:get)
      |> url("/#{queue_name}/messages")
      |> add_param_if(
        numofmessages != Keyword.get(opts_defaults, :numofmessages),
        :query,
        :numofmessages,
        numofmessages
      )
      |> add_param_if(
        visibilitytimeout != Keyword.get(opts_defaults, :visibilitytimeout),
        :query,
        :visibilitytimeout,
        visibilitytimeout
      )
      |> add_param_if(
        timeout != Keyword.get(opts_defaults, :timeout),
        :query,
        :timeout,
        timeout
      )
      |> sign_and_call(:queue_service)

    case response do
      %{status: status} when 400 <= status and status < 500 ->
        {:error, create_error_response(response)}

      %{status: 200} ->
        {
          :ok,
          create_success_response(response, xml_body_parser: &Responses.get_message_response/0)
        }
    end
  end

  def delete_message(%__MODULE__{storage_context: context, queue_name: queue_name}, popreceipt, timeout \\ 30) do
    # https://docs.microsoft.com/en-us/rest/api/storageservices/delete-message2

    response =
      context
      |> new_azure_storage_request()
      |> method(:delete)
      |> url("/#{queue_name}/messages/messageid")
      |> add_param(:query, :popreceipt, popreceipt)
      |> add_param(:query, :timeout, timeout)
      |> sign_and_call(:queue_service)

    case response do
      %{status: status} when 400 <= status and status < 500 ->
        {:error, create_error_response(response)}

      %{status: 204} ->
        {:ok, create_success_response(response)}
    end
  end

  def clear_messages(%__MODULE__{storage_context: context, queue_name: queue_name}, timeout \\ 30) do
    # https://docs.microsoft.com/en-us/rest/api/storageservices/clear-messages

    response =
      context
      |> new_azure_storage_request()
      |> method(:delete)
      |> url("/#{queue_name}/messages")
      |> add_param(:query, :timeout, timeout)
      |> sign_and_call(:queue_service)

    case response do
      %{status: status} when 400 <= status and status < 500 ->
        {:error, create_error_response(response)}

      %{status: 204} ->
        {:ok, create_success_response(response)}
    end
  end
end
