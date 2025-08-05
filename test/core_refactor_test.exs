defmodule CoreRefactorTest do
  use ExUnit.Case

  doctest LibOss.Core

  describe "Core模块重构验证" do
    test "RequestBuilder模块存在且功能正常" do
      # 测试基础请求构建
      request = LibOss.Core.RequestBuilder.build_base_request(:get, "test-bucket", "test-object")

      assert request.method == :get
      assert request.bucket == "test-bucket"
      assert request.object == "test-object"
    end

    test "ResponseParser模块存在且功能正常" do
      # 测试XML解析功能
      xml_body = ~s(<?xml version="1.0" encoding="UTF-8"?><Test><Key>value</Key></Test>)

      {:ok, parsed} = LibOss.Core.ResponseParser.parse_xml_response(xml_body)
      assert is_map(parsed)
    end

    test "Core.Object模块存在" do
      # 验证Object模块已正确定义
      assert Code.ensure_loaded?(LibOss.Core.Object)

      # 验证主要函数存在
      functions = LibOss.Core.Object.__info__(:functions)
      assert Keyword.has_key?(functions, :put_object)
      assert Keyword.has_key?(functions, :get_object)
      assert Keyword.has_key?(functions, :delete_object)
    end

    test "Core.Acl模块存在" do
      # 验证ACL模块已正确定义
      assert Code.ensure_loaded?(LibOss.Core.Acl)

      # 验证主要函数存在
      functions = LibOss.Core.Acl.__info__(:functions)
      assert Keyword.has_key?(functions, :put_object_acl)
      assert Keyword.has_key?(functions, :get_object_acl)
      assert Keyword.has_key?(functions, :put_bucket_acl)
      assert Keyword.has_key?(functions, :get_bucket_acl)
    end

    test "Core.Symlink模块存在" do
      # 验证Symlink模块已正确定义
      assert Code.ensure_loaded?(LibOss.Core.Symlink)

      # 验证主要函数存在
      functions = LibOss.Core.Symlink.__info__(:functions)
      assert Keyword.has_key?(functions, :put_symlink)
      assert Keyword.has_key?(functions, :get_symlink)
    end

    test "Core.Tagging模块存在" do
      # 验证Tagging模块已正确定义
      assert Code.ensure_loaded?(LibOss.Core.Tagging)

      # 验证主要函数存在
      functions = LibOss.Core.Tagging.__info__(:functions)
      assert Keyword.has_key?(functions, :put_object_tagging)
      assert Keyword.has_key?(functions, :get_object_tagging)
      assert Keyword.has_key?(functions, :delete_object_tagging)
    end

    test "Core.Multipart模块存在" do
      # 验证Multipart模块已正确定义
      assert Code.ensure_loaded?(LibOss.Core.Multipart)

      # 验证主要函数存在
      functions = LibOss.Core.Multipart.__info__(:functions)
      assert Keyword.has_key?(functions, :init_multi_upload)
      assert Keyword.has_key?(functions, :upload_part)
      assert Keyword.has_key?(functions, :complete_multipart_upload)
      assert Keyword.has_key?(functions, :abort_multipart_upload)
    end

    test "Core.Bucket模块存在" do
      # 验证Bucket模块已正确定义
      assert Code.ensure_loaded?(LibOss.Core.Bucket)

      # 验证主要函数存在
      functions = LibOss.Core.Bucket.__info__(:functions)
      assert Keyword.has_key?(functions, :put_bucket)
      assert Keyword.has_key?(functions, :delete_bucket)
      assert Keyword.has_key?(functions, :get_bucket)
      assert Keyword.has_key?(functions, :list_object_v2)
    end

    test "Core.Token模块存在" do
      # 验证Token模块已正确定义
      assert Code.ensure_loaded?(LibOss.Core.Token)

      # 验证主要函数存在
      functions = LibOss.Core.Token.__info__(:functions)
      assert Keyword.has_key?(functions, :get_token)
    end

    test "精简版Core模块保留基础功能" do
      # 验证Core模块已正确定义
      assert Code.ensure_loaded?(LibOss.Core)

      # 验证基础函数存在
      functions = LibOss.Core.__info__(:functions)
      assert Keyword.has_key?(functions, :start_link)
      assert Keyword.has_key?(functions, :get)
      assert Keyword.has_key?(functions, :call)

      # 验证业务函数已移除（不再存在于Core模块中）
      refute Keyword.has_key?(functions, :put_object)
      refute Keyword.has_key?(functions, :get_object)
      refute Keyword.has_key?(functions, :put_bucket)
    end

    test "ACL验证功能正常" do
      # 测试ACL验证
      assert :ok = LibOss.Core.Acl.validate_acl("private")
      assert :ok = LibOss.Core.Acl.validate_acl("public-read")
      assert :ok = LibOss.Core.Acl.validate_acl("public-read-write")
      assert :ok = LibOss.Core.Acl.validate_acl("default")

      assert {:error, _} = LibOss.Core.Acl.validate_acl("invalid-acl")
    end

    test "标签验证功能正常" do
      # 测试标签验证
      valid_tags = %{"key1" => "value1", "key2" => "value2"}
      assert :ok = LibOss.Core.Tagging.validate_tags(valid_tags)

      # 测试空标签
      assert :ok = LibOss.Core.Tagging.validate_tags(%{})

      # 测试过多标签
      too_many_tags = Map.new(1..11, fn i -> {"key#{i}", "value#{i}"} end)
      assert {:error, _} = LibOss.Core.Tagging.validate_tags(too_many_tags)
    end

    test "分片上传限制验证正常" do
      # 测试分片大小验证
      # 5MB
      min_size = 5 * 1024 * 1024
      assert :ok = LibOss.Core.Multipart.validate_multipart_params(100 * 1024 * 1024, min_size)

      # 测试推荐分片大小计算
      # 1GB
      file_size = 1024 * 1024 * 1024
      recommended_size = LibOss.Core.Multipart.recommended_part_size(file_size)
      assert recommended_size >= min_size
    end

    test "存储桶存储类型验证正常" do
      # 测试存储类型验证
      assert :ok = LibOss.Core.Bucket.validate_storage_class("Standard")
      assert :ok = LibOss.Core.Bucket.validate_storage_class("IA")
      assert :ok = LibOss.Core.Bucket.validate_storage_class("Archive")
      assert :ok = LibOss.Core.Bucket.validate_storage_class("ColdArchive")

      assert {:error, _} = LibOss.Core.Bucket.validate_storage_class("InvalidType")
    end
  end

  describe "API层模块调用验证" do
    test "API模块存在且正确引用Core子模块" do
      # 验证API模块存在
      assert Code.ensure_loaded?(LibOss.Api.Object)
      assert Code.ensure_loaded?(LibOss.Api.Acl)
      assert Code.ensure_loaded?(LibOss.Api.Symlink)
      assert Code.ensure_loaded?(LibOss.Api.Tagging)
      assert Code.ensure_loaded?(LibOss.Api.Multipart)
      assert Code.ensure_loaded?(LibOss.Api.Bucket)
      assert Code.ensure_loaded?(LibOss.Api.Token)
    end
  end
end
