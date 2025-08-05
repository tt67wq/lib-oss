defmodule LibOss.Core.RequestBuilder do
  @moduledoc """
  请求构建模块，负责统一的请求构建逻辑、认证处理和URL构建
  """

  alias LibOss.Model.Config
  alias LibOss.Model.Http
  alias LibOss.Model.Request

  @doc """
  构建HTTP请求

  ## 参数
  - config: 配置信息
  - req: OSS请求结构

  ## 返回值
  - HTTP请求结构
  """
  @spec build_http_request(Config.t(), Request.t()) :: Http.Request.t()
  def build_http_request(config, req) do
    req =
      req
      |> Request.build_headers(config)
      |> Request.auth(config)

    endpoint = config[:endpoint]
    %Request{host: host, bucket: bucket, sub_resources: sub_resources, object: object, debug: debug} = req

    host = build_host(host, bucket, endpoint)
    path = build_path(object, sub_resources)

    # 构建HTTP请求
    %Http.Request{
      scheme: "https",
      port: 443,
      host: host,
      method: req.method,
      path: path,
      headers: req.headers,
      body: req.body,
      params: req.params,
      opts: [debug: debug]
    }
  end

  @doc """
  构建主机名

  ## 参数
  - host: 指定的主机名
  - bucket: 存储桶名称
  - endpoint: OSS端点

  ## 返回值
  - 完整的主机名
  """
  @spec build_host(binary(), binary(), binary()) :: binary()
  def build_host(host, bucket, endpoint) do
    if host != "" do
      host
    else
      case bucket do
        "" -> endpoint
        _ -> "#{bucket}.#{endpoint}"
      end
    end
  end

  @doc """
  构建请求路径

  ## 参数
  - object: 对象名称
  - sub_resources: 子资源参数

  ## 返回值
  - 完整的请求路径
  """
  @spec build_path(binary(), list()) :: binary()
  def build_path(object, sub_resources) do
    object_with_query =
      sub_resources
      |> Enum.map_join("&", fn
        {k, nil} -> k
        {k, v} -> "#{k}=#{v}"
      end)
      |> case do
        "" -> object
        query_string -> "#{object}?#{query_string}"
      end

    Path.join(["/", object_with_query])
  end

  @doc """
  构建基础请求结构

  ## 参数
  - method: HTTP方法
  - bucket: 存储桶名称
  - object: 对象名称
  - opts: 可选参数

  ## 返回值
  - 请求结构
  """
  @spec build_base_request(atom(), binary(), binary(), keyword()) :: Request.t()
  def build_base_request(method, bucket, object, opts \\ []) do
    resource = build_resource(bucket, object)

    %Request{
      method: method,
      bucket: bucket,
      object: object,
      resource: resource,
      host: Keyword.get(opts, :host, ""),
      headers: Keyword.get(opts, :headers, []),
      body: Keyword.get(opts, :body, ""),
      params: Keyword.get(opts, :params, %{}),
      sub_resources: Keyword.get(opts, :sub_resources, []),
      debug: Keyword.get(opts, :debug, false)
    }
  end

  @doc """
  添加查询参数到请求

  ## 参数
  - request: 请求结构
  - params: 查询参数

  ## 返回值
  - 更新后的请求结构
  """
  @spec add_query_params(Request.t(), map()) :: Request.t()
  def add_query_params(%Request{} = request, params) when is_map(params) do
    updated_params = Map.merge(request.params, params)
    %{request | params: updated_params}
  end

  @doc """
  添加子资源到请求

  ## 参数
  - request: 请求结构
  - sub_resources: 子资源列表

  ## 返回值
  - 更新后的请求结构
  """
  @spec add_sub_resources(Request.t(), list()) :: Request.t()
  def add_sub_resources(%Request{} = request, sub_resources) when is_list(sub_resources) do
    updated_sub_resources = request.sub_resources ++ sub_resources
    %{request | sub_resources: updated_sub_resources}
  end

  @doc """
  添加请求头到请求

  ## 参数
  - request: 请求结构
  - headers: 请求头列表

  ## 返回值
  - 更新后的请求结构
  """
  @spec add_headers(Request.t(), list()) :: Request.t()
  def add_headers(%Request{} = request, headers) when is_list(headers) do
    updated_headers = request.headers ++ headers
    %{request | headers: updated_headers}
  end

  @doc """
  设置请求体

  ## 参数
  - request: 请求结构
  - body: 请求体内容

  ## 返回值
  - 更新后的请求结构
  """
  @spec set_body(Request.t(), binary()) :: Request.t()
  def set_body(%Request{} = request, body) when is_binary(body) do
    %{request | body: body}
  end

  @spec build_resource(binary(), binary()) :: binary()
  defp build_resource(bucket, object) do
    case {bucket, object} do
      {"", ""} -> "/"
      {bucket, ""} -> Path.join(["/", bucket]) <> "/"
      {bucket, object} -> Path.join(["/", bucket, object])
    end
  end
end
