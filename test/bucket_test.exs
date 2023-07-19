defmodule LibOss.BucketTest do
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
    assert {:ok, _} = LibOss.list_object_v2(cli, bucket, %{"prefix" => "test/test"})

    # delete
    for i <- 1..10 do
      assert {:ok, _} = LibOss.delete_object(cli, bucket, "/test/test_#{i}.txt")
    end
  end

  test "get_bucket_info", %{cli: cli, bucket: bucket} do
    assert {:ok, _} = LibOss.get_bucket_info(cli, bucket)
  end
end
