defmodule ExMicrosoftAzureStorage.Storage.BlobTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import ExMicrosoftAzureStorage.Factory

  alias ExMicrosoftAzureStorage.Storage.Blob
  alias ExMicrosoftAzureStorage.Storage.BlobProperties
  alias ExMicrosoftAzureStorage.Storage.Container

  @moduletag :external

  defp header(headers, key) do
    case List.keyfind(headers, key, 0) do
      nil -> nil
      {^key, value} -> value
    end
  end

  setup do
    storage_context = build(:storage_context)
    container_context = Container.new(storage_context, "blob-test")

    Container.delete_container(container_context)

    {:ok, _response} = Container.ensure_container(container_context)

    %{storage_context: storage_context, container_context: container_context}
  end

  describe "blob properties" do
    setup %{container_context: container_context} do
      blob_name = build(:blob_name)
      blob_data = build(:blob_data)
      blob = Blob.new(container_context, blob_name)

      Blob.delete_blob(blob)
      {:ok, %{status: 201}} = Blob.put_blob(blob, blob_data)

      %{blob: blob, container_context: container_context}
    end

    test "gets blob properties", %{blob: blob} do
      assert {:ok, %{status: 200, properties: %BlobProperties{}}} = Blob.get_blob_properties(blob)
    end

    test "error when blob not found", %{container_context: container_context} do
      blob_name = build(:blob_name)
      blob = Blob.new(container_context, blob_name)

      assert {:error, %{status: 404}} = Blob.get_blob_properties(blob)
    end

    test "set blob properties", %{blob: blob} do
      content_type = build(:content_type)
      content_md5 = build(:content_md5)

      {:ok, %{status: 200, properties: blob_properties}} = Blob.get_blob_properties(blob)

      refute blob_properties.content_type == content_type

      blob_properties =
        blob_properties
        |> Map.put(:content_type, content_type)
        |> Map.put(:content_md5, content_md5)

      assert {:ok, %{status: 200}} = Blob.set_blob_properties(blob, blob_properties)

      assert {:ok, %{status: 200, properties: blob_properties}} = Blob.get_blob_properties(blob)

      assert blob_properties.content_type == content_type
      assert blob_properties.content_md5 == content_md5
    end
  end

  describe "put_blob" do
    test "puts a blob", %{container_context: container_context} do
      blob_name = "my_blob"
      blob_data = "my_blob_data"
      blob = Blob.new(container_context, blob_name)

      assert {:ok, %{status: 201}} = Blob.put_blob(blob, blob_data)

      assert {:ok, %{body: ^blob_data}} = Blob.get_blob(blob)
    end
  end

  describe "put_blob_by_url" do
    test "puts a blob from a URL", %{
      container_context: container_context,
      storage_context: storage_context
    } do
      blob_name = "blob_from_url.txt"

      url =
        "https://raw.githubusercontent.com/joeapearson/elixir-azure/main/test/storage/#{blob_name}"

      expected_contents =
        if storage_context.is_development_factory do
          # Storage emulator doesn't yet support put blob from URL API and always returns an empty
          # blob
          ""
        else
          File.read!(Path.expand(blob_name, __DIR__))
        end

      %{headers: source_headers} = Tesla.head!(url)
      source_content_type = header(source_headers, "content-type")
      source_content_encoding = header(source_headers, "content-encoding")
      source_content_language = header(source_headers, "content-language")
      source_content_disposition = header(source_headers, "content-disposition")

      assert is_binary(source_content_type)

      blob = Blob.new(container_context, blob_name)

      assert {:ok, %{status: 201}} = Blob.put_blob_from_url(blob, url, content_type_workaround: true)

      assert {:ok, %{status: 200, body: destination_body, headers: destination_headers}} = Blob.get_blob(blob)

      assert destination_body == expected_contents

      destination_content_type = header(destination_headers, "content-type")
      destination_content_encoding = header(destination_headers, "content-encoding")
      destination_content_language = header(destination_headers, "content-language")
      destination_content_disposition = header(destination_headers, "content-disposition")

      assert source_content_type == destination_content_type
      assert source_content_encoding == destination_content_encoding
      assert source_content_language == destination_content_language
      assert source_content_disposition == destination_content_disposition
    end
  end

  describe "copy" do
    test "copies a blob from another blob", %{
      container_context: container_context
    } do
      blob_data = "my_blob_data"
      source = Blob.new(container_context, "source_blob")
      target = Blob.new(container_context, "target_blob")

      assert {:ok, %{status: 201}} = Blob.put_blob(source, blob_data)
      assert {:ok, %{body: ^blob_data}} = Blob.get_blob(source)

      assert {:ok, %{x_ms_copy_status: "success"}} = Blob.copy(source, target)
      assert {:ok, %{body: ^blob_data}} = Blob.get_blob(target)
    end
  end

  describe "upload_file" do
    test "uploads a file with blob properties", %{container_context: container_context} do
      file_content = "test file contentt"
      tmp_dir = System.tmp_dir!()
      source_path = Path.join(tmp_dir, "test_upload_#{System.unique_integer([:positive])}.txt")
      blob_name = build(:blob_name)

      try do
        File.write!(source_path, file_content)

        blob_properties = %{
          content_type: "application/octet-stream",
          meta: [
            {"x-frame-options", "DENY"},
            {"content-security-policy", "default-src 'self'"},
            {"enable-cors-protection", "true"}
          ]
        }

        assert {:ok, %{status: 201}} =
                 Blob.upload_file(container_context, source_path, blob_name, blob_properties)

        blob = Blob.new(container_context, blob_name)
        assert {:ok, %{status: 200, body: ^file_content}} = Blob.get_blob(blob)

        assert {:ok, %{status: 200, properties: properties}} = Blob.get_blob_properties(blob)

        assert properties.content_type == "application/octet-stream"
        assert {"x-frame-options", "DENY"} in properties.meta
        assert {"content-security-policy", "default-src 'self'"} in properties.meta
        assert {"enable-cors-protection", "true"} in properties.meta
      after
        if File.exists?(source_path), do: File.rm!(source_path)
      end
    end
  end
end
