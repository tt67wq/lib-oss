defmodule LibOss.Api.Symlink do
  @moduledoc """
  OSS符号链接管理相关API

  提供符号链接的创建和获取功能。
  """

  alias LibOss.Core.Symlink
  alias LibOss.Typespecs

  @doc """
  调用PutSymlink接口用于为OSS的目标文件（TargetObject）创建软链接（Symlink）

  Doc: https://help.aliyun.com/document_detail/45126.html

  ## Examples

      iex> put_symlink(bucket, "/test/test.txt", "/test/test_symlink.txt")
      :ok
  """
  @spec put_symlink(module(), Typespecs.bucket(), Typespecs.object(), String.t(), Typespecs.headers()) ::
          :ok | {:error, LibOss.Exception.t()}
  def put_symlink(client, bucket, object, target_object, headers \\ []) do
    Symlink.put_symlink(client, bucket, object, target_object, headers)
  end

  @doc """
  调用GetSymlink接口获取软链接。

  Doc: https://help.aliyun.com/document_detail/45146.html

  ## Examples

      iex> get_symlink(bucket, "/test/test.txt")
      {:ok, "/test/test_symlink.txt"}
  """
  @spec get_symlink(module(), Typespecs.bucket(), Typespecs.object()) ::
          {:ok, binary()} | {:error, LibOss.Exception.t()}
  def get_symlink(client, bucket, object) do
    Symlink.get_symlink(client, bucket, object)
  end

  @doc """
  创建宏，用于在客户端模块中导入所有符号链接管理函数
  """
  defmacro __using__(_opts) do
    quote do
      alias LibOss.Api.Symlink

      # 定义委托函数，自动传入客户端模块名
      def put_symlink(bucket, object, target_object, headers \\ []) do
        Symlink.put_symlink(__MODULE__, bucket, object, target_object, headers)
      end

      def get_symlink(bucket, object) do
        Symlink.get_symlink(__MODULE__, bucket, object)
      end
    end
  end
end
