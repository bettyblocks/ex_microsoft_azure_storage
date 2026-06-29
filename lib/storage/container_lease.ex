defmodule ExMicrosoftAzureStorage.Storage.ContainerLease do
  @moduledoc """
  ContainerLease
  """

  import ExMicrosoftAzureStorage.Storage.RequestBuilder

  alias ExMicrosoftAzureStorage.Storage.Container

  # "x-ms-lease-action" acquire/renew/change/release/break
  # "x-ms-lease-id"     Required for renew/change/release
  # "x-ms-lease-break-period"  optional 0..60
  # "x-ms-lease-duration" required for acquire. -1, 15..60
  # "x-ms-proposed-lease-id" Optional for acquire, required for change
  defp container_lease_handler(
         %Container{storage_context: context, container_name: container_name},
         expected_status_code,
         fn_prepare_request,
         fn_prepare_response
       ) do
    # https://docs.microsoft.com/en-us/rest/api/storageservices/lease-container

    response =
      context
      |> new_azure_storage_request()
      |> method(:put)
      |> url("/#{container_name}")
      |> add_param(:query, :comp, "lease")
      |> add_param(:query, :restype, "container")
      |> fn_prepare_request.()
      |> sign_and_call(:blob_service)

    case response do
      %{status: status} when 400 <= status and status < 500 ->
        {:error, create_error_response(response)}

      %{status: ^expected_status_code} ->
        {:ok,
         response
         |> create_success_response()
         |> fn_prepare_response.(response)}
    end
  end

  defp pass_result_as_is(result, _response), do: result

  # AcquireLease TimeSpan? leaseTime, string proposedLeaseId
  def container_lease_acquire(%Container{} = container, lease_duration, proposed_lease_id \\ nil)
      when is_integer(lease_duration) and (lease_duration == -1 or lease_duration in 15..60) do
    # https://docs.microsoft.com/en-us/rest/api/storageservices/lease-container

    fn_prepare_request = fn request ->
      request
      |> add_header("x-ms-lease-action", "acquire")
      |> add_header("x-ms-lease-duration", "#{lease_duration}")
      |> add_header("x-ms-proposed-lease-id", "#{proposed_lease_id}")
    end

    container_lease_handler(container, 201, fn_prepare_request, &pass_result_as_is/2)
  end

  # RenewLease
  def container_lease_renew(%Container{} = container, lease_id) do
    # https://docs.microsoft.com/en-us/rest/api/storageservices/lease-container

    fn_prepare_request = fn request ->
      request
      |> add_header("x-ms-lease-action", "renew")
      |> add_header("x-ms-lease-id", "#{lease_id}")
    end

    container_lease_handler(container, 200, fn_prepare_request, &pass_result_as_is/2)
  end

  # BreakLease   TimeSpan? breakPeriod
  def container_lease_break(%Container{} = container, lease_id, break_period \\ -1)
      when is_integer(break_period) and break_period in -1..60 do
    # https://docs.microsoft.com/en-us/rest/api/storageservices/lease-container

    fn_prepare_request = fn request ->
      request
      |> add_header("x-ms-lease-action", "break")
      |> add_header("x-ms-lease-id", "#{lease_id}")
      |> add_header("x-ms-lease-break-period", "#{break_period}")
    end

    fn_prepare_response = fn result, response ->
      Map.put(result, :lease_time, response.headers["x-ms-lease-time"] |> Integer.parse() |> elem(0))
    end

    container_lease_handler(container, 202, fn_prepare_request, fn_prepare_response)
  end

  # ReleaseLease
  def container_lease_release(%Container{} = container, lease_id) do
    # https://docs.microsoft.com/en-us/rest/api/storageservices/lease-container#remarks

    fn_prepare_request = fn request ->
      request
      |> add_header("x-ms-lease-action", "release")
      |> add_header("x-ms-lease-id", "#{lease_id}")
    end

    container_lease_handler(container, 200, fn_prepare_request, &pass_result_as_is/2)
  end

  # ChangeLease string proposedLeaseId,
  def container_lease_change(%Container{} = container, lease_id, proposed_lease_id) do
    # https://docs.microsoft.com/en-us/rest/api/storageservices/lease-container#remarks

    fn_prepare_request = fn request ->
      request
      |> add_header("x-ms-lease-action", "release")
      |> add_header("x-ms-lease-id", "#{lease_id}")
      |> add_header("x-ms-proposed-lease-id", "#{proposed_lease_id}")
    end

    container_lease_handler(container, 200, fn_prepare_request, &pass_result_as_is/2)
  end
end
