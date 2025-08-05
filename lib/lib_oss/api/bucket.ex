defmodule LibOss.Api.Bucket do
  @moduledoc """
  OSS存储桶操作相关API

  提供存储桶的创建、删除、列举、信息获取等功能。
  """

  alias LibOss.Core.Bucket
  alias LibOss.Typespecs

  @doc """
  调用PutBucket接口创建存储空间（Bucket）。

  Doc: https://help.aliyun.com/document_detail/31959.html

  ## Examples

      iex> put_bucket(your-new-bucket)
      :ok
  """
  @spec put_bucket(module(), Typespecs.bucket(), String.t(), String.t(), Typespecs.headers()) ::
          :ok | {:error, LibOss.Exception.t()}
  def put_bucket(client, bucket, storage_class \\ "Standard", data_redundancy_type \\ "LRS", headers \\ []) do
    Bucket.put_bucket(client, bucket, storage_class, data_redundancy_type, headers)
  end

  @doc """
  调用DeleteBucket删除某个存储空间（Bucket）。

  Doc: https://help.aliyun.com/document_detail/31973.html

  ## Examples

      iex> delete_bucket(to-delete-bucket)
      :ok
  """
  @spec delete_bucket(module(), Typespecs.bucket()) :: :ok | {:error, LibOss.Exception.t()}
  def delete_bucket(client, bucket) do
    Bucket.delete_bucket(client, bucket)
  end

  @doc """
  GetBucket (ListObjects)接口用于列举存储空间（Bucket）中所有文件（Object）的信息。

  Doc: https://help.aliyun.com/document_detail/31965.html

  其中query_params具体细节参考上面链接中`请求参数`部分

  ## Examples

      iex> get_bucket(bucket, %{"prefix" => "test/test"})
      {:ok, [
        %{
         "ETag" => "\"A5D2B2E40EF7EBA1C788697D31C27A78-3\"",
         "Key" => "test/test.txt",
         "LastModified" => "2023-07-09T14:41:08.000Z",
         "Owner" => %{
           "DisplayName" => "1074124462684153",
           "ID" => "1074124462684153"
         },
         "Size" => "409608",
         "StorageClass" => "Standard",
         "Type" => "Multipart"
       },
       %{
         "ETag" => "\"5EB63BBBE01EEED093CB22BB8F5ACDC3\"",
         "Key" => "test/test_1.txt",
         "LastModified" => "2023-07-09T14:41:08.000Z",
         "Owner" => %{
           "DisplayName" => "1074124462684153",
           "ID" => "1074124462684153"
         },
         "Size" => "11",
         "StorageClass" => "Standard",
         "Type" => "Normal"
       }
      ]}
  """
  @spec get_bucket(module(), Typespecs.bucket(), Typespecs.params()) ::
          {:ok, list(Typespecs.dict())} | {:error, LibOss.Exception.t()}
  def get_bucket(client, bucket, query_params) do
    Bucket.get_bucket(client, bucket, query_params)
  end

  @doc """
  ListObjectsV2（GetBucketV2）接口用于列举存储空间（Bucket）中所有文件（Object）的信息。

  Doc: https://help.aliyun.com/document_detail/187544.html

  ## Examples

      iex> list_object_v2(bucket, %{"prefix" => "test/test"})
      {:ok,
       [
         %{
           "ETag" => "\"A5D2B2E40EF7EBA1C788697D31C27A78-3\"",
           "Key" => "test/test.txt",
           "LastModified" => "2023-07-09T14:41:08.000Z",
           "Owner" => %{
             "DisplayName" => "1074124462684153",
             "ID" => "1074124462684153"
           },
           "Size" => "409608",
           "StorageClass" => "Standard",
           "Type" => "Multipart"
         },
         %{
           "ETag" => "\"5EB63BBBE01EEED093CB22BB8F5ACDC3\"",
           "Key" => "test/test_1.txt",
           "LastModified" => "2023-07-09T14:41:08.000Z",
           "Owner" => %{
             "DisplayName" => "1074124462684153",
             "ID" => "1074124462684153"
           },
           "Size" => "11",
           "StorageClass" => "Standard",
           "Type" => "Normal"
         }
       ]}
  """
  @spec list_object_v2(module(), Typespecs.bucket(), Typespecs.params()) ::
          {:ok, list(Typespecs.dict())} | {:error, LibOss.Exception.t()}
  def list_object_v2(client, bucket, query_params) do
    Bucket.list_object_v2(client, bucket, query_params)
  end

  @doc """
  调用GetBucketInfo接口获取某个存储空间（Bucket）的相关信息。

  Doc: https://help.aliyun.com/document_detail/31968.html

  ## Examples

      iex> get_bucket_info(bucket)
      {:ok,
       %{
         "BucketInfo" => %{
           "Bucket" => %{
             "AccessControlList" => %{"Grant" => "private"},
             "CreationDate" => "2023-07-07T12:57:30.000Z",
             "ExtranetEndpoint" => "oss-cn-beijing.aliyuncs.com",
             "IntranetEndpoint" => "oss-cn-beijing-internal.aliyuncs.com",
             "Location" => "oss-cn-beijing",
             "Name" => "test-bucket",
             "Owner" => %{"DisplayName" => "1074124462684153", "ID" => "1074124462684153"},
             "StorageClass" => "Standard"
           }
         }
       }}
  """
  @spec get_bucket_info(module(), Typespecs.bucket()) ::
          {:ok, Typespecs.dict()} | {:error, LibOss.Exception.t()}
  def get_bucket_info(client, bucket) do
    Bucket.get_bucket_info(client, bucket)
  end

  @doc """
  调用GetBucketLocation接口获取存储空间（Bucket）的位置信息。

  Doc: https://help.aliyun.com/document_detail/31967.html

  ## Examples

      iex> get_bucket_location(bucket)
      {:ok, "oss-cn-beijing"}
  """
  @spec get_bucket_location(module(), Typespecs.bucket()) ::
          {:ok, binary()} | {:error, LibOss.Exception.t()}
  def get_bucket_location(client, bucket) do
    Bucket.get_bucket_location(client, bucket)
  end

  @doc """
  调用GetBucketStat接口获取指定存储空间（Bucket）的存储容量以及文件（Object）数量。

  Doc: https://help.aliyun.com/document_detail/47572.html

  ## Examples

      iex> get_bucket_stat(bucket)
      {:ok,
       %{
         "BucketStat" => %{
           "LastModifiedTime" => "1689855033",
           "ObjectCount" => "7",
           "Storage" => "1001100",
           "StandardStorage" => "1001100"
         }
       }}
  """
  @spec get_bucket_stat(module(), Typespecs.bucket()) ::
          {:ok, Typespecs.dict()} | {:error, LibOss.Exception.t()}
  def get_bucket_stat(client, bucket) do
    Bucket.get_bucket_stat(client, bucket)
  end

  @doc """
  创建宏，用于在客户端模块中导入所有存储桶操作函数
  """
  defmacro __using__(_opts) do
    quote do
      alias LibOss.Api.Bucket

      # 定义委托函数，自动传入客户端模块名
      def put_bucket(bucket, storage_class \\ "Standard", data_redundancy_type \\ "LRS", headers \\ []) do
        Bucket.put_bucket(__MODULE__, bucket, storage_class, data_redundancy_type, headers)
      end

      def delete_bucket(bucket) do
        Bucket.delete_bucket(__MODULE__, bucket)
      end

      def get_bucket(bucket, query_params) do
        Bucket.get_bucket(__MODULE__, bucket, query_params)
      end

      def list_object_v2(bucket, query_params) do
        Bucket.list_object_v2(__MODULE__, bucket, query_params)
      end

      def get_bucket_info(bucket) do
        Bucket.get_bucket_info(__MODULE__, bucket)
      end

      def get_bucket_location(bucket) do
        Bucket.get_bucket_location(__MODULE__, bucket)
      end

      def get_bucket_stat(bucket) do
        Bucket.get_bucket_stat(__MODULE__, bucket)
      end
    end
  end
end
