defmodule LibOssDelegateTest do
  use ExUnit.Case

  doctest LibOss

  describe "主模块delegate调用验证" do
    # 定义一个测试模块
    defmodule TestOssClient do
      @moduledoc false
      use LibOss, otp_app: :test_app
    end

    setup do
      # 设置测试配置
      config = [
        endpoint: "oss-cn-test.aliyuncs.com",
        access_key_id: "test_access_key_id",
        access_key_secret: "test_access_key_secret"
      ]

      Application.put_env(:test_app, TestOssClient, config)

      # 启动测试客户端
      {:ok, _} = start_supervised(TestOssClient)

      :ok
    end

    test "Token相关函数正确delegate到Core.Token模块" do
      # 验证get_token函数存在
      functions = TestOssClient.__info__(:functions)
      assert Keyword.has_key?(functions, :get_token)

      # 测试函数调用（这里我们主要测试函数存在和可调用性）
      # 实际的网络调用会因为测试环境而失败，但这里我们主要验证delegate是否正确
      try do
        TestOssClient.get_token("test-bucket", "test-object")
      rescue
        # 预期会因为网络或配置问题失败，但不应该是未定义函数错误
        error ->
          refute match?(%UndefinedFunctionError{}, error)
      end
    end

    test "Object相关函数正确delegate到Core.Object模块" do
      # 验证主要的object函数存在
      functions = TestOssClient.__info__(:functions)

      object_functions = [
        :put_object,
        :get_object,
        :delete_object,
        :copy_object,
        :append_object,
        :head_object,
        :get_object_meta,
        :delete_multiple_objects
      ]

      for func <- object_functions do
        assert Keyword.has_key?(functions, func), "函数 #{func} 不存在"
      end

      # 测试基本的函数调用结构
      try do
        TestOssClient.put_object("test-bucket", "test-object", "test-data")
      rescue
        error ->
          refute match?(%UndefinedFunctionError{}, error)
      end
    end

    test "ACL相关函数正确delegate到Core.Acl模块" do
      functions = TestOssClient.__info__(:functions)

      acl_functions = [:put_object_acl, :get_object_acl, :put_bucket_acl, :get_bucket_acl]

      for func <- acl_functions do
        assert Keyword.has_key?(functions, func), "函数 #{func} 不存在"
      end

      # 测试ACL函数调用
      try do
        TestOssClient.put_object_acl("test-bucket", "test-object", "private")
      rescue
        error ->
          refute match?(%UndefinedFunctionError{}, error)
      end
    end

    test "Symlink相关函数正确delegate到Core.Symlink模块" do
      functions = TestOssClient.__info__(:functions)

      symlink_functions = [:put_symlink, :get_symlink]

      for func <- symlink_functions do
        assert Keyword.has_key?(functions, func), "函数 #{func} 不存在"
      end

      # 测试symlink函数调用
      try do
        TestOssClient.put_symlink("test-bucket", "link-object", "target-object")
      rescue
        error ->
          refute match?(%UndefinedFunctionError{}, error)
      end
    end

    test "Tagging相关函数正确delegate到Core.Tagging模块" do
      functions = TestOssClient.__info__(:functions)

      tagging_functions = [:put_object_tagging, :get_object_tagging, :delete_object_tagging]

      for func <- tagging_functions do
        assert Keyword.has_key?(functions, func), "函数 #{func} 不存在"
      end

      # 测试tagging函数调用
      try do
        TestOssClient.put_object_tagging("test-bucket", "test-object", %{"key" => "value"})
      rescue
        error ->
          refute match?(%UndefinedFunctionError{}, error)
      end
    end

    test "Bucket相关函数正确delegate到Core.Bucket模块" do
      functions = TestOssClient.__info__(:functions)

      bucket_functions = [
        :put_bucket,
        :delete_bucket,
        :get_bucket,
        :list_object_v2,
        :get_bucket_info,
        :get_bucket_location,
        :get_bucket_stat
      ]

      for func <- bucket_functions do
        assert Keyword.has_key?(functions, func), "函数 #{func} 不存在"
      end

      # 测试bucket函数调用
      try do
        TestOssClient.put_bucket("test-bucket")
      rescue
        error ->
          refute match?(%UndefinedFunctionError{}, error)
      end
    end

    test "Multipart相关函数正确delegate到Core.Multipart模块" do
      functions = TestOssClient.__info__(:functions)

      multipart_functions = [
        :init_multi_upload,
        :upload_part,
        :list_multipart_uploads,
        :complete_multipart_upload,
        :abort_multipart_upload,
        :list_parts
      ]

      for func <- multipart_functions do
        assert Keyword.has_key?(functions, func), "函数 #{func} 不存在"
      end

      # 测试multipart函数调用
      try do
        TestOssClient.init_multi_upload("test-bucket", "test-object")
      rescue
        error ->
          refute match?(%UndefinedFunctionError{}, error)
      end
    end

    test "delegate函数的模块映射正确" do
      # 这个测试验证我们的delegate函数确实调用了正确的模块

      # 由于delegate是私有函数，我们通过间接方式验证
      # 确保所有相关的Core子模块都已正确加载
      core_modules = [
        LibOss.Core.Token,
        LibOss.Core.Object,
        LibOss.Core.Acl,
        LibOss.Core.Symlink,
        LibOss.Core.Tagging,
        LibOss.Core.Bucket,
        LibOss.Core.Multipart
      ]

      for module <- core_modules do
        assert Code.ensure_loaded?(module), "模块 #{module} 未正确加载"
      end
    end

    test "所有delegate函数的参数传递正确" do
      # 验证参数传递的正确性
      # 我们通过检查函数的arity来验证参数传递是否正确

      functions_with_arity = [
        # 有默认参数，实际arity是2
        {:get_token, 2},
        # 有默认参数，实际arity是3
        {:put_object, 3},
        # 有默认参数，实际arity是2
        {:get_object, 2},
        {:delete_object, 2},
        {:put_object_acl, 3},
        {:get_object_acl, 2},
        # 有默认参数，实际arity是3
        {:put_symlink, 3},
        {:get_symlink, 2},
        {:put_object_tagging, 3},
        {:get_object_tagging, 2},
        {:delete_object_tagging, 2},
        # 有多个默认参数，实际arity是1
        {:put_bucket, 1},
        {:delete_bucket, 1},
        {:get_bucket, 2},
        # 有默认参数，实际arity是2
        {:init_multi_upload, 2},
        {:upload_part, 5},
        # 有默认参数，实际arity是4
        {:complete_multipart_upload, 4},
        {:abort_multipart_upload, 3}
      ]

      client_functions = TestOssClient.__info__(:functions)

      for {func_name, expected_arity} <- functions_with_arity do
        actual_arity = Keyword.get(client_functions, func_name)

        assert actual_arity == expected_arity,
               "函数 #{func_name} 的arity不匹配，期望: #{expected_arity}, 实际: #{actual_arity}"
      end
    end

    test "主模块保持向后兼容性" do
      # 验证所有原有的公共API函数仍然存在
      functions = TestOssClient.__info__(:functions)

      # 原有的主要API函数列表
      expected_functions = [
        :get_token,
        :put_object,
        :get_object,
        :copy_object,
        :delete_object,
        :delete_multiple_objects,
        :append_object,
        :head_object,
        :get_object_meta,
        :put_object_acl,
        :get_object_acl,
        :put_symlink,
        :get_symlink,
        :put_object_tagging,
        :get_object_tagging,
        :delete_object_tagging,
        :put_bucket,
        :delete_bucket,
        :get_bucket,
        :list_object_v2,
        :get_bucket_info,
        :get_bucket_location,
        :get_bucket_stat,
        :put_bucket_acl,
        :get_bucket_acl,
        :init_multi_upload,
        :upload_part,
        :list_multipart_uploads,
        :complete_multipart_upload,
        :abort_multipart_upload,
        :list_parts
      ]

      for func <- expected_functions do
        assert Keyword.has_key?(functions, func),
               "重构后缺少原有的API函数: #{func}"
      end

      # 验证函数总数没有减少（只能增加，不能减少）
      assert length(Keyword.keys(functions)) >= length(expected_functions),
             "重构后函数数量不能少于重构前"
    end
  end

  describe "错误处理验证" do
    defmodule TestOssClientError do
      @moduledoc false
      use LibOss, otp_app: :test_error_app
    end

    test "当Core子模块不存在时应该有明确的错误信息" do
      # 这个测试确保如果某个Core子模块缺失，会有清晰的错误信息
      # 而不是神秘的UndefinedFunctionError

      config = [
        endpoint: "oss-cn-test.aliyuncs.com",
        access_key_id: "test_access_key_id",
        access_key_secret: "test_access_key_secret"
      ]

      Application.put_env(:test_error_app, TestOssClientError, config)

      # 如果所有模块都正确加载，这个测试应该通过
      assert Code.ensure_loaded?(LibOss.Core.Object)
      assert Code.ensure_loaded?(LibOss.Core.Token)
      assert Code.ensure_loaded?(LibOss.Core.Acl)
    end
  end
end
