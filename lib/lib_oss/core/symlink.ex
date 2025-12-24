defmodule LibOss.Core.Symlink do
  @moduledoc """
  符号链接模块

  负责：
  - put_symlink: 创建符号链接
  - get_symlink: 获取符号链接目标
  """

  alias LibOss.Core
  alias LibOss.Core.RequestBuilder
  alias LibOss.Exception
  alias LibOss.Model.Http
  alias LibOss.Typespecs

  @type err_t() :: {:error, Exception.t()}

  @doc """
  创建符号链接

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 符号链接对象名称
  - target_object: 目标对象名称
  - headers: 可选的HTTP请求头

  ## 返回值
  - :ok | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Symlink.put_symlink(MyOss, "my-bucket", "link-object", "target-object")
      :ok

  ## 相关文档
  https://help.aliyun.com/document_detail/45126.html
  """
  @spec put_symlink(module(), Typespecs.bucket(), Typespecs.object(), binary(), Typespecs.headers()) ::
          :ok | err_t()
  def put_symlink(name, bucket, object, target_object, headers \\ []) do
    symlink_header = {"x-oss-symlink-target", target_object}

    req =
      RequestBuilder.build_base_request(:put, bucket, object,
        headers: [symlink_header | headers],
        sub_resources: [{"symlink", nil}]
      )

    with {:ok, _} <- Core.call(name, req), do: :ok
  end

  @doc """
  获取符号链接目标

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 符号链接对象名称

  ## 返回值
  - {:ok, binary()} | {:error, Exception.t()}

  返回符号链接指向的目标对象名称

  ## 示例
      iex> LibOss.Core.Symlink.get_symlink(MyOss, "my-bucket", "link-object")
      {:ok, "target-object"}

  ## 相关文档
  https://help.aliyun.com/document_detail/45146.html
  """
  @spec get_symlink(module(), Typespecs.bucket(), Typespecs.object()) :: {:ok, binary()} | err_t()
  def get_symlink(name, bucket, object) do
    req =
      RequestBuilder.build_base_request(:get, bucket, object, sub_resources: [{"symlink", nil}])

    with {:ok, %Http.Response{headers: headers}} <- Core.call(name, req) do
      case find_symlink_target_header(headers) do
        {:ok, target} ->
          {:ok, URI.decode(target)}

        :error ->
          {:error, Exception.new("symlink_target_not_found: x-oss-symlink-target header not found", "missing_header")}
      end
    end
  end

  @doc """
  检查对象是否为符号链接

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 对象名称

  ## 返回值
  - boolean()

  ## 示例
      iex> LibOss.Core.Symlink.symlink?(MyOss, "my-bucket", "link-object")
      true

      iex> LibOss.Core.Symlink.symlink?(MyOss, "my-bucket", "normal-object")
      false
  """
  @spec symlink?(module(), Typespecs.bucket(), Typespecs.object()) :: boolean()
  def symlink?(name, bucket, object) do
    case get_symlink(name, bucket, object) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  获取符号链接的元数据（包括目标对象）

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 符号链接对象名称

  ## 返回值
  - {:ok, map()} | {:error, Exception.t()}

  返回的map包含：
  - target: 目标对象名称
  - headers: 其他响应头信息

  ## 示例
      iex> LibOss.Core.Symlink.get_symlink_meta(MyOss, "my-bucket", "link-object")
      {:ok, %{
        target: "target-object",
        headers: %{"content-type" => "application/octet-stream", ...}
      }}
  """
  @spec get_symlink_meta(module(), Typespecs.bucket(), Typespecs.object()) :: {:ok, map()} | err_t()
  def get_symlink_meta(name, bucket, object) do
    req =
      RequestBuilder.build_base_request(:get, bucket, object, sub_resources: [{"symlink", nil}])

    with {:ok, %Http.Response{headers: headers}} <- Core.call(name, req) do
      case find_symlink_target_header(headers) do
        {:ok, target} ->
          {:ok,
           %{
             target: URI.decode(target),
             headers: Map.new(headers)
           }}

        :error ->
          {:error, Exception.new("symlink_target_not_found: x-oss-symlink-target header not found", "missing_header")}
      end
    end
  end

  @doc """
  创建符号链接并设置自定义元数据

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 符号链接对象名称
  - target_object: 目标对象名称
  - metadata: 自定义元数据map

  ## 返回值
  - :ok | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Symlink.put_symlink_with_metadata(MyOss, "my-bucket", "link-object", "target-object", %{"description" => "My symlink"})
      :ok
  """
  @spec put_symlink_with_metadata(module(), Typespecs.bucket(), Typespecs.object(), binary(), map()) ::
          :ok | err_t()
  def put_symlink_with_metadata(name, bucket, object, target_object, metadata) when is_map(metadata) do
    metadata_headers =
      Enum.map(metadata, fn {k, v} ->
        {"x-oss-meta-#{k}", to_string(v)}
      end)

    put_symlink(name, bucket, object, target_object, metadata_headers)
  end

  # 私有辅助函数

  defp find_symlink_target_header(headers) do
    headers
    |> Enum.find(fn
      {"x-oss-symlink-target", _} -> true
      {"X-Oss-Symlink-Target", _} -> true
      _ -> false
    end)
    |> case do
      {_, value} -> {:ok, value}
      nil -> :error
    end
  end
end
