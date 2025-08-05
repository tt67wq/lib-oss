defmodule LibOss.Core.ObjectIntegrationTest do
  use ExUnit.Case

  alias LibOss.Core.Object
  alias LibOss.Exception

  @moduletag :integration

  # 测试配置模块
  defmodule TestOss do
    @moduledoc false
    use LibOss, otp_app: :lib_oss_test
  end

  @test_bucket "hope-data"
  @test_object "integration-test-object"
  @test_object_2 "integration-test-object-2"
  @test_append_object "integration-test-append-object"
  @test_data "Hello, 这是集成测试数据!"
  @append_data_1 "第一部分数据"
  @append_data_2 "第二部分数据"

  setup_all do
    # 从环境变量读取配置
    config = get_test_config()

    case config do
      {:ok, test_config} ->
        # 设置测试应用配置
        Application.put_env(:lib_oss_test, TestOss, test_config)

        # 启动测试客户端
        {:ok, _pid} = TestOss.start_link()

        # 返回配置供测试使用
        {:ok, config: test_config}

      {:error, reason} ->
        {:skip, "跳过集成测试: #{reason}"}
    end
  end

  setup do
    # 每个测试前清理可能存在的测试对象
    cleanup_test_objects()
    :ok
  end

  describe "对象基础操作" do
    @tag :integration
    test "put_object/5 - 上传对象" do
      assert :ok = Object.put_object(TestOss, @test_bucket, @test_object, @test_data)
    end

    @tag :integration
    test "get_object/4 - 获取对象" do
      # 先上传对象
      :ok = Object.put_object(TestOss, @test_bucket, @test_object, @test_data)

      # 获取对象
      assert {:ok, data} = Object.get_object(TestOss, @test_bucket, @test_object)
      assert data == @test_data
    end

    @tag :integration
    test "get_object/4 - 获取不存在的对象应返回错误" do
      assert {:error, %Exception{}} = Object.get_object(TestOss, @test_bucket, "不存在的对象")
    end

    @tag :integration
    test "delete_object/3 - 删除对象" do
      # 先上传对象
      :ok = Object.put_object(TestOss, @test_bucket, @test_object, @test_data)

      # 验证对象存在
      assert {:ok, _} = Object.get_object(TestOss, @test_bucket, @test_object)

      # 删除对象
      assert :ok = Object.delete_object(TestOss, @test_bucket, @test_object)

      # 验证对象已被删除
      assert {:error, _} = Object.get_object(TestOss, @test_bucket, @test_object)
    end

    @tag :integration
    test "delete_object/3 - 删除不存在的对象也应该返回成功" do
      assert :ok = Object.delete_object(TestOss, @test_bucket, "不存在的对象")
    end
  end

  describe "对象复制操作" do
    @tag :integration
    test "copy_object/6 - 复制对象到同一个存储桶" do
      # 先上传源对象
      :ok = Object.put_object(TestOss, @test_bucket, @test_object, @test_data)

      # 复制对象
      assert :ok = Object.copy_object(TestOss, @test_bucket, @test_object_2, @test_bucket, @test_object)

      # 验证复制后的对象内容正确
      assert {:ok, data} = Object.get_object(TestOss, @test_bucket, @test_object_2)
      assert data == @test_data

      # 清理
      Object.delete_object(TestOss, @test_bucket, @test_object_2)
    end

    @tag :integration
    test "copy_object/6 - 复制不存在的对象应返回错误" do
      assert {:error, %Exception{}} =
               Object.copy_object(
                 TestOss,
                 @test_bucket,
                 @test_object_2,
                 @test_bucket,
                 "不存在的源对象"
               )
    end
  end

  describe "批量删除操作" do
    @tag :integration
    test "delete_multiple_objects/3 - 批量删除多个对象" do
      objects = ["批量删除测试-1", "批量删除测试-2", "批量删除测试-3"]

      # 先上传多个对象
      Enum.each(objects, fn object ->
        :ok = Object.put_object(TestOss, @test_bucket, object, "测试数据")
      end)

      # 验证对象都存在
      Enum.each(objects, fn object ->
        assert {:ok, _} = Object.get_object(TestOss, @test_bucket, object)
      end)

      # 批量删除
      assert :ok = Object.delete_multiple_objects(TestOss, @test_bucket, objects)

      # 验证对象都已被删除
      Enum.each(objects, fn object ->
        assert {:error, _} = Object.get_object(TestOss, @test_bucket, object)
      end)
    end

    @tag :integration
    test "delete_multiple_objects/3 - 批量删除包含不存在对象的列表" do
      objects = ["存在的对象", "不存在的对象-1", "不存在的对象-2"]

      # 只上传第一个对象
      :ok = Object.put_object(TestOss, @test_bucket, "存在的对象", "测试数据")

      # 批量删除应该成功
      assert :ok = Object.delete_multiple_objects(TestOss, @test_bucket, objects)
    end
  end

  describe "追加写操作" do
    @tag :integration
    test "append_object/6 - 追加写对象" do
      # 第一次追加写（从位置0开始）
      assert :ok = Object.append_object(TestOss, @test_bucket, @test_append_object, 0, @append_data_1)

      # 验证第一次写入的内容
      assert {:ok, data} = Object.get_object(TestOss, @test_bucket, @test_append_object)
      assert data == @append_data_1

      # 第二次追加写（从第一次写入数据的末尾开始）
      position = byte_size(@append_data_1)
      assert :ok = Object.append_object(TestOss, @test_bucket, @test_append_object, position, @append_data_2)

      # 验证追加后的完整内容
      assert {:ok, data} = Object.get_object(TestOss, @test_bucket, @test_append_object)
      assert data == @append_data_1 <> @append_data_2

      # 清理
      Object.delete_object(TestOss, @test_bucket, @test_append_object)
    end

    @tag :integration
    test "append_object/6 - 错误的追加位置应返回错误" do
      # 先进行正常的追加写
      :ok = Object.append_object(TestOss, @test_bucket, @test_append_object, 0, @append_data_1)

      # 尝试从错误的位置追加（不是文件末尾）
      assert {:error, %Exception{}} =
               Object.append_object(
                 TestOss,
                 @test_bucket,
                 @test_append_object,
                 999,
                 @append_data_2
               )

      # 清理
      Object.delete_object(TestOss, @test_bucket, @test_append_object)
    end
  end

  describe "对象元数据操作" do
    @tag :integration
    test "head_object/4 - 获取对象头部信息" do
      # 先上传对象
      :ok = Object.put_object(TestOss, @test_bucket, @test_object, @test_data)

      # 获取头部信息
      assert {:ok, headers} = Object.head_object(TestOss, @test_bucket, @test_object)

      # 验证基本头部信息存在
      assert is_map(headers)
      assert Map.has_key?(headers, "content-length")
      assert Map.has_key?(headers, "content-type")
      assert Map.has_key?(headers, "etag")
      assert Map.has_key?(headers, "last-modified")

      # 验证内容长度正确
      expected_length = byte_size(@test_data)
      assert headers["content-length"] == to_string(expected_length)
    end

    @tag :integration
    test "head_object/4 - 获取不存在对象的头部信息应返回错误" do
      assert {:error, %Exception{}} = Object.head_object(TestOss, @test_bucket, "不存在的对象")
    end

    @tag :integration
    test "get_object_meta/3 - 获取对象元数据" do
      # 先上传对象
      :ok = Object.put_object(TestOss, @test_bucket, @test_object, @test_data)

      # 获取元数据
      assert {:ok, meta} = Object.get_object_meta(TestOss, @test_bucket, @test_object)

      # 验证元数据格式正确
      assert is_map(meta)
      assert Map.has_key?(meta, "content-length")
      assert Map.has_key?(meta, "etag")
    end

    @tag :integration
    test "object_exists?/3 - 检查对象是否存在" do
      # 检查不存在的对象
      assert Object.object_exists?(TestOss, @test_bucket, @test_object) == false

      # 上传对象
      :ok = Object.put_object(TestOss, @test_bucket, @test_object, @test_data)

      # 检查存在的对象
      assert Object.object_exists?(TestOss, @test_bucket, @test_object) == true

      # 删除对象
      :ok = Object.delete_object(TestOss, @test_bucket, @test_object)

      # 再次检查应该返回false
      assert Object.object_exists?(TestOss, @test_bucket, @test_object) == false
    end

    @tag :integration
    test "get_object_size/3 - 获取对象大小" do
      # 先上传对象
      :ok = Object.put_object(TestOss, @test_bucket, @test_object, @test_data)

      # 获取对象大小
      assert {:ok, size} = Object.get_object_size(TestOss, @test_bucket, @test_object)

      # 验证大小正确
      expected_size = byte_size(@test_data)
      assert size == expected_size
    end

    @tag :integration
    test "get_object_size/3 - 获取不存在对象的大小应返回错误" do
      assert {:error, %Exception{}} = Object.get_object_size(TestOss, @test_bucket, "不存在的对象")
    end
  end

  describe "自定义头部操作" do
    @tag :integration
    test "put_object/5 - 使用自定义头部上传对象" do
      custom_headers = [
        {"content-type", "text/plain; charset=utf-8"},
        {"x-oss-meta-custom", "自定义元数据值"},
        {"x-oss-meta-author", "集成测试"}
      ]

      # 使用自定义头部上传
      assert :ok = Object.put_object(TestOss, @test_bucket, @test_object, @test_data, custom_headers)

      # 获取头部信息验证自定义头部
      assert {:ok, headers} = Object.head_object(TestOss, @test_bucket, @test_object)

      # 验证内容类型
      assert headers["content-type"] == "text/plain; charset=utf-8"

      # 验证自定义元数据（OSS会将x-oss-meta-前缀的头部作为用户元数据）
      assert Map.has_key?(headers, "x-oss-meta-custom")
      assert Map.has_key?(headers, "x-oss-meta-author")
    end

    @tag :integration
    test "get_object/4 - 使用条件头部获取对象" do
      # 先上传对象
      :ok = Object.put_object(TestOss, @test_bucket, @test_object, @test_data)

      # 获取对象的ETag
      {:ok, headers} = Object.head_object(TestOss, @test_bucket, @test_object)
      etag = headers["etag"]

      # 使用If-Match头部获取对象
      req_headers = [{"if-match", etag}]
      assert {:ok, data} = Object.get_object(TestOss, @test_bucket, @test_object, req_headers)
      assert data == @test_data

      # 使用错误的If-Match头部应该返回错误
      wrong_headers = [{"if-match", "\"wrong-etag\""}]

      assert {:error, %Exception{}} = Object.get_object(TestOss, @test_bucket, @test_object, wrong_headers)
    end
  end

  describe "错误处理测试" do
    @tag :integration
    test "使用无效存储桶名称的操作应返回错误" do
      invalid_bucket = "invalid-bucket-name-!@#$%"

      assert {:error, %Exception{}} = Object.put_object(TestOss, invalid_bucket, @test_object, @test_data)
      assert {:error, %Exception{}} = Object.get_object(TestOss, invalid_bucket, @test_object)
      assert {:error, %Exception{}} = Object.delete_object(TestOss, invalid_bucket, @test_object)
    end

    @tag :integration
    test "使用空对象名称应返回错误" do
      assert {:error, %Exception{}} = Object.put_object(TestOss, @test_bucket, "", @test_data)
      assert {:error, %Exception{}} = Object.get_object(TestOss, @test_bucket, "")
    end
  end

  # 私有辅助函数

  defp get_test_config do
    with endpoint when not is_nil(endpoint) <- System.get_env("OSS_ENDPOINT"),
         access_key_id when not is_nil(access_key_id) <- System.get_env("OSS_ACCESS_KEY_ID"),
         access_key_secret when not is_nil(access_key_secret) <- System.get_env("OSS_ACCESS_KEY_SECRET") do
      {:ok,
       [
         endpoint: endpoint,
         access_key_id: access_key_id,
         access_key_secret: access_key_secret
       ]}
    else
      nil ->
        {:error, "缺少必要的环境变量: OSS_ENDPOINT, OSS_ACCESS_KEY_ID, OSS_ACCESS_KEY_SECRET"}
    end
  end

  defp cleanup_test_objects do
    # 尝试清理所有可能的测试对象，忽略错误
    test_objects = [
      @test_object,
      @test_object_2,
      @test_append_object,
      "批量删除测试-1",
      "批量删除测试-2",
      "批量删除测试-3",
      "存在的对象"
    ]

    Enum.each(test_objects, fn object ->
      Object.delete_object(TestOss, @test_bucket, object)
    end)
  end
end
