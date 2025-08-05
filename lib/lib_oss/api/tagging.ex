defmodule LibOss.Api.Tagging do
  @moduledoc """
  OSS对象标签管理相关API

  提供对象标签的设置、获取和删除功能。
  """

  alias LibOss.Core.Tagging
  alias LibOss.Typespecs

  @doc """
  调用PutObjectTagging接口设置或更新对象（Object）的标签（Tagging）信息。

  Doc: https://help.aliyun.com/document_detail/114855.html

  ## Examples

      iex> put_object_tagging(bucket, "/test/test.txt", %{"key1" => "value1", "key2" => "value2"})
      :ok
  """
  @spec put_object_tagging(module(), Typespecs.bucket(), Typespecs.object(), Typespecs.tags()) ::
          :ok | {:error, LibOss.Exception.t()}
  def put_object_tagging(client, bucket, object, tags) do
    Tagging.put_object_tagging(client, bucket, object, tags)
  end

  @doc """
  调用GetObjectTagging接口获取对象（Object）的标签（Tagging）信息。

  Doc: https://help.aliyun.com/document_detail/114878.html

  ## Examples

      iex> get_object_tagging(bucket, "/test/test.txt")
      {:ok,
       [
         %{"Key" => "key1", "Value" => "value1"},
         %{"Key" => "key2", "Value" => "value2"}
       ]}
  """
  @spec get_object_tagging(module(), Typespecs.bucket(), Typespecs.object()) ::
          {:ok, Typespecs.dict()} | {:error, LibOss.Exception.t()}
  def get_object_tagging(client, bucket, object) do
    Tagging.get_object_tagging(client, bucket, object)
  end

  @doc """
  删除Object当前版本的标签信息。

  Doc: https://help.aliyun.com/document_detail/114879.html

  ## Examples

      iex> delete_object_tagging(bucket, "/test/test.txt")
      :ok
  """
  @spec delete_object_tagging(module(), Typespecs.bucket(), Typespecs.object()) ::
          :ok | {:error, LibOss.Exception.t()}
  def delete_object_tagging(client, bucket, object) do
    Tagging.delete_object_tagging(client, bucket, object)
  end

  @doc """
  创建宏，用于在客户端模块中导入所有标签管理函数
  """
  defmacro __using__(_opts) do
    quote do
      alias LibOss.Api.Tagging

      # 定义委托函数，自动传入客户端模块名
      def put_object_tagging(bucket, object, tags) do
        Tagging.put_object_tagging(__MODULE__, bucket, object, tags)
      end

      def get_object_tagging(bucket, object) do
        Tagging.get_object_tagging(__MODULE__, bucket, object)
      end

      def delete_object_tagging(bucket, object) do
        Tagging.delete_object_tagging(__MODULE__, bucket, object)
      end
    end
  end
end
