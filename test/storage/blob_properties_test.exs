defmodule ExMicrosoftAzureStorage.Storage.BlobPropertiesTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias ExMicrosoftAzureStorage.Storage.BlobProperties

  describe "deserialise" do
    test "deserialises blob properties from headers" do
      headers = [
        {"server", "Azurite-Blob/3.11.0"},
        {"last-modified", "Mon, 12 Jul 2021 18:18:21 GMT"},
        {"x-ms-creation-time", "Mon, 12 Jul 2021 18:18:21 GMT"},
        {"x-ms-blob-type", "BlockBlob"},
        {"x-ms-lease-state", "available"},
        {"x-ms-lease-status", "unlocked"},
        {"content-length", "12"},
        {"content-type", "application/octet-stream"},
        {"etag", "\"0x198B53AAAB848F0\""},
        {"content-md5", "h/Fps4ugBcqAcVVmEmMG/w=="},
        {"x-ms-request-id", "f7022735-4acd-49b1-ae93-de9389874274"},
        {"x-ms-version", "2020-06-12"},
        {"date", "Mon, 12 Jul 2021 18:18:21 GMT"},
        {"accept-ranges", "bytes"},
        {"x-ms-server-encrypted", "true"},
        {"x-ms-access-tier", "Hot"},
        {"x-ms-access-tier-inferred", "true"},
        {"x-ms-access-tier-change-time", "Mon, 12 Jul 2021 18:18:21 GMT"},
        {"connection", "keep-alive"},
        {"keep-alive", "timeout=5"},
        {"x-ms-meta-x-frame-options", "DENY"},
        {"x-ms-meta-content-security-policy", "default-src 'self'"},
        {"x-ms-meta-enable-cors-protection", "true"}
      ]

      expected = %BlobProperties{
        accept_ranges: "bytes",
        access_tier: "Hot",
        access_tier_change_time: ~U[2021-07-12 18:18:21Z],
        access_tier_inferred: true,
        archive_status: nil,
        blob_committed_block_count: nil,
        blob_sealed: nil,
        blob_sequence_number: nil,
        blob_server_encrypted: nil,
        blob_type: "BlockBlob",
        cache_control: nil,
        content_disposition: nil,
        content_encoding: nil,
        content_language: nil,
        content_length: 12,
        content_md5: "h/Fps4ugBcqAcVVmEmMG/w==",
        content_type: "application/octet-stream",
        copy_completion_time: nil,
        copy_destination_snapshot: nil,
        copy_id: nil,
        copy_progress: nil,
        copy_source: nil,
        copy_status: nil,
        copy_status_description: nil,
        creation_time: ~U[2021-07-12 18:18:21Z],
        encryption_key_sha256: nil,
        encryption_scope: nil,
        etag: "\"0x198B53AAAB848F0\"",
        incremental_copy: nil,
        last_access_time: nil,
        last_modified: ~U[2021-07-12 18:18:21Z],
        lease_duration: nil,
        lease_state: "available",
        lease_status: "unlocked",
        meta: [
          {"x-frame-options", "DENY"},
          {"content-security-policy", "default-src 'self'"},
          {"enable-cors-protection", "true"}
        ],
        rehydrate_priority: nil,
        tag_count: nil
      }

      assert ^expected = headers |> BlobProperties.deserialise()
    end
  end

  describe "serialise" do
    test "serialises blob properties to headers" do
      properties = %BlobProperties{
        cache_control: nil,
        content_type: "application/octet-stream",
        content_length: 12,
        meta: [
          {"x-frame-options", "DENY"},
          {"content-security-policy", "default-src 'self'"},
          {"enable-cors-protection", "true"}
        ]
      }

      expected = [
        {"content-type", "application/octet-stream"},
        {"content-length", "12"},
        {"x-ms-meta-x-frame-options", "DENY"},
        {"x-ms-meta-content-security-policy", "default-src 'self'"},
        {"x-ms-meta-enable-cors-protection", "true"}
      ]

      assert ^expected = properties |> BlobProperties.serialise()
    end
  end
end
