defmodule LibOss.LibOssTest do
  @moduledoc false
  use ExUnit.Case

  alias LibOss.Debug
  alias LibOss.Test.App

  setup_all do
    cfg = [
      endpoint: System.get_env("LIBOSS_TEST_ENDPOINT"),
      access_key_id: System.get_env("LIBOSS_TEST_ACCESS_KEY_ID"),
      access_key_secret: System.get_env("LIBOSS_TEST_ACCESS_KEY_SECRET")
    ]

    bucket = System.get_env("LIBOSS_TEST_BUCKET")
    Application.put_env(:app, LibOss.Test.App, cfg)

    start_supervised!(LibOss.Test.App)
    [bucket: bucket]
  end

  test "get_token", %{bucket: bucket} do
    assert {:ok, token} = App.get_token(bucket, "/test/test.txt", 3600)
    Debug.debug(token)
  end

  test "put_object", %{bucket: bucket} do
    assert :ok == App.put_object(bucket, "/test/test.txt", "hello world")
  end

  test "get_object", %{bucket: bucket} do
    assert {:ok, "hello world"} = App.get_object(bucket, "/test/test.txt")
  end

  test "copy_object", %{bucket: bucket} do
    to_bucket = "test-copy-object-#{System.system_time(:second)}"
    assert :ok == App.put_bucket(to_bucket)

    Process.sleep(1000)

    assert :ok = App.copy_object(to_bucket, "/test/test_copy.txt", bucket, "/test/test.txt")

    assert {:ok, "hello world"} = App.get_object(to_bucket, "/test/test_copy.txt")

    Process.sleep(1000)
    assert :ok == App.delete_object(to_bucket, "/test/test_copy.txt")
    assert :ok == App.delete_bucket(to_bucket)
  end

  test "delete_object", %{bucket: bucket} do
    App.put_object(bucket, "/test/test_for_delete.txt", "hello world")
    assert :ok == App.delete_object(bucket, "/test/test_for_delete.txt")

    for i <- 1..10 do
      assert :ok == App.put_object(bucket, "/test/test_#{i}.txt", "hello world")
    end

    assert :ok ==
             App.delete_multiple_objects(
               bucket,
               [
                 "/test/test_1.txt",
                 "/test/test_2.txt",
                 "/test/test_3.txt",
                 "/test/test_4.txt",
                 "/test/test_5.txt",
                 "/test/test_6.txt",
                 "/test/test_7.txt",
                 "/test/test_8.txt",
                 "/test/test_9.txt",
                 "/test/test_10.txt"
               ]
             )
  end

  test "append_object", %{bucket: bucket} do
    assert :ok == App.append_object(bucket, "/test/test_append.txt", 0, "hello world")
    assert :ok == App.append_object(bucket, "/test/test_append.txt", 11, " hello world")

    assert {:ok, "hello world hello world"} == App.get_object(bucket, "/test/test_append.txt")

    App.delete_object(bucket, "/test/test_append.txt")
  end

  test "head_object", %{bucket: bucket} do
    assert {:ok, res} = App.head_object(bucket, "/test/test.txt")
    Debug.debug(res)
  end

  test "get_object_meta", %{bucket: bucket} do
    assert {:ok, res} = App.get_object_meta(bucket, "/test/test.txt")
    Debug.debug(res)
  end

  test "acl", %{bucket: bucket} do
    assert :ok == App.put_object(bucket, "/test/test.txt", "hello world")
    assert :ok == App.put_object_acl(bucket, "/test/test.txt", "public-read")
    assert {:ok, "public-read"} == App.get_object_acl(bucket, "/test/test.txt")
  end

  test "put/get_symlink", %{bucket: bucket} do
    assert :ok == App.put_symlink(bucket, "/test/test.txt", "/test/test_symlink.txt")
    assert {:ok, "/test/test_symlink.txt"} == App.get_symlink(bucket, "/test/test.txt")
  end

  test "tagging", %{bucket: bucket} do
    assert :ok ==
             App.put_object_tagging(bucket, "/test/test.txt", %{
               "key1" => "value1",
               "key2" => "value2"
             })

    assert {:ok,
            [
              %{"Key" => "key1", "Value" => "value1"},
              %{"Key" => "key2", "Value" => "value2"}
            ]} = App.get_object_tagging(bucket, "/test/test.txt")

    assert :ok == App.delete_object_tagging(bucket, "/test/test.txt")
  end

  defp generate_test_data(length) when is_integer(length) and length > 0 do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.encode64()
  end

  test "multi_upload", %{bucket: bucket} do
    object = "/test/multi-test.txt"
    assert {:ok, upload_id} = App.init_multi_upload(bucket, object)
    Debug.debug(upload_id)

    assert {:ok, etag1} =
             App.upload_part(
               bucket,
               object,
               upload_id,
               1,
               generate_test_data(102_400)
             )

    assert {:ok, etag2} =
             App.upload_part(
               bucket,
               object,
               upload_id,
               2,
               generate_test_data(102_400)
             )

    assert {:ok, etag3} =
             App.upload_part(
               bucket,
               object,
               upload_id,
               3,
               generate_test_data(102_400)
             )

    parts = [
      {"1", etag1},
      {"2", etag2},
      {"3", etag3}
    ]

    assert {:ok, res} =
             App.list_multipart_uploads(bucket, %{
               "delimiter" => "/",
               "max-uploads" => "10",
               "prefix" => "test/"
             })

    Debug.debug(res)

    assert {:ok, res} = App.list_parts(bucket, object, upload_id)
    Debug.debug(res)

    assert :ok == App.complete_multipart_upload(bucket, object, upload_id, parts)
  end

  test "abort_multipart_upload", %{bucket: bucket} do
    object = "/test/multi-test.txt"
    assert {:ok, upload_id} = App.init_multi_upload(bucket, object)
    assert :ok == App.abort_multipart_upload(bucket, object, upload_id)
  end

  test "put/get/delete bucket", _ do
    bucket = "test-bucket-#{System.system_time(:second)}"
    assert :ok == App.put_bucket(bucket)

    for i <- 1..5 do
      App.put_object(bucket, "/test/test_#{i}.txt", "hello world")
    end

    assert {:ok, ms} = App.get_bucket(bucket, %{"prefix" => "test/test"})
    Debug.debug(ms)

    assert {:ok, ms} = App.list_object_v2(bucket, %{"prefix" => "test/test"})
    Debug.debug(ms)

    for i <- 1..5 do
      App.delete_object(bucket, "/test/test_#{i}.txt")
    end

    assert :ok == App.delete_bucket(bucket)
  end

  @tag exec: true
  test "get_bucket_info", %{bucket: bucket} do
    assert {:ok, res} = App.get_bucket_info(bucket)
    Debug.debug(res)
  end
end
