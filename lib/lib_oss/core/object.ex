defmodule LibOss.Core.Object do
  @moduledoc """
  对象操作模块

  负责基础对象操作：
  - 基础对象操作：put_object, get_object, delete_object, copy_object
  - 追加写：append_object
  - 元数据：head_object, get_object_meta
  - 批量删除：delete_multiple_objects
  """

  alias LibOss.Core
  alias LibOss.Core.RequestBuilder
  alias LibOss.Exception
  alias LibOss.Model.Http
  alias LibOss.Typespecs

  @type err_t() :: {:error, Exception.t()}

  @doc """
  上传对象

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 对象名称
  - data: 对象数据
  - headers: 可选的HTTP请求头

  ## 返回值
  - :ok | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Object.put_object(MyOss, "my-bucket", "my-object", "Hello World")
      :ok
  """
  @spec put_object(module(), Typespecs.bucket(), Typespecs.object(), iodata(), Typespecs.headers()) :: :ok | err_t()
  def put_object(name, bucket, object, data, headers \\ []) do
    req =
      RequestBuilder.build_base_request(:put, bucket, object,
        body: data,
        headers: headers
      )

    with {:ok, _} <- Core.call(name, req), do: :ok
  end

  @doc """
  复制对象

  ## 参数
  - name: Agent进程名称
  - bucket: 目标存储桶名称
  - object: 目标对象名称
  - source_bucket: 源存储桶名称
  - source_object: 源对象名称
  - headers: 可选的HTTP请求头

  ## 返回值
  - :ok | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Object.copy_object(MyOss, "dest-bucket", "dest-object", "src-bucket", "src-object")
      :ok
  """
  @spec copy_object(
          module(),
          Typespecs.bucket(),
          Typespecs.object(),
          Typespecs.bucket(),
          Typespecs.object(),
          Typespecs.headers()
        ) :: :ok | err_t()
  def copy_object(name, bucket, object, source_bucket, source_object, headers \\ []) do
    copy_source_header = {"x-oss-copy-source", Path.join(["/", source_bucket, source_object])}

    req =
      RequestBuilder.build_base_request(:put, bucket, object, headers: [copy_source_header | headers])

    with {:ok, _} <- Core.call(name, req), do: :ok
  end

  @doc """
  获取对象

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 对象名称
  - req_headers: 可选的HTTP请求头

  ## 返回值
  - {:ok, binary()} | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Object.get_object(MyOss, "my-bucket", "my-object")
      {:ok, "Hello World"}
  """
  @spec get_object(module(), Typespecs.bucket(), Typespecs.object(), Typespecs.headers()) :: {:ok, binary()} | err_t()
  def get_object(name, bucket, object, req_headers \\ []) do
    req =
      RequestBuilder.build_base_request(:get, bucket, object, headers: req_headers)

    with {:ok, %Http.Response{body: body}} <- Core.call(name, req), do: {:ok, body}
  end

  @doc """
  删除对象

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 对象名称

  ## 返回值
  - :ok | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Object.delete_object(MyOss, "my-bucket", "my-object")
      :ok
  """
  @spec delete_object(module(), Typespecs.bucket(), Typespecs.object()) :: :ok | err_t()
  def delete_object(name, bucket, object) do
    req = RequestBuilder.build_base_request(:delete, bucket, object)

    with {:ok, _} <- Core.call(name, req), do: :ok
  end

  @doc """
  批量删除对象

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - objects: 对象名称列表

  ## 返回值
  - :ok | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Object.delete_multiple_objects(MyOss, "my-bucket", ["obj1", "obj2", "obj3"])
      :ok
  """
  @spec delete_multiple_objects(module(), Typespecs.bucket(), [Typespecs.object()]) :: :ok | err_t()
  def delete_multiple_objects(name, bucket, objects) do
    body = build_delete_xml(objects)

    req =
      RequestBuilder.build_base_request(:post, bucket, "",
        body: body,
        sub_resources: [{"delete", nil}]
      )

    with {:ok, _} <- Core.call(name, req), do: :ok
  end

  @doc """
  追加写对象

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 对象名称
  - since: 追加位置
  - data: 追加的数据
  - headers: 可选的HTTP请求头

  ## 返回值
  - :ok | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Object.append_object(MyOss, "my-bucket", "my-object", 0, "Hello")
      :ok
  """
  @spec append_object(module(), Typespecs.bucket(), Typespecs.object(), non_neg_integer(), binary(), Typespecs.headers()) ::
          :ok | err_t()
  def append_object(name, bucket, object, since, data, headers \\ []) do
    req =
      RequestBuilder.build_base_request(:post, bucket, object,
        body: data,
        headers: headers,
        sub_resources: [{"append", nil}, {"position", "#{since}"}]
      )

    with {:ok, _} <- Core.call(name, req), do: :ok
  end

  @doc """
  获取对象头部信息

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 对象名称
  - headers: 可选的HTTP请求头

  ## 返回值
  - {:ok, map()} | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Object.head_object(MyOss, "my-bucket", "my-object")
      {:ok, %{"content-length" => "11", "content-type" => "text/plain"}}
  """
  @spec head_object(module(), Typespecs.bucket(), Typespecs.object(), Typespecs.headers()) ::
          {:ok, Typespecs.dict()} | err_t()
  def head_object(name, bucket, object, headers \\ []) do
    req =
      RequestBuilder.build_base_request(:head, bucket, object, headers: headers)

    with {:ok, %Http.Response{headers: response_headers}} <- Core.call(name, req) do
      {:ok, Map.new(response_headers)}
    end
  end

  @doc """
  获取对象元数据

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 对象名称

  ## 返回值
  - {:ok, map()} | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Object.get_object_meta(MyOss, "my-bucket", "my-object")
      {:ok, %{"content-length" => "11", "etag" => "\"5d41402abc4b2a76b9719d911017c592\""}}
  """
  @spec get_object_meta(module(), Typespecs.bucket(), Typespecs.object()) ::
          {:ok, Typespecs.dict()} | err_t()
  def get_object_meta(name, bucket, object) do
    head_object(name, bucket, object)
  end

  @doc """
  检查对象是否存在

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 对象名称

  ## 返回值
  - boolean()

  ## 示例
      iex> LibOss.Core.Object.object_exists?(MyOss, "my-bucket", "my-object")
      true
  """
  @spec object_exists?(module(), Typespecs.bucket(), Typespecs.object()) :: boolean()
  def object_exists?(name, bucket, object) do
    case head_object(name, bucket, object) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  获取对象大小

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 对象名称

  ## 返回值
  - {:ok, non_neg_integer()} | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Object.get_object_size(MyOss, "my-bucket", "my-object")
      {:ok, 1024}
  """
  @spec get_object_size(module(), Typespecs.bucket(), Typespecs.object()) :: {:ok, non_neg_integer()} | err_t()
  def get_object_size(name, bucket, object) do
    case head_object(name, bucket, object) do
      {:ok, headers} ->
        case Map.get(headers, "content-length") do
          nil -> {:error, Exception.new(:missing_content_length, "Content-Length header not found")}
          size_str -> {:ok, String.to_integer(size_str)}
        end

      {:error, _} = error ->
        error
    end
  end

  # 私有辅助函数

  defp build_delete_xml(objects) do
    objects_xml =
      Enum.map_join(objects, "", fn object ->
        "<Object><Key>#{escape_xml(object)}</Key></Object>"
      end)

    "<Delete><Quiet>true</Quiet>#{objects_xml}</Delete>"
  end

  defp escape_xml(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
