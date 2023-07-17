defmodule LibOssTest do
  use ExUnit.Case

  setup_all do
    %{
      "endpoint" => endpoint,
      "access_key_id" => access_key_id,
      "access_key_secret" => access_key_secret,
      "bucket" => bucket
    } =
      File.read!("./tmp/test.json")
      |> Jason.decode!()

    cli =
      LibOss.new(
        endpoint: endpoint,
        access_key_id: access_key_id,
        access_key_secret: access_key_secret
      )

    start_supervised!({LibOss, client: cli})

    [cli: cli, bucket: bucket]
  end

  test "get_token", %{cli: cli, bucket: bucket} do
    assert {:ok, _} = LibOss.get_token(cli, bucket, "/test/test.txt", 3600)
  end

  test "put_object", %{cli: cli, bucket: bucket} do
    assert {:ok, _} = LibOss.put_object(cli, bucket, "/test/test.txt", "hello world")
  end

  test "get_object", %{cli: cli, bucket: bucket} do
    assert {:ok, "hello world"} = LibOss.get_object(cli, bucket, "/test/test.txt")
  end

  test "copy_object", %{cli: cli, bucket: bucket} do
    to_bucket = "test-copy-object-#{System.system_time(:second)}"
    {:ok, _} = LibOss.put_bucket(cli, to_bucket)

    Process.sleep(1000)

    assert {:ok, _} =
             LibOss.copy_object(cli, to_bucket, "/test/test_copy.txt", bucket, "/test/test.txt")

    assert {:ok, "hello world"} = LibOss.get_object(cli, to_bucket, "/test/test_copy.txt")
    LibOss.delete_object(cli, to_bucket, "/test/test_copy.txt")
    LibOss.delete_bucket(cli, to_bucket)
  end

  test "delete_object", %{cli: cli, bucket: bucket} do
    LibOss.put_object(cli, bucket, "/test/test_for_delete.txt", "hello world")
    assert {:ok, _} = LibOss.delete_object(cli, bucket, "/test/test_for_delete.txt")
  end

  test "delete_multiple_object", %{cli: cli, bucket: bucket} do
    for i <- 1..10 do
      assert {:ok, _} = LibOss.put_object(cli, bucket, "/test/test_#{i}.txt", "hello world")
    end

    assert {:ok, _} =
             LibOss.delete_multiple_objects(cli, bucket, [
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
             ])
  end

  test "append_object", %{cli: cli, bucket: bucket} do
    assert {:ok, _} = LibOss.append_object(cli, bucket, "/test/test_append.txt", 0, "hello world")

    assert {:ok, _} =
             LibOss.append_object(cli, bucket, "/test/test_append.txt", 11, "hello world")

    assert {:ok, "hello worldhello world"} =
             LibOss.get_object(cli, bucket, "/test/test_append.txt")

    LibOss.delete_object(cli, bucket, "/test/test_append.txt")
  end

  defp generate_test_data(length) when is_integer(length) and length > 0 do
    :crypto.strong_rand_bytes(length)
    |> Base.encode64()
  end

  test "multi_upload", %{cli: cli, bucket: bucket} do
    object = "/test/multi-test.txt"
    assert {:ok, upload_id} = LibOss.init_multi_upload(cli, bucket, object)

    assert {:ok, etag1} =
             LibOss.upload_part(
               cli,
               bucket,
               object,
               upload_id,
               1,
               generate_test_data(102_400)
             )

    assert {:ok, etag2} =
             LibOss.upload_part(
               cli,
               bucket,
               object,
               upload_id,
               2,
               generate_test_data(102_400)
             )

    assert {:ok, etag3} =
             LibOss.upload_part(
               cli,
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

    assert {:ok, _} = LibOss.complete_multipart_upload(cli, bucket, object, upload_id, parts)
  end

  test "put/delete_bucket", %{cli: cli} do
    bucket = "test-bucket-#{System.system_time(:second)}"
    assert {:ok, _} = LibOss.put_bucket(cli, bucket)
    assert {:ok, _} = LibOss.delete_bucket(cli, bucket)
  end

  test "get_bucket", %{cli: cli, bucket: bucket} do
    for i <- 1..10 do
      assert {:ok, _} = LibOss.put_object(cli, bucket, "/test/test_#{i}.txt", "hello world")
    end

    assert {:ok, _} = LibOss.get_bucket(cli, bucket, %{"prefix" => "test/test"})

    # delete
    for i <- 1..10 do
      assert {:ok, _} = LibOss.delete_object(cli, bucket, "/test/test_#{i}.txt")
    end
  end
end
