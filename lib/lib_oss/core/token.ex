defmodule LibOss.Core.Token do
  @moduledoc """
  Token生成模块

  负责：
  - Web上传令牌：get_token
  - 策略和签名生成
  """

  alias LibOss.Core
  alias LibOss.Exception
  alias LibOss.Typespecs

  @type err_t() :: {:error, Exception.t()}

  @callback_body """
  filename=${object}&size=${size}&mimeType=${mimeType}&height=${imageInfo.height}&width=${imageInfo.width}
  """

  @doc """
  生成Web上传令牌

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 对象名称前缀
  - expire_sec: 过期时间（秒，默认3600秒）
  - callback: 回调URL（可选）

  ## 返回值
  - {:ok, binary()} | {:error, Exception.t()}

  返回JSON格式的上传令牌，包含：
  - accessid: 访问密钥ID
  - host: 上传主机URL
  - policy: Base64编码的策略
  - signature: 签名
  - expire: 过期时间戳
  - dir: 对象前缀
  - callback: Base64编码的回调信息

  ## 示例
      iex> LibOss.Core.Token.get_token(MyOss, "my-bucket", "uploads/", 3600, "https://example.com/callback")
      {:ok, "{\"accessid\":\"...\",\"host\":\"https://my-bucket.oss-cn-hangzhou.aliyuncs.com\",\"policy\":\"...\",\"signature\":\"...\",\"expire\":1640995200,\"dir\":\"uploads/\",\"callback\":\"...\"}"}

  ## 相关文档
  https://help.aliyun.com/document_detail/31926.html
  """
  @spec get_token(module(), Typespecs.bucket(), Typespecs.object(), non_neg_integer(), binary()) ::
          {:ok, binary()} | err_t()
  def get_token(name, bucket, object, expire_sec \\ 3600, callback \\ "") do
    config = Core.get(name)

    expire =
      "Etc/UTC"
      |> DateTime.now!()
      |> DateTime.add(expire_sec, :second)

    with {:ok, policy} <- build_policy(object, expire),
         {:ok, signature} <- sign_policy(policy, config[:access_key_secret]),
         {:ok, callback_data} <- build_callback_data(callback) do
      build_token(config, bucket, policy, signature, expire, object, callback_data)
    end
  end

  @doc """
  生成自定义策略的上传令牌

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - policy_conditions: 策略条件列表
  - expire_sec: 过期时间（秒，默认3600秒）
  - callback: 回调URL（可选）

  ## 策略条件示例
      [
        ["starts-with", "$key", "uploads/"],
        ["content-length-range", 1, 10485760],
        ["eq", "$content-type", "image/jpeg"]
      ]

  ## 返回值
  - {:ok, binary()} | {:error, Exception.t()}

  ## 示例
      iex> conditions = [["starts-with", "$key", "photos/"], ["content-length-range", 1, 5242880]]
      iex> LibOss.Core.Token.get_token_with_policy(MyOss, "my-bucket", conditions, 3600)
      {:ok, "{\"accessid\":\"...\",\"host\":\"...\",\"policy\":\"...\",\"signature\":\"...\",\"expire\":1640995200,\"dir\":\"\",\"callback\":\"\"}"}
  """
  @spec get_token_with_policy(module(), Typespecs.bucket(), list(), non_neg_integer(), binary()) ::
          {:ok, binary()} | err_t()
  def get_token_with_policy(name, bucket, policy_conditions, expire_sec \\ 3600, callback \\ "") do
    config = Core.get(name)

    expire =
      "Etc/UTC"
      |> DateTime.now!()
      |> DateTime.add(expire_sec, :second)

    with {:ok, policy} <- build_custom_policy(policy_conditions, expire),
         {:ok, signature} <- sign_policy(policy, config[:access_key_secret]),
         {:ok, callback_data} <- build_callback_data(callback) do
      build_token(config, bucket, policy, signature, expire, "", callback_data)
    end
  end

  @doc """
  验证上传令牌是否过期

  ## 参数
  - token: 令牌JSON字符串

  ## 返回值
  - boolean()

  ## 示例
      iex> LibOss.Core.Token.token_expired?(token_json)
      false
  """
  @spec token_expired?(binary()) :: boolean()
  def token_expired?(token) when is_binary(token) do
    case Jason.decode(token) do
      {:ok, %{"expire" => expire_timestamp}} when is_integer(expire_timestamp) ->
        current_timestamp = DateTime.to_unix(DateTime.utc_now())
        current_timestamp >= expire_timestamp

      _ ->
        true
    end
  rescue
    _ -> true
  end

  @doc """
  解析上传令牌信息

  ## 参数
  - token: 令牌JSON字符串

  ## 返回值
  - {:ok, map()} | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Token.parse_token(token_json)
      {:ok, %{
        "accessid" => "...",
        "host" => "https://...",
        "expire" => 1640995200,
        "dir" => "uploads/"
      }}
  """
  @spec parse_token(binary()) :: {:ok, map()} | err_t()
  def parse_token(token) when is_binary(token) do
    case Jason.decode(token) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, reason} -> {:error, Exception.new(:invalid_token, "Failed to parse token: #{inspect(reason)}")}
    end
  end

  @doc """
  获取令牌剩余有效时间（秒）

  ## 参数
  - token: 令牌JSON字符串

  ## 返回值
  - {:ok, non_neg_integer()} | {:error, Exception.t()}

  如果令牌已过期，返回0

  ## 示例
      iex> LibOss.Core.Token.token_remaining_time(token_json)
      {:ok, 3540}
  """
  @spec token_remaining_time(binary()) :: {:ok, non_neg_integer()} | err_t()
  def token_remaining_time(token) when is_binary(token) do
    case parse_token(token) do
      {:ok, %{"expire" => expire_timestamp}} when is_integer(expire_timestamp) ->
        current_timestamp = DateTime.to_unix(DateTime.utc_now())
        remaining = max(0, expire_timestamp - current_timestamp)
        {:ok, remaining}

      {:ok, _} ->
        {:error, Exception.new(:invalid_token, "Token does not contain expire field")}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  创建文件大小限制条件

  ## 参数
  - min_size: 最小文件大小（字节）
  - max_size: 最大文件大小（字节）

  ## 返回值
  - list()

  ## 示例
      iex> LibOss.Core.Token.content_length_range(1024, 10485760)
      ["content-length-range", 1024, 10485760]
  """
  @spec content_length_range(non_neg_integer(), non_neg_integer()) :: list()
  def content_length_range(min_size, max_size) when min_size <= max_size do
    ["content-length-range", min_size, max_size]
  end

  @doc """
  创建键前缀条件

  ## 参数
  - prefix: 对象键前缀

  ## 返回值
  - list()

  ## 示例
      iex> LibOss.Core.Token.starts_with_condition("uploads/images/")
      ["starts-with", "$key", "uploads/images/"]
  """
  @spec starts_with_condition(binary()) :: list()
  def starts_with_condition(prefix) when is_binary(prefix) do
    ["starts-with", "$key", prefix]
  end

  @doc """
  创建内容类型条件

  ## 参数
  - content_type: MIME类型

  ## 返回值
  - list()

  ## 示例
      iex> LibOss.Core.Token.content_type_condition("image/jpeg")
      ["eq", "$content-type", "image/jpeg"]
  """
  @spec content_type_condition(binary()) :: list()
  def content_type_condition(content_type) when is_binary(content_type) do
    ["eq", "$content-type", content_type]
  end

  # 私有辅助函数

  defp build_policy(object, expire) do
    policy_map = %{
      "expiration" => DateTime.to_iso8601(expire),
      "conditions" => [["starts-with", "$key", object]]
    }

    case Jason.encode(policy_map) do
      {:ok, json} ->
        encoded_policy = json |> String.trim() |> Base.encode64()
        {:ok, encoded_policy}

      {:error, reason} ->
        {:error, Exception.new(:policy_encode_error, "Failed to encode policy: #{inspect(reason)}")}
    end
  end

  defp build_custom_policy(conditions, expire) do
    policy_map = %{
      "expiration" => DateTime.to_iso8601(expire),
      "conditions" => conditions
    }

    case Jason.encode(policy_map) do
      {:ok, json} ->
        encoded_policy = json |> String.trim() |> Base.encode64()
        {:ok, encoded_policy}

      {:error, reason} ->
        {:error, Exception.new(:policy_encode_error, "Failed to encode custom policy: #{inspect(reason)}")}
    end
  end

  defp sign_policy(policy, access_key_secret) do
    signature = LibOss.Utils.do_sign(policy, access_key_secret)
    {:ok, signature}
  rescue
    e ->
      {:error, Exception.new(:signature_error, "Failed to sign policy: #{Exception.message(e)}")}
  end

  defp build_callback_data(""), do: {:ok, ""}

  defp build_callback_data(callback_url) when is_binary(callback_url) do
    callback_map = %{
      "callbackUrl" => callback_url,
      "callbackBody" => @callback_body,
      "callbackBodyType" => "application/x-www-form-urlencoded"
    }

    case Jason.encode(callback_map) do
      {:ok, json} ->
        encoded_callback = json |> String.trim() |> Base.encode64()
        {:ok, encoded_callback}

      {:error, reason} ->
        {:error, Exception.new(:callback_encode_error, "Failed to encode callback: #{inspect(reason)}")}
    end
  end

  defp build_token(config, bucket, policy, signature, expire, dir, callback) do
    token_map = %{
      "accessid" => config[:access_key_id],
      "host" => "https://#{bucket}.#{config[:endpoint]}",
      "policy" => policy,
      "signature" => signature,
      "expire" => DateTime.to_unix(expire),
      "dir" => dir,
      "callback" => callback
    }

    case Jason.encode(token_map) do
      {:ok, json} -> {:ok, json}
      {:error, reason} -> {:error, Exception.new(:token_encode_error, "Failed to encode token: #{inspect(reason)}")}
    end
  end
end
