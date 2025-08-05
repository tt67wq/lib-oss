defmodule LibOss.Api.Object do
  @moduledoc """
  OSS对象操作相关API

  提供对象的基本CRUD操作，包括上传、下载、复制、删除、追加写等功能。
  """

  alias LibOss.Core
  alias LibOss.Typespecs

  @doc """
  调用PutObject接口上传文件（Object）。

  Doc: https://help.aliyun.com/document_detail/31978.html

  ## Examples

      iex> put_object(bucket, "/test/test.txt", "hello world")
      :ok
  """
  @spec put_object(module(), Typespecs.bucket(), Typespecs.object(), iodata(), Typespecs.headers()) ::
          :ok | {:error, LibOss.Exception.t()}
  def put_object(client, bucket, object, data, headers \\ []) do
    Core.put_object(client, bucket, object, data, headers)
  end

  @doc """
  GetObject接口用于获取某个文件（Object）。此操作需要对此Object具有读权限。

  Doc: https://help.aliyun.com/document_detail/31980.html

  req_headers的具体参数可参考文档中"请求头"部分说明

  ## Examples

      iex> get_object(bucket, "/test/test.txt")
      {:ok, "hello world"}
  """
  @spec get_object(module(), Typespecs.bucket(), Typespecs.object(), Typespecs.headers()) ::
          {:ok, binary()} | {:error, LibOss.Exception.t()}
  def get_object(client, bucket, object, req_headers \\ []) do
    Core.get_object(client, bucket, object, req_headers)
  end

  @doc """
  调用CopyObject接口拷贝同一地域下相同或不同存储空间（Bucket）之间的文件（Object）。

  Doc: https://help.aliyun.com/document_detail/31979.html

  ## Examples

      iex> copy_object(target_bucket, "object_copy.txt", source_bucket, "object.txt")
      :ok
  """
  @spec copy_object(
          module(),
          Typespecs.bucket(),
          Typespecs.object(),
          Typespecs.bucket(),
          Typespecs.object(),
          Typespecs.headers()
        ) :: :ok | {:error, LibOss.Exception.t()}
  def copy_object(client, bucket, object, source_bucket, source_object, headers \\ []) do
    Core.copy_object(client, bucket, object, source_bucket, source_object, headers)
  end

  @doc """
  调用DeleteObject删除某个文件（Object）。

  Doc: https://help.aliyun.com/document_detail/31982.html

  ## Examples

      iex> delete_object(bucket, "/test/test.txt")
      :ok
  """
  @spec delete_object(module(), Typespecs.bucket(), Typespecs.object()) :: :ok | {:error, LibOss.Exception.t()}
  def delete_object(client, bucket, object) do
    Core.delete_object(client, bucket, object)
  end

  @doc """
  DeleteMultipleObjects接口用于删除同一个存储空间（Bucket）中的多个文件（Object）。

  Doc: https://help.aliyun.com/document_detail/31983.html

  ## Examples

      iex> delete_multiple_objects(bucket, ["/test/test_1.txt", "/test/test_2.txt"])
      :ok
  """
  @spec delete_multiple_objects(module(), Typespecs.bucket(), [Typespecs.object()]) ::
          :ok | {:error, LibOss.Exception.t()}
  def delete_multiple_objects(client, bucket, objects) do
    Core.delete_multiple_objects(client, bucket, objects)
  end

  @doc """
  调用AppendObject接口用于以追加写的方式上传文件（Object）。

  Doc: https://help.aliyun.com/document_detail/31981.html

  ## Examples

      iex> append_object(bucket, "/test/test.txt", 0, "hello ")
      :ok
      iex> append_object(bucket, "/test/test.txt", 6, "world")
      :ok
  """
  @spec append_object(
          module(),
          Typespecs.bucket(),
          Typespecs.object(),
          non_neg_integer(),
          binary(),
          Typespecs.headers()
        ) :: :ok | {:error, LibOss.Exception.t()}
  def append_object(client, bucket, object, since, data, headers \\ []) do
    Core.append_object(client, bucket, object, since, data, headers)
  end

  @doc """
  HeadObject接口用于获取某个文件（Object）的元信息。使用此接口不会返回文件内容。

  Doc: https://help.aliyun.com/document_detail/31984.html

  ## Examples

      iex> head_object(bucket, "/test/test.txt")
      {:ok,
       %{
         "accept-ranges" => "bytes",
         "connection" => "keep-alive",
         "content-length" => "11",
         "content-md5" => "XrY7u+Ae7tCTyyK7j1rNww==",
         "content-type" => "text/plain",
         "date" => "Tue, 18 Jul 2023 06:27:36 GMT",
         "etag" => "\"5EB63BBBE01EEED093CB22BB8F5ACDC3\"",
         "last-modified" => "Tue, 18 Jul 2023 06:27:33 GMT",
         "server" => "AliyunOSS",
         "x-oss-hash-crc64ecma" => "5981764153023615706",
         "x-oss-object-type" => "Normal",
         "x-oss-request-id" => "64B630D8E0DCB93335001974",
         "x-oss-server-time" => "1",
         "x-oss-storage-class" => "Standard"
       }}
  """
  @spec head_object(module(), Typespecs.bucket(), Typespecs.object(), Typespecs.headers()) ::
          {:ok, Typespecs.dict()} | {:error, LibOss.Exception.t()}
  def head_object(client, bucket, object, headers \\ []) do
    Core.head_object(client, bucket, object, headers)
  end

  @doc """
  GetObjectMeta接口用于获取某个文件（Object）的基本元信息，包括该Object的ETag、Size、LastModified信息，并不返回该Object的内容。

  Doc: https://help.aliyun.com/document_detail/31985.html

  ## Examples

      iex> get_object_meta(bucket, "/test/test.txt")
      {:ok,
       %{
         "connection" => "keep-alive",
         "content-length" => "11",
         "date" => "Tue, 18 Jul 2023 06:27:36 GMT",
         "etag" => "\"5EB63BBBE01EEED093CB22BB8F5ACDC3\"",
         "last-modified" => "Tue, 18 Jul 2023 06:27:33 GMT",
         "server" => "AliyunOSS",
         "x-oss-request-id" => "64B630D8E0DCB93335001975"
       }}
  """
  @spec get_object_meta(module(), Typespecs.bucket(), Typespecs.object()) ::
          {:ok, Typespecs.dict()} | {:error, LibOss.Exception.t()}
  def get_object_meta(client, bucket, object) do
    Core.get_object_meta(client, bucket, object)
  end

  @doc """
  创建宏，用于在客户端模块中导入所有对象操作函数
  """
  defmacro __using__(_opts) do
    quote do
      alias LibOss.Api.Object

      # 定义委托函数，自动传入客户端模块名
      def put_object(bucket, object, data, headers \\ []) do
        Object.put_object(__MODULE__, bucket, object, data, headers)
      end

      def get_object(bucket, object, req_headers \\ []) do
        Object.get_object(__MODULE__, bucket, object, req_headers)
      end

      def copy_object(bucket, object, source_bucket, source_object, headers \\ []) do
        Object.copy_object(__MODULE__, bucket, object, source_bucket, source_object, headers)
      end

      def delete_object(bucket, object) do
        Object.delete_object(__MODULE__, bucket, object)
      end

      def delete_multiple_objects(bucket, objects) do
        Object.delete_multiple_objects(__MODULE__, bucket, objects)
      end

      def append_object(bucket, object, since, data, headers \\ []) do
        Object.append_object(__MODULE__, bucket, object, since, data, headers)
      end

      def head_object(bucket, object, headers \\ []) do
        Object.head_object(__MODULE__, bucket, object, headers)
      end

      def get_object_meta(bucket, object) do
        Object.get_object_meta(__MODULE__, bucket, object)
      end
    end
  end
end
