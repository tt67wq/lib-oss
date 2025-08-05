defmodule LibOss.Config.ValidatorTest do
  use ExUnit.Case, async: true

  alias LibOss.Config.Validator

  doctest LibOss.Config.Validator

  describe "validate/2" do
    test "验证有效的基础配置" do
      config = [
        access_key_id: "test_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      ]

      assert {:ok, validated_config} = Validator.validate(config)
      assert Keyword.get(validated_config, :access_key_id) == "test_access_key_id_123"
      assert Keyword.get(validated_config, :access_key_secret) == "test_access_key_secret_12345678901234567890"
      assert Keyword.get(validated_config, :endpoint) == "oss-cn-hangzhou.aliyuncs.com"
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

      assert {:ok, validated_config} = Validator.validate(config)
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

      assert {:error, error_message} = Validator.validate(config)
      assert String.contains?(error_message, "基础配置验证失败")
    end

    test "验证失败：参数类型错误" do
      config = [
        access_key_id: 123,
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      ]

      assert {:error, error_message} = Validator.validate(config)
      assert String.contains?(error_message, "环境特定配置验证失败")
    end

    test "运行时验证：空的endpoint" do
      config = [
        access_key_id: "test_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: ""
      ]

      assert {:error, error_message} = Validator.validate(config, runtime: true)
      assert error_message == "endpoint 不能为空"
    end

    test "运行时验证：无效的endpoint格式" do
      config = [
        access_key_id: "test_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "invalid-endpoint"
      ]

      assert {:error, error_message} = Validator.validate(config, runtime: true)
      assert error_message == "endpoint 格式无效。应该是有效的域名格式，如：oss-cn-hangzhou.aliyuncs.com"
    end

    test "运行时验证：endpoint包含协议前缀" do
      config = [
        access_key_id: "test_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "https://oss-cn-hangzhou.aliyuncs.com"
      ]

      assert {:error, error_message} = Validator.validate(config, runtime: true)
      assert error_message == "endpoint 不应包含协议前缀(http:// 或 https://)。请只提供域名部分"
    end

    test "运行时验证：access_key_id太短" do
      config = [
        access_key_id: "short",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      ]

      assert {:error, error_message} = Validator.validate(config, runtime: true)
      assert error_message == "access_key_id 长度不能少于10个字符"
    end

    test "运行时验证：access_key_id格式无效" do
      config = [
        access_key_id: "invalid-key-with-dashes",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      ]

      assert {:error, error_message} = Validator.validate(config, runtime: true)
      assert error_message == "access_key_id 格式无效。只能包含字母、数字和下划线"
    end

    test "运行时验证：access_key_secret太短" do
      config = [
        access_key_id: "test_access_key_id_123",
        access_key_secret: "short",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      ]

      assert {:error, error_message} = Validator.validate(config, runtime: true)
      assert error_message == "access_key_secret 长度不能少于20个字符"
    end

    test "禁用运行时验证" do
      config = [
        access_key_id: "short",
        access_key_secret: "short",
        endpoint: ""
      ]

      # 禁用运行时验证时，只进行基础的NimbleOptions验证
      # 由于这些值都符合基础类型要求，所以会通过验证
      assert {:ok, _} = Validator.validate(config, runtime: false)
    end
  end

  describe "validate!/2" do
    test "验证成功时返回配置" do
      config = [
        access_key_id: "test_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      ]

      validated_config = Validator.validate!(config)
      assert is_list(validated_config)
      assert Keyword.get(validated_config, :access_key_id) == "test_access_key_id_123"
    end

    test "验证失败时抛出异常" do
      config = [
        access_key_id: "test_access_key_id_123",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      ]

      assert_raise LibOss.Exception, fn ->
        Validator.validate!(config)
      end
    end
  end

  describe "get_schema/1" do
    test "获取开发环境模式" do
      schema = Validator.get_schema(:dev)

      # 检查基础字段
      assert Keyword.has_key?(schema, :access_key_id)
      assert Keyword.has_key?(schema, :access_key_secret)
      assert Keyword.has_key?(schema, :endpoint)

      # 检查开发环境特定字段
      assert Keyword.has_key?(schema, :log_level)
      assert Keyword.has_key?(schema, :mock_responses)

      log_level_config = Keyword.get(schema, :log_level)
      assert log_level_config[:default] == :debug
    end

    test "获取测试环境模式" do
      schema = Validator.get_schema(:test)

      # 检查测试环境特定字段
      assert Keyword.has_key?(schema, :test_mode)
      assert Keyword.has_key?(schema, :mock_responses)

      mock_responses_config = Keyword.get(schema, :mock_responses)
      assert mock_responses_config[:default] == true

      test_mode_config = Keyword.get(schema, :test_mode)
      assert test_mode_config[:default] == true
    end

    test "获取生产环境模式" do
      schema = Validator.get_schema(:prod)

      # 检查生产环境特定字段
      assert Keyword.has_key?(schema, :ssl_verify)
      assert Keyword.has_key?(schema, :performance_monitoring)

      ssl_verify_config = Keyword.get(schema, :ssl_verify)
      assert ssl_verify_config[:default] == true

      performance_monitoring_config = Keyword.get(schema, :performance_monitoring)
      assert performance_monitoring_config[:default] == true

      # 生产环境log_level默认应该是info
      log_level_config = Keyword.get(schema, :log_level)
      assert log_level_config[:default] == :info
    end
  end

  describe "环境特定验证" do
    test "开发环境验证" do
      config = [
        access_key_id: "test_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com",
        log_level: :debug,
        mock_responses: true
      ]

      assert {:ok, validated_config} = Validator.validate(config, env: :dev, runtime: false)
      assert Keyword.get(validated_config, :log_level) == :debug
      assert Keyword.get(validated_config, :mock_responses) == true
    end

    test "测试环境验证" do
      config = [
        access_key_id: "test_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com",
        test_mode: true
      ]

      assert {:ok, validated_config} = Validator.validate(config, env: :test, runtime: false)
      assert Keyword.get(validated_config, :test_mode) == true
      # 测试环境默认值
      assert Keyword.get(validated_config, :mock_responses) == true
    end

    test "生产环境验证" do
      config = [
        access_key_id: "test_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com",
        ssl_verify: true,
        performance_monitoring: true
      ]

      assert {:ok, validated_config} = Validator.validate(config, env: :prod, runtime: false)
      assert Keyword.get(validated_config, :ssl_verify) == true
      assert Keyword.get(validated_config, :performance_monitoring) == true
    end
  end

  describe "错误格式化" do
    test "各种错误消息格式化正确" do
      test_cases = [
        {[
           access_key_id: "",
           access_key_secret: "test_access_key_secret_12345678901234567890",
           endpoint: "oss-cn-hangzhou.aliyuncs.com"
         ], "access_key_id 不能为空"},
        {[access_key_id: "test_access_key_id_123", access_key_secret: "", endpoint: "oss-cn-hangzhou.aliyuncs.com"],
         "access_key_secret 不能为空"},
        {[
           access_key_id: "test_access_key_id_123",
           access_key_secret: "test_access_key_secret_12345678901234567890",
           endpoint: ""
         ], "endpoint 不能为空"},
        {[
           access_key_id: "test_access_key_id_123",
           access_key_secret: "test_access_key_secret_12345678901234567890",
           endpoint: "http://oss-cn-hangzhou.aliyuncs.com"
         ], "endpoint 不应包含协议前缀(http:// 或 https://)。请只提供域名部分"}
      ]

      for {config, expected_message} <- test_cases do
        assert {:error, ^expected_message} = Validator.validate(config, runtime: true)
      end
    end
  end
end
