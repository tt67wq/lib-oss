defmodule LibOss.Api.Acl do
  @moduledoc """
  OSS访问控制列表(ACL)管理相关API

  提供对象和存储桶的ACL权限管理功能。
  """

  alias LibOss.Core.Acl
  alias LibOss.Typespecs

  @doc """
  调用PutObjectACL接口修改文件（Object）的访问权限（ACL）。

  Doc: https://help.aliyun.com/document_detail/31986.html

  ## Examples

      iex> put_object_acl(bucket, "/test/test.txt", "public-read")
      :ok
  """
  @spec put_object_acl(module(), Typespecs.bucket(), Typespecs.object(), String.t()) ::
          :ok | {:error, LibOss.Exception.t()}
  def put_object_acl(client, bucket, object, acl) do
    Acl.put_object_acl(client, bucket, object, acl)
  end

  @doc """
  调用GetObjectACL接口获取存储空间（Bucket）下某个文件（Object）的访问权限（ACL）。

  Doc: https://help.aliyun.com/document_detail/31987.html

  ## Examples

      iex> get_object_acl(bucket, "/test/test.txt")
      {:ok, "public-read"}
  """
  @spec get_object_acl(module(), Typespecs.bucket(), Typespecs.object()) ::
          {:ok, binary()} | {:error, LibOss.Exception.t()}
  def get_object_acl(client, bucket, object) do
    Acl.get_object_acl(client, bucket, object)
  end

  @doc """
  调用PutBucketAcl接口设置或修改存储空间（Bucket）的访问权限（ACL）。

  Doc: https://help.aliyun.com/document_detail/31976.html

  ## Examples

      iex> put_bucket_acl(bucket, "public-read")
      :ok
  """
  @spec put_bucket_acl(module(), Typespecs.bucket(), String.t()) ::
          :ok | {:error, LibOss.Exception.t()}
  def put_bucket_acl(client, bucket, acl) do
    Acl.put_bucket_acl(client, bucket, acl)
  end

  @doc """
  调用GetBucketAcl接口获取某个存储空间（Bucket）的访问权限（ACL）。

  Doc: https://help.aliyun.com/document_detail/31975.html

  ## Examples

      iex> get_bucket_acl(bucket)
      {:ok, "public-read"}
  """
  @spec get_bucket_acl(module(), Typespecs.bucket()) ::
          {:ok, binary()} | {:error, LibOss.Exception.t()}
  def get_bucket_acl(client, bucket) do
    Acl.get_bucket_acl(client, bucket)
  end

  @doc """
  创建宏，用于在客户端模块中导入所有ACL管理函数
  """
  defmacro __using__(_opts) do
    quote do
      alias LibOss.Api.Acl

      # 定义委托函数，自动传入客户端模块名
      def put_object_acl(bucket, object, acl) do
        Acl.put_object_acl(__MODULE__, bucket, object, acl)
      end

      def get_object_acl(bucket, object) do
        Acl.get_object_acl(__MODULE__, bucket, object)
      end

      def put_bucket_acl(bucket, acl) do
        Acl.put_bucket_acl(__MODULE__, bucket, acl)
      end

      def get_bucket_acl(bucket) do
        Acl.get_bucket_acl(__MODULE__, bucket)
      end
    end
  end
end
