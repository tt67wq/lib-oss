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
    assert {:ok, _} = LibOss.delete_object(cli, bucket, "/test/test.txt")
  end
end
