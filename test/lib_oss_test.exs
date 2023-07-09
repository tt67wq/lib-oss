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

  test "delete_object", %{cli: cli, bucket: bucket} do
    LibOss.put_object(cli, bucket, "/test/test_for_delete.txt", "hello world")
    assert {:ok, _} = LibOss.delete_object(cli, bucket, "/test/test_for_delete.txt")
  end

  def generate_test_data(length) when is_integer(length) and length > 0 do
    :crypto.strong_rand_bytes(length)
    |> Base.encode64()
  end

  test "multi_upload", %{cli: cli, bucket: bucket} do
    assert {:ok, upload_id} = LibOss.init_multi_upload(cli, bucket, "/test/test.txt")

    assert {:ok, etag1} =
             LibOss.upload_part(
               cli,
               bucket,
               "/test/test.txt",
               upload_id,
               1,
               generate_test_data(102_400)
             )

    assert {:ok, etag2} =
             LibOss.upload_part(
               cli,
               bucket,
               "/test/test.txt",
               upload_id,
               2,
               generate_test_data(102_400)
             )

    assert {:ok, etag3} =
             LibOss.upload_part(
               cli,
               bucket,
               "/test/test.txt",
               upload_id,
               3,
               generate_test_data(102_400)
             )

    parts = [
      {"1", etag1},
      {"2", etag2},
      {"3", etag3}
    ]

    assert {:ok, _} =
             LibOss.complete_multipart_upload(cli, bucket, "/test/test.txt", upload_id, parts)
  end
end
