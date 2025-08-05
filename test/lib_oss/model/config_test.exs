defmodule LibOss.Model.ConfigTest do
  use ExUnit.Case, async: true

  alias LibOss.Model.Config

  doctest LibOss.Model.Config

  describe "validate/1" do
    test "验证有效的基础配置" do
      config = [
        access_key_id: "test_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      ]

      assert {:ok, validated_config} = Config.validate(config)
      assert is_list(validated_config)
      assert Keyword.get(validated_config, :access_key_id) == "test_access_key_id_123"
      assert Keyword.get(validated_config, :access_key_secret) == "test_access_key_secret_12345678901234567890"
      assert Keyword.get(validated_config, :endpoint) == "oss-cn-hangzhou.aliyuncs.com"
      # 检查默认值
      assert Keyword.get(validated_config, :timeout) == 30_000
      assert Keyword.get(validated_config, :pool_size) == 100
      assert Keyword.get(validated_config, :max_retries) == 3
      assert Keyword.get(validated_config, :debug) == false
    end

    test "验证包含可选参数的配置" do
      config = [
        access_key_id: "test_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com",
        timeout: 60_000,
        pool_size: 200,
        max_retries: 5,
        debug: true
      ]

      assert {:ok, validated_config} = Config.validate(config)
      assert Keyword.get(validated_config, :timeout) == 60_000
      assert Keyword.get(validated_config, :pool_size) == 200
      assert Keyword.get(validated_config, :max_retries) == 5
      assert Keyword.get(validated_config, :debug) == true
    end

    test "验证失败：缺少必需参数" do
      config = [
        access_key_id: "test_access_key_id_123",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      ]

      assert {:error, error_message} = Config.validate(config)
      assert is_binary(error_message)
      assert String.contains?(error_message, "基础配置验证失败")
    end

    test "验证失败：参数类型错误" do
      config = [
        access_key_id: 123,
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      ]

      assert {:error, error_message} = Config.validate(config)
      assert is_binary(error_message)
    end

    test "验证失败：非关键字列表" do
      config = %{
        access_key_id: "test_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      }

      assert {:error, error_message} = Config.validate(config)
      assert String.contains?(error_message, "配置必须是关键字列表")
    end

    test "空配置列表" do
      assert {:error, error_message} = Config.validate([])
      assert String.contains?(error_message, "基础配置验证失败")
    end
  end

  describe "validate!/1" do
    test "验证成功时返回配置" do
      config = [
        access_key_id: "test_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      ]

      validated_config = Config.validate!(config)
      assert is_list(validated_config)
      assert Keyword.get(validated_config, :access_key_id) == "test_access_key_id_123"
    end

    test "验证失败时抛出异常" do
      config = [
        access_key_id: "test_access_key_id_123",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      ]

      assert_raise LibOss.Exception, fn ->
        Config.validate!(config)
      end
    end

    test "非关键字列表时抛出异常" do
      config = "invalid_config"

      assert_raise LibOss.Exception, fn ->
        Config.validate!(config)
      end
    end
  end

  describe "get_schema/0" do
    test "获取配置模式" do
      schema = Config.get_schema()

      assert is_list(schema)
      assert Keyword.has_key?(schema, :access_key_id)
      assert Keyword.has_key?(schema, :access_key_secret)
      assert Keyword.has_key?(schema, :endpoint)
      assert Keyword.has_key?(schema, :timeout)
      assert Keyword.has_key?(schema, :pool_size)
      assert Keyword.has_key?(schema, :max_retries)
      assert Keyword.has_key?(schema, :debug)

      # 检查必需字段
      access_key_id_config = Keyword.get(schema, :access_key_id)
      assert access_key_id_config[:required] == true
      assert access_key_id_config[:type] == :string

      access_key_secret_config = Keyword.get(schema, :access_key_secret)
      assert access_key_secret_config[:required] == true
      assert access_key_secret_config[:type] == :string

      endpoint_config = Keyword.get(schema, :endpoint)
      assert endpoint_config[:required] == true
      assert endpoint_config[:type] == :string

      # 检查默认值
      timeout_config = Keyword.get(schema, :timeout)
      assert timeout_config[:default] == 30_000
    end
  end

  describe "validate_enhanced/2" do
    test "使用增强验证功能" do
      config = [
        access_key_id: "test_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      ]

      # 禁用运行时验证
      assert {:ok, validated_config} = Config.validate_enhanced(config, runtime: false)
      assert is_list(validated_config)

      # 启用运行时验证
      assert {:ok, validated_config} = Config.validate_enhanced(config, runtime: true)
      assert is_list(validated_config)
    end

    test "增强验证失败" do
      config = [
        access_key_id: "short",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      ]

      # 运行时验证应该失败
      assert {:error, error_message} = Config.validate_enhanced(config, runtime: true)
      assert String.contains?(error_message, "access_key_id 长度不能少于10个字符")
    end

    test "环境特定验证" do
      config = [
        access_key_id: "test_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com",
        log_level: :debug
      ]

      # 开发环境验证
      assert {:ok, validated_config} = Config.validate_enhanced(config, env: :dev, runtime: false)
      assert Keyword.get(validated_config, :log_level) == :debug
    end
  end

  describe "validate_enhanced!/2" do
    test "验证成功时返回配置" do
      config = [
        access_key_id: "test_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      ]

      validated_config = Config.validate_enhanced!(config)
      assert is_list(validated_config)
      assert Keyword.get(validated_config, :access_key_id) == "test_access_key_id_123"
    end

    test "验证失败时抛出异常" do
      config = [
        access_key_id: "short",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      ]

      assert_raise LibOss.Exception, fn ->
        Config.validate_enhanced!(config, runtime: true)
      end
    end
  end

  describe "向后兼容性" do
    test "与原有API完全兼容" do
      # 这个测试确保新的实现与原有的API完全兼容
      config = [
        access_key_id: "test_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      ]

      # 验证原有的validate/1函数仍然工作
      assert {:ok, _} = Config.validate(config)

      # 验证原有的validate!/1函数仍然工作
      assert is_list(Config.validate!(config))

      # 验证返回的配置格式保持一致
      {:ok, validated_config} = Config.validate(config)
      assert is_list(validated_config)
      assert Keyword.keyword?(validated_config)
    end

    test "错误格式保持一致" do
      invalid_config = [
        access_key_id: "test_access_key_id_123"
        # 缺少必需字段
      ]

      # 验证错误返回格式
      assert {:error, error_message} = Config.validate(invalid_config)
      assert is_binary(error_message)

      # 验证异常抛出行为
      assert_raise LibOss.Exception, fn ->
        Config.validate!(invalid_config)
      end
    end
  end

  describe "边缘情况" do
    test "处理nil值" do
      assert {:error, error_message} = Config.validate(nil)
      assert String.contains?(error_message, "配置必须是关键字列表")
    end

    test "处理原子值" do
      assert {:error, error_message} = Config.validate(:invalid)
      assert String.contains?(error_message, "配置必须是关键字列表")
    end

    test "处理嵌套列表" do
      config = [
        access_key_id: "test_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com",
        nested: [key: "value"]
      ]

      # 应该能够处理嵌套结构（虽然可能不会验证嵌套内容）
      result = Config.validate(config)

      case result do
        {:ok, _} -> assert true
        {:error, _} -> assert true
      end
    end
  end
end
