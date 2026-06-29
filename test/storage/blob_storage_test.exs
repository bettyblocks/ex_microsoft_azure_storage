defmodule ExMicrosoftAzureStorage.Storage.BlobStorageTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import ExMicrosoftAzureStorage.Factory

  alias ExMicrosoftAzureStorage.Storage.BlobStorage
  alias ExMicrosoftAzureStorage.Storage.BlobStorage.ServiceProperties

  @moduletag :external

  setup do
    storage_context = build(:storage_context)

    %{storage_context: storage_context}
  end

  describe "get_blob_service_stats" do
    test "gets blob service stats", %{storage_context: storage_context} do
      assert {:ok, %{geo_replication: %{last_sync_time: last_sync_time, status: "live"}}} =
               BlobStorage.get_blob_service_stats(storage_context)

      assert last_sync_time
    end
  end

  describe "get_blob_service_properties" do
    test "gets blob service properties", %{storage_context: storage_context} do
      assert {:ok, %{service_properties: %ServiceProperties{}}} =
               BlobStorage.get_blob_service_properties(storage_context)
    end
  end

  describe "put_blob_service_properties" do
    test "sets CORS rules", %{storage_context: storage_context} do
      rule = %{
        allowed_origins: ["https://google.com"],
        allowed_methods: ["GET"],
        max_age_in_seconds: 600,
        exposed_headers: [""],
        allowed_headers: [""]
      }

      cors_rule = ServiceProperties.CorsRule.to_struct(rule)

      {:ok, %{service_properties: service_properties}} = BlobStorage.get_blob_service_properties(storage_context)

      service_properties = Map.put(service_properties, :cors_rules, [cors_rule])

      BlobStorage.set_blob_service_properties(storage_context, service_properties)

      {:ok, %{service_properties: service_properties_after_update}} =
        BlobStorage.get_blob_service_properties(storage_context)

      assert service_properties == service_properties_after_update
    end
  end
end
