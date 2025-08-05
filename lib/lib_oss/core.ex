defmodule LibOss.Core do
  @moduledoc """
  LibOss核心模块（精简版）

  负责：
  - Agent状态管理
  - 通用请求处理
  - 配置管理

  业务逻辑已拆分到各个专门模块中。
  """

  use Agent

  alias LibOss.Core.RequestBuilder
  alias LibOss.Exception
  alias LibOss.Model.Config
  alias LibOss.Model.Http
  alias LibOss.Model.Request

  @type err_t() :: {:error, Exception.t()}

  @doc """
  启动Agent进程

  ## 参数
  - {name, http, config}: 包含进程名称、HTTP客户端和配置的元组

  ## 返回值
  - {:ok, pid()} | {:error, term()}
  """
  @spec start_link({module(), module(), Config.t()}) :: {:ok, pid()} | {:error, term()}
  def start_link({name, http, config}) do
    # 使用增强的配置验证
    validated_config =
      config
      |> Config.validate_enhanced!(runtime: true)
      |> Keyword.put(:http, http)

    Agent.start_link(fn -> validated_config end, name: name)
  end

  @doc """
  获取Agent中存储的配置

  ## 参数
  - name: Agent进程名称

  ## 返回值
  - 配置信息
  """
  @spec get(module()) :: Config.t()
  def get(name) do
    Agent.get(name, & &1)
  end

  @doc """
  执行HTTP请求调用

  ## 参数
  - name: Agent进程名称或配置信息
  - req: OSS请求结构

  ## 返回值
  - {:ok, Http.Response.t()} | {:error, Exception.t()}
  """
  @spec call(module(), Request.t()) :: {:ok, Http.Response.t()} | err_t()
  def call(name, req) when is_atom(name) do
    config = get(name)
    call(config, req)
  end

  @spec call(Config.t(), Request.t()) :: {:ok, Http.Response.t()} | err_t()
  def call(config, req) when is_list(config) do
    http_req = RequestBuilder.build_http_request(config, req)
    LibOss.Http.do_request(config[:http], http_req)
  end

  @doc """
  构建HTTP请求（已弃用，使用RequestBuilder.build_http_request代替）

  ## 参数
  - config: 配置信息
  - req: OSS请求结构

  ## 返回值
  - HTTP请求结构
  """
  @deprecated "Use LibOss.Core.RequestBuilder.build_http_request/2 instead"
  @spec make_request(Config.t(), Request.t()) :: Http.Request.t()
  def make_request(config, req) do
    RequestBuilder.build_http_request(config, req)
  end

  @doc """
  更新Agent中的配置

  ## 参数
  - name: Agent进程名称
  - update_fun: 更新函数

  ## 返回值
  - :ok
  """
  @spec update_config(module(), (Config.t() -> Config.t())) :: :ok
  def update_config(name, update_fun) when is_function(update_fun, 1) do
    Agent.update(name, update_fun)
  end

  @doc """
  获取配置中的特定值

  ## 参数
  - name: Agent进程名称
  - key: 配置键
  - default: 默认值

  ## 返回值
  - 配置值或默认值
  """
  @spec get_config_value(module(), atom(), any()) :: any()
  def get_config_value(name, key, default \\ nil) do
    config = get(name)
    Keyword.get(config, key, default)
  end

  @doc """
  验证配置是否有效

  ## 参数
  - name: Agent进程名称

  ## 返回值
  - :ok | {:error, term()}
  """
  @spec validate_config(module()) :: :ok | {:error, term()}
  def validate_config(name) do
    config = get(name)
    Config.validate_enhanced!(config, runtime: true)
    :ok
  rescue
    e -> {:error, e}
  end

  @doc """
  检查Agent进程是否存在

  ## 参数
  - name: Agent进程名称

  ## 返回值
  - boolean()
  """
  @spec alive?(module()) :: boolean()
  def alive?(name) do
    case Process.whereis(name) do
      nil -> false
      pid -> Process.alive?(pid)
    end
  end

  @doc """
  停止Agent进程

  ## 参数
  - name: Agent进程名称
  - reason: 停止原因（可选）

  ## 返回值
  - :ok
  """
  @spec stop(module(), term()) :: :ok
  def stop(name, reason \\ :normal) do
    Agent.stop(name, reason)
  end
end
