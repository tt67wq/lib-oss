defmodule LibOss.Core.RequestBuilderTest do
  use ExUnit.Case, async: true

  alias LibOss.Core.RequestBuilder
  alias LibOss.Model.Request

  describe "build_base_request/4" do
    test "构建基础请求结构包含所有必需字段" do
      method = :get
      bucket = "test-bucket"
      object = "test-object.txt"

      request = RequestBuilder.build_base_request(method, bucket, object)

      assert %Request{} = request
      assert request.method == :get
      assert request.bucket == "test-bucket"
      assert request.object == "test-object.txt"
      assert request.resource == "/test-bucket/test-object.txt"
      assert request.host == ""
      assert request.headers == []
      assert request.body == ""
      assert request.params == %{}
      assert request.sub_resources == []
      assert request.debug == false
    end

    test "构建请求时正确处理空bucket和object" do
      request = RequestBuilder.build_base_request(:get, "", "")
      assert request.resource == "/"
    end

    test "构建请求时正确处理只有bucket没有object" do
      request = RequestBuilder.build_base_request(:get, "test-bucket", "")
      assert request.resource == "/test-bucket/"
    end

    test "构建请求时支持可选参数" do
      opts = [
        host: "custom-host.com",
        headers: [{"Content-Type", "application/json"}],
        body: "test body",
        params: %{"key" => "value"},
        sub_resources: [{"acl", nil}],
        debug: true
      ]

      request = RequestBuilder.build_base_request(:post, "bucket", "object", opts)

      assert request.host == "custom-host.com"
      assert request.headers == [{"Content-Type", "application/json"}]
      assert request.body == "test body"
      assert request.params == %{"key" => "value"}
      assert request.sub_resources == [{"acl", nil}]
      assert request.debug == true
    end
  end

  describe "add_query_params/2" do
    test "添加查询参数到现有请求" do
      request = RequestBuilder.build_base_request(:get, "bucket", "object")
      params = %{"limit" => "10", "marker" => "abc"}

      updated_request = RequestBuilder.add_query_params(request, params)

      assert updated_request.params == %{"limit" => "10", "marker" => "abc"}
    end

    test "合并查询参数到现有参数" do
      opts = [params: %{"existing" => "value"}]
      request = RequestBuilder.build_base_request(:get, "bucket", "object", opts)
      new_params = %{"new" => "param"}

      updated_request = RequestBuilder.add_query_params(request, new_params)

      assert updated_request.params == %{"existing" => "value", "new" => "param"}
    end
  end

  describe "add_sub_resources/2" do
    test "添加子资源到请求" do
      request = RequestBuilder.build_base_request(:get, "bucket", "object")
      sub_resources = [{"acl", nil}, {"tagging", nil}]

      updated_request = RequestBuilder.add_sub_resources(request, sub_resources)

      assert updated_request.sub_resources == [{"acl", nil}, {"tagging", nil}]
    end

    test "追加子资源到现有子资源" do
      opts = [sub_resources: [{"existing", "value"}]]
      request = RequestBuilder.build_base_request(:get, "bucket", "object", opts)
      new_sub_resources = [{"new", nil}]

      updated_request = RequestBuilder.add_sub_resources(request, new_sub_resources)

      assert updated_request.sub_resources == [{"existing", "value"}, {"new", nil}]
    end
  end

  describe "add_headers/2" do
    test "添加请求头到请求" do
      request = RequestBuilder.build_base_request(:get, "bucket", "object")
      headers = [{"Authorization", "Bearer token"}, {"Content-Type", "application/json"}]

      updated_request = RequestBuilder.add_headers(request, headers)

      assert updated_request.headers == [{"Authorization", "Bearer token"}, {"Content-Type", "application/json"}]
    end

    test "追加请求头到现有请求头" do
      opts = [headers: [{"Existing", "header"}]]
      request = RequestBuilder.build_base_request(:get, "bucket", "object", opts)
      new_headers = [{"New", "header"}]

      updated_request = RequestBuilder.add_headers(request, new_headers)

      assert updated_request.headers == [{"Existing", "header"}, {"New", "header"}]
    end
  end

  describe "set_body/2" do
    test "设置请求体" do
      request = RequestBuilder.build_base_request(:post, "bucket", "object")
      body = "test request body"

      updated_request = RequestBuilder.set_body(request, body)

      assert updated_request.body == "test request body"
    end
  end

  describe "build_host/3" do
    test "使用指定的主机名" do
      host = RequestBuilder.build_host("custom-host.com", "bucket", "endpoint.com")
      assert host == "custom-host.com"
    end

    test "没有bucket时使用endpoint" do
      host = RequestBuilder.build_host("", "", "oss-cn-hangzhou.aliyuncs.com")
      assert host == "oss-cn-hangzhou.aliyuncs.com"
    end

    test "有bucket时拼接bucket和endpoint" do
      host = RequestBuilder.build_host("", "my-bucket", "oss-cn-hangzhou.aliyuncs.com")
      assert host == "my-bucket.oss-cn-hangzhou.aliyuncs.com"
    end
  end

  describe "build_path/2" do
    test "构建没有子资源的对象路径" do
      path = RequestBuilder.build_path("test-object.txt", [])
      assert path == "/test-object.txt"
    end

    test "构建带有子资源的对象路径" do
      sub_resources = [{"acl", nil}, {"versionId", "123"}]
      path = RequestBuilder.build_path("test-object.txt", sub_resources)
      assert path == "/test-object.txt?acl&versionId=123"
    end

    test "构建空对象路径" do
      path = RequestBuilder.build_path("", [])
      assert path == "/"
    end

    test "构建根路径带查询参数" do
      sub_resources = [{"uploads", nil}]
      path = RequestBuilder.build_path("", sub_resources)
      assert path == "/?uploads"
    end
  end

  describe "integration with Request signing" do
    test "验证resource字段在签名生成中正确使用" do
      # 模拟配置
      config = [
        endpoint: "oss-cn-hangzhou.aliyuncs.com",
        access_key_id: "test_key_id",
        access_key_secret: "test_secret"
      ]

      # 构建请求
      request = RequestBuilder.build_base_request(:get, "test-bucket", "test-object.txt")

      # 验证resource字段正确设置
      assert request.resource == "/test-bucket/test-object.txt"

      # 构建完整的HTTP请求以验证签名流程不会报错
      http_request = RequestBuilder.build_http_request(config, request)

      # 验证HTTP请求构建成功
      assert %LibOss.Model.Http.Request{} = http_request
      assert http_request.host == "test-bucket.oss-cn-hangzhou.aliyuncs.com"
      assert http_request.path == "/test-object.txt"
      assert http_request.method == :get
    end

    test "验证不同bucket/object组合的resource构建" do
      test_cases = [
        {"", "", "/"},
        {"bucket", "", "/bucket/"},
        {"bucket", "object", "/bucket/object"},
        {"my-bucket", "path/to/file.txt", "/my-bucket/path/to/file.txt"}
      ]

      for {bucket, object, expected_resource} <- test_cases do
        request = RequestBuilder.build_base_request(:get, bucket, object)

        assert request.resource == expected_resource,
               "Expected resource '#{expected_resource}' for bucket '#{bucket}' and object '#{object}', got '#{request.resource}'"
      end
    end
  end
end
