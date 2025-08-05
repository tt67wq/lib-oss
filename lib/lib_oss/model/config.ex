defmodule LibOss.Model.Config do
  @moduledoc """
  配置模型，提供配置验证和管理功能。

  该模块是对新配置系统的兼容性封装，保持原有API的同时
  使用增强的配置验证器。

  ## 迁移说明

  此模块保持向后兼容，但建议新代码直接使用：
  - `LibOss.Config.Validator` - 用于配置验证
  - `LibOss.Config.Manager` - 用于配置管理

  ## 示例

      iex> config = [
      ...>   access_key_id: "test_access_key_id_123",
      ...>   access_key_secret: "test_access_key_secret_12345678901234567890",
      ...>   endpoint: "oss-cn-hangzhou.aliyuncs.com"
      ...> ]
      iex> {:ok, result} = LibOss.Model.Config.validate(config)
      iex> Keyword.get(result, :access_key_id)
      "test_access_key_id_123"

  """

  alias LibOss.Config.Validator

  # 为了向后兼容，保持原有的类型定义
  @type t :: keyword()

  @doc """
  验证配置参数。

  ## 参数

    * `config` - 配置关键字列表

  ## 返回值

    * `{:ok, validated_config}` - 验证成功
    * `{:error, error_message}` - 验证失败

  ## 示例

      iex> config = [
      ...>   access_key_id: "test_access_key_id_123",
      ...>   access_key_secret: "test_access_key_secret_12345678901234567890",
      ...>   endpoint: "oss-cn-hangzhou.aliyuncs.com"
      ...> ]
      iex> {:ok, result} = LibOss.Model.Config.validate(config)
      iex> Keyword.get(result, :access_key_id)
      "test_access_key_id_123"

  """
  @spec validate(keyword()) :: {:ok, keyword()} | {:error, String.t()}
  def validate(config) when is_list(config) do
    # 使用新的验证器，但禁用运行时验证以保持兼容性
    Validator.validate(config, runtime: false)
  end

  def validate(config) do
    {:error, "配置必须是关键字列表，得到: #{inspect(config)}"}
  end

  @doc """
  验证配置参数，验证失败时抛出异常。

  ## 参数

    * `config` - 配置关键字列表

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
      iex> result = LibOss.Model.Config.validate!(config)
      iex> Keyword.get(result, :access_key_id)
      "test_access_key_id_123"

  """
  @spec validate!(keyword()) :: keyword()
  def validate!(config) do
    case validate(config) do
      {:ok, validated_config} -> validated_config
      {:error, message} -> raise LibOss.Exception, message: message
    end
  end

  @doc """
  获取配置模式定义（兼容性函数）。

  ## 返回值

    * NimbleOptions 模式定义

  """
  @spec get_schema() :: keyword()
  def get_schema do
    Validator.get_schema()
  end

  @doc """
  验证配置参数（增强版本）。

  ## 参数

    * `config` - 配置关键字列表
    * `opts` - 验证选项

  ## 返回值

    * `{:ok, validated_config}` - 验证成功
    * `{:error, error_message}` - 验证失败

  """
  @spec validate_enhanced(keyword(), keyword()) :: {:ok, keyword()} | {:error, String.t()}
  def validate_enhanced(config, opts \\ []) do
    Validator.validate(config, opts)
  end

  @doc """
  验证配置参数（增强版本），验证失败时抛出异常。

  ## 参数

    * `config` - 配置关键字列表
    * `opts` - 验证选项

  ## 返回值

    * `validated_config` - 验证成功的配置

  ## 异常

    * `LibOss.Exception` - 验证失败

  """
  @spec validate_enhanced!(keyword(), keyword()) :: keyword()
  def validate_enhanced!(config, opts \\ []) do
    Validator.validate!(config, opts)
  end
end
