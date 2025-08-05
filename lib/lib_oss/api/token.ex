defmodule LibOss.Api.Token do
  @moduledoc """
  OSS Web上传令牌生成相关API

  提供Web端直传文件到OSS的签名生成功能。
  """

  alias LibOss.Core.Token
  alias LibOss.Typespecs

  @doc """
  通过Web端直传文件（Object）到OSS的签名生成

  Doc: https://help.aliyun.com/document_detail/31926.html

  ## Examples

      iex> get_token(bucket, "/test/test.txt")
      {:ok, "{\"accessid\":\"LTAI1k8kxWG8JpUF\",\"callback\":\"=\",\"dir\":\"/test/test.txt\",\".........ePNPyWQo=\"}"}
  """
  @spec get_token(module(), Typespecs.bucket(), Typespecs.object(), non_neg_integer(), binary()) ::
          {:ok, binary()} | {:error, LibOss.Exception.t()}
  def get_token(client, bucket, object, expire_sec \\ 3600, callback \\ "") do
    Token.get_token(client, bucket, object, expire_sec, callback)
  end

  @doc """
  创建宏，用于在客户端模块中导入所有令牌生成函数
  """
  defmacro __using__(_opts) do
    quote do
      alias LibOss.Api.Token

      # 定义委托函数，自动传入客户端模块名
      def get_token(bucket, object, expire_sec \\ 3600, callback \\ "") do
        Token.get_token(__MODULE__, bucket, object, expire_sec, callback)
      end
    end
  end
end
