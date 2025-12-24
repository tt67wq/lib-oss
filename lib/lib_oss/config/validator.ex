defmodule LibOss.Config.Validator do
  @moduledoc """
  增强的配置验证器，提供运行时配置验证和环境特定配置支持。

  该模块扩展了基础的NimbleOptions验证，添加了：
  - 运行时配置验证
  - 环境特定配置支持
  - 详细的错误提示
  - 配置值的格式验证
  """

  alias LibOss.Exception

  @type validation_result :: {:ok, keyword()} | {:error, String.t()}
  @type env :: :dev | :test | :prod

  @base_schema [
    access_key_id: [
      type: :string,
      doc: "OSS access key id",
      required: true
    ],
    access_key_secret: [
      type: :string,
      doc: "OSS access key secret",
      required: true
    ],
    endpoint: [
      type: :string,
      doc: "OSS endpoint",
      required: true
    ],
    timeout: [
      type: :pos_integer,
      default: 30_000,
      doc: "Request timeout in milliseconds"
    ],
    pool_size: [
      type: :pos_integer,
      default: 100,
      doc: "HTTP connection pool size"
    ],
    max_retries: [
      type: :non_neg_integer,
      default: 3,
      doc: "Maximum number of request retries"
    ],
    debug: [
      type: :boolean,
      default: false,
      doc: "Enable debug mode"
    ]
  ]

  @doc """
  验证配置参数。

  ## 参数

    * `config` - 配置关键字列表
    * `opts` - 验证选项
      * `:env` - 环境 (:dev, :test, :prod)
      * `:runtime` - 是否进行运行时验证 (默认: true)

  ## 返回值

    * `{:ok, validated_config}` - 验证成功
    * `{:error, error_message}` - 验证失败

  ## 示例

      iex> config = [
      ...>   access_key_id: "test_access_key_id_123",
      ...>   access_key_secret: "test_access_key_secret_12345678901234567890",
      ...>   endpoint: "oss-cn-hangzhou.aliyuncs.com"
      ...> ]
      iex> {:ok, result} = LibOss.Config.Validator.validate(config, runtime: false)
      iex> Keyword.get(result, :access_key_id)
      "test_access_key_id_123"

  """
  @spec validate(keyword(), keyword()) :: validation_result()
  def validate(config, opts \\ []) when is_list(config) do
    env = Keyword.get(opts, :env, get_current_env())
    runtime = Keyword.get(opts, :runtime, true)

    with {:ok, validated_config} <- validate_base_config(config),
         {:ok, env_config} <- apply_env_specific_config(validated_config, env),
         {:ok, final_config} <- maybe_validate_runtime(env_config, runtime) do
      {:ok, final_config}
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  @doc """
  验证配置参数，验证失败时抛出异常。

  ## 参数

    * `config` - 配置关键字列表
    * `opts` - 验证选项（同 `validate/2`）

  ## 返回值

    * `validated_config` - 验证成功的配置

  ## 异常

    * `LibOss.Exception` - 验证失败

  ## 示例

      iex> config = [
      ...>   access_key_id: "test_access_key_id_123",
      ...>   access_key_secret: "test_access_key_secret_12345678901234567890",
      ...>   endpoint: "oss-cn-hangzhou.aliyuncs.com"
      ...> ]
      iex> result = LibOss.Config.Validator.validate!(config, runtime: false)
      iex> Keyword.get(result, :access_key_id)
      "test_access_key_id_123"

  """
  @spec validate!(keyword(), keyword()) :: keyword()
  def validate!(config, opts \\ []) do
    case validate(config, opts) do
      {:ok, validated_config} -> validated_config
      {:error, message} -> raise Exception, message: message
    end
  end

  @doc """
  获取配置模式定义。

  ## 参数

    * `env` - 环境 (:dev, :test, :prod)

  ## 返回值

    * NimbleOptions 模式定义

  """
  @spec get_schema(env()) :: keyword()
  def get_schema(env \\ get_current_env()) do
    base_schema = @base_schema

    case env do
      :dev -> add_dev_options(base_schema)
      :test -> add_test_options(base_schema)
      :prod -> add_prod_options(base_schema)
      _ -> base_schema
    end
  end

  # 私有函数

  defp validate_base_config(config) do
    # 检查必需的基础字段是否存在（不检查空字符串，由运行时验证处理）
    required_fields = [:access_key_id, :access_key_secret, :endpoint]

    missing_fields =
      Enum.filter(required_fields, fn field ->
        is_nil(Keyword.get(config, field))
      end)

    if Enum.empty?(missing_fields) do
      {:ok, config}
    else
      {:error, :base_validation_failed}
    end
  end

  defp apply_env_specific_config(config, env) do
    # 使用环境特定的schema进行验证
    env_schema = get_schema(env)

    try do
      validated = NimbleOptions.validate!(config, env_schema)
      {:ok, validated}
    rescue
      NimbleOptions.ValidationError -> {:error, :env_validation_failed}
    end
  end

  defp maybe_validate_runtime(config, false), do: {:ok, config}

  defp maybe_validate_runtime(config, true) do
    with :ok <- validate_endpoint_format(config[:endpoint]),
         :ok <- validate_access_key_format(config[:access_key_id]),
         :ok <- validate_access_key_secret_format(config[:access_key_secret]) do
      {:ok, config}
    end
  end

  defp validate_endpoint_format(endpoint) when is_binary(endpoint) do
    cond do
      String.length(endpoint) == 0 ->
        {:error, :empty_endpoint}

      not String.contains?(endpoint, ".") ->
        {:error, :invalid_endpoint_format}

      String.starts_with?(endpoint, "http://") or String.starts_with?(endpoint, "https://") ->
        {:error, :endpoint_should_not_include_protocol}

      true ->
        :ok
    end
  end

  defp validate_endpoint_format(_), do: {:error, :invalid_endpoint_type}

  defp validate_access_key_format(access_key_id) when is_binary(access_key_id) do
    cond do
      String.length(access_key_id) == 0 ->
        {:error, :empty_access_key_id}

      String.length(access_key_id) < 10 ->
        {:error, :access_key_id_too_short}

      not Regex.match?(~r/^[A-Za-z0-9_]+$/, access_key_id) ->
        {:error, :invalid_access_key_id_format}

      true ->
        :ok
    end
  end

  defp validate_access_key_format(_), do: {:error, :invalid_access_key_id_type}

  defp validate_access_key_secret_format(access_key_secret) when is_binary(access_key_secret) do
    cond do
      String.length(access_key_secret) == 0 ->
        {:error, :empty_access_key_secret}

      String.length(access_key_secret) < 20 ->
        {:error, :access_key_secret_too_short}

      true ->
        :ok
    end
  end

  defp validate_access_key_secret_format(_), do: {:error, :invalid_access_key_secret_type}

  defp add_dev_options(base_schema) do
    base_schema ++
      [
        log_level: [
          type: {:in, [:debug, :info, :warning, :error]},
          default: :debug,
          doc: "Log level for development"
        ],
        mock_responses: [
          type: :boolean,
          default: false,
          doc: "Enable mock responses for development"
        ]
      ]
  end

  defp add_test_options(base_schema) do
    base_schema ++
      [
        log_level: [
          type: {:in, [:debug, :info, :warning, :error]},
          default: :warning,
          doc: "Log level for testing"
        ],
        mock_responses: [
          type: :boolean,
          default: true,
          doc: "Enable mock responses for testing"
        ],
        test_mode: [
          type: :boolean,
          default: true,
          doc: "Enable test mode features"
        ]
      ]
  end

  defp add_prod_options(base_schema) do
    base_schema ++
      [
        log_level: [
          type: {:in, [:info, :warning, :error]},
          default: :info,
          doc: "Log level for production"
        ],
        ssl_verify: [
          type: :boolean,
          default: true,
          doc: "Enable SSL certificate verification"
        ],
        performance_monitoring: [
          type: :boolean,
          default: true,
          doc: "Enable performance monitoring"
        ]
      ]
  end

  defp get_current_env do
    case System.get_env("MIX_ENV") do
      "dev" -> :dev
      "test" -> :test
      "prod" -> :prod
      _ -> :dev
    end
  end

  defp format_error(:base_validation_failed) do
    "基础配置验证失败。请检查必需的配置项：access_key_id, access_key_secret, endpoint"
  end

  defp format_error(:env_validation_failed) do
    "环境特定配置验证失败。请检查当前环境的配置要求"
  end

  defp format_error(:empty_endpoint) do
    "endpoint 不能为空"
  end

  defp format_error(:invalid_endpoint_format) do
    "endpoint 格式无效。应该是有效的域名格式，如：oss-cn-hangzhou.aliyuncs.com"
  end

  defp format_error(:endpoint_should_not_include_protocol) do
    "endpoint 不应包含协议前缀(http:// 或 https://)。请只提供域名部分"
  end

  defp format_error(:invalid_endpoint_type) do
    "endpoint 必须是字符串类型"
  end

  defp format_error(:empty_access_key_id) do
    "access_key_id 不能为空"
  end

  defp format_error(:access_key_id_too_short) do
    "access_key_id 长度不能少于10个字符"
  end

  defp format_error(:invalid_access_key_id_format) do
    "access_key_id 格式无效。只能包含字母、数字和下划线"
  end

  defp format_error(:invalid_access_key_id_type) do
    "access_key_id 必须是字符串类型"
  end

  defp format_error(:empty_access_key_secret) do
    "access_key_secret 不能为空"
  end

  defp format_error(:access_key_secret_too_short) do
    "access_key_secret 长度不能少于20个字符"
  end

  defp format_error(:invalid_access_key_secret_type) do
    "access_key_secret 必须是字符串类型"
  end

  # defp format_error(error) when is_binary(error) do
  #   error
  # end

  # defp format_error(error) do
  #   "配置验证失败: #{inspect(error)}"
  # end
end
