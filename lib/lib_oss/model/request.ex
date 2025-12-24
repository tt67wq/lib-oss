defmodule LibOss.Model.Request do
  @moduledoc """
  OSS请求模型和签名模块。

  此模块负责构建、签名和验证OSS API请求，确保所有请求都符合阿里云OSS的认证规范。
  主要功能包括：

  ## 功能特性

  1. **HTTP头部构建** - 自动生成标准HTTP头部（Host、Content-Type、Date等）
  2. **OSS签名生成** - 实现OSS专用的HMAC-SHA1签名算法
  3. **资源规范化** - 按OSS规范格式化CanonicalizedResource
  4. **多协议支持** - 支持HTTP/HTTPS和RTMP协议
  5. **调试支持** - 可选开启调试模式输出签名信息

  ## 签名流程

  OSS使用标准的HTTP Authorization头部进行认证：

  ```
  Authorization: OSS <access_key_id>:<signature>
  ```

  签名计算过程：
  1. 构建StringToSign字符串
  2. 使用HMAC-SHA1算法计算签名
  3. 将签名添加到Authorization头部

  ## 使用示例

      iex> request = %LibOss.Model.Request{
      ...>   bucket: "my-bucket",
      ...>   object: "path/to/file.txt",
      ...>   method: :get,
      ...>   body: ""
      ...> }
      iex> config = %{endpoint: "oss-cn-hangzhou.aliyuncs.com", access_key_id: "KEY", access_key_secret: "SECRET"}
      iex> signed_request = LibOss.Model.Request.build_headers(request, config) |> LibOss.Model.Request.auth(config)

  ## 字段说明

  - `host`: 请求主机地址
  - `method`: HTTP方法（:get, :post, :put, :delete等）
  - `object`: OSS对象名称
  - `resource`: 资源路径
  - `bucket`: 存储桶名称
  - `headers`: HTTP头部列表
  - `body`: 请求体
  - `params`: URL参数
  - `expires`: 过期时间戳
  - `debug`: 是否开启调试模式

  ## 相关文档

  - [OSS签名和验证](https://help.aliyun.com/document_detail/100392.html)
  - [HTTP Authorization头部规范](https://help.aliyun.com/document_detail/100385.html)
  """

  alias LibOss.Model.Config
  alias LibOss.Typespecs

  @type t :: %__MODULE__{
          host: Typespecs.host(),
          method: Typespecs.method(),
          object: String.t(),
          resource: String.t(),
          sub_resources: [{String.t(), String.t() | nil}],
          bucket: Typespecs.bucket(),
          params: Typespecs.params(),
          body: Typespecs.body(),
          headers: Typespecs.headers(),
          expires: non_neg_integer(),
          debug: boolean()
        }

  @verbs %{
    post: "POST",
    get: "GET",
    put: "PUT",
    delete: "DELETE",
    head: "HEAD",
    options: "OPTIONS",
    patch: "PATCH"
  }

  defstruct host: "",
            method: :post,
            object: "",
            resource: "",
            sub_resources: [],
            bucket: "",
            params: %{},
            body: "",
            headers: [],
            expires: 0,
            debug: false

  @spec build_headers(t(), Config.t()) :: t()
  def build_headers(%__MODULE__{} = request, config) do
    endpoint = config[:endpoint]

    host =
      case request.bucket do
        "" -> endpoint
        _ -> request.bucket <> "." <> endpoint
      end

    headers = [
      {"Host", host},
      {"Content-Type", content_type(request)},
      {"Content-MD5", content_md5(request)},
      {"Content-Length", request.body |> byte_size() |> to_string()},
      {"Date", gmt_now()} | request.headers
    ]

    %__MODULE__{request | headers: headers}
  end

  @spec auth(t(), Config.t()) :: t()
  def auth(%__MODULE__{} = request, config) do
    headers = [
      {"Authorization", "OSS #{config[:access_key_id]}:#{signature(request, config)}"}
      | request.headers
    ]

    %__MODULE__{request | headers: headers}
  end

  defp content_type(%{resource: resource, headers: headers}) do
    headers
    |> Enum.find(fn {k, _} -> k in ["Content-Type", "content-type"] end)
    |> case do
      nil -> content_type_from_resource(resource)
      {_, v} -> v
    end
  end

  defp content_type_from_resource(resource) do
    case Path.extname(resource) do
      "." <> name -> MIME.type(name)
      _ -> "application/octet-stream"
    end
  end

  defp content_md5(%{body: ""}), do: ""

  defp content_md5(%{body: body}) do
    :md5
    |> :crypto.hash(body)
    |> Base.encode64()
  end

  @spec gmt_now() :: binary()
  defp gmt_now do
    {:ok, dt} = DateTime.now("Etc/UTC")
    Calendar.strftime(dt, "%a, %d %b %Y %H:%M:%S GMT")
  end

  @spec signature(t(), Config.t()) :: binary()
  defp signature(request, config) do
    request
    |> string_to_sign()
    |> tap(fn x ->
      if request.debug do
        LibOss.Debug.stacktrace(%{
          request: request,
          config: config,
          string_to_sign: x
        })
      end
    end)
    |> LibOss.Utils.do_sign(config[:access_key_secret])
  end

  # POST
  #
  # application/octet-stream
  # Tue, 05 Aug 2025 06:11:27 GMT
  # /hope-data/test/multi-test.txt?uploads
  @spec string_to_sign(t()) :: binary()
  defp string_to_sign(%{scheme: "rtmp"} = request) do
    Enum.join(
      [
        expire_time(request),
        canonicalize_query_params(request) <> canonicalize_resource(request)
      ],
      "\n"
    )
  end

  defp string_to_sign(%__MODULE__{method: method} = request) do
    Enum.join(
      [
        "#{@verbs[method]}",
        get_header(request, "Content-MD5"),
        get_header(request, "Content-Type"),
        expires_time(request),
        canonicalize_oss_headers(request) <> canonicalize_resource(request)
      ],
      "\n"
    )
  end

  defp canonicalize_oss_headers(%{headers: headers}) do
    headers
    |> Stream.filter(&oss_header?/1)
    |> Enum.map_join("\n", &encode_header/1)
    |> case do
      "" -> ""
      str -> str <> "\n"
    end
  end

  defp oss_header?({h, _}) do
    Regex.match?(~r/^x-oss-/i, to_string(h))
  end

  defp encode_header({h, v}) do
    (h |> to_string() |> String.downcase()) <> ":" <> to_string(v)
  end

  # 发送请求中希望访问的OSS目标资源被称为CanonicalizedResource，构建方法如下：

  # 如果既有BucketName也有ObjectName，则则CanonicalizedResource格式为/BucketName/ObjectName
  # 如果仅有BucketName而没有ObjectName，则CanonicalizedResource格式为/BucketName/。
  # 如果既没有BucketName也没有ObjectName，则CanonicalizedResource为正斜线（/）。
  # 如果请求的资源包括子资源（SubResource），则所有的子资源需按照字典序升序排列，并以&为分隔符生成子资源字符串。
  defp canonicalize_resource(%{resource: resource, sub_resources: nil}), do: resource

  defp canonicalize_resource(%{resource: resource, sub_resources: sub_resources}) do
    sub_resources
    |> Enum.map_join("&", fn
      {k, nil} -> k
      {k, v} -> "#{k}=#{v}"
    end)
    |> case do
      "" -> resource
      query_string -> resource <> "?" <> query_string
    end
  end

  defp canonicalize_query_params(%{params: params}) do
    params
    |> Stream.map(fn {k, v} -> "#{k}:#{v}\n" end)
    |> Enum.join()
  end

  @spec expires_time(t()) :: binary()
  defp expires_time(%{expires: 0} = request) do
    request
    |> get_header("Date")
    |> to_string()
  end

  defp expire_time(%{expires: expires}), do: to_string(expires)

  @spec get_header(t(), String.t()) :: binary()
  defp get_header(%__MODULE__{headers: headers}, header_key) do
    headers
    |> Enum.find(fn {k, _} -> k == header_key end)
    |> then(fn
      {_, v} -> v
      nil -> ""
    end)
  end
end
