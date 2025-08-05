defmodule LibOss.Config.Manager do
  @moduledoc """
  统一的配置管理器，提供配置加载、缓存和运行时更新功能。

  该模块负责：
  - 从多个来源加载配置（应用配置、环境变量、运行时配置）
  - 配置缓存和更新
  - 配置变更通知
  - 环境特定配置处理
  """

  use GenServer

  alias LibOss.Config.Validator

  @type config_source :: :app_config | :env_vars | :runtime
  @type config_key :: atom()
  @type config_value :: any()

  # 配置优先级：runtime > env_vars > app_config
  @config_sources [:app_config, :env_vars, :runtime]

  # 环境变量前缀
  @env_prefix "LIBOSS_"

  # 环境变量映射
  @env_var_mapping %{
    "ACCESS_KEY_ID" => :access_key_id,
    "ACCESS_KEY_SECRET" => :access_key_secret,
    "ENDPOINT" => :endpoint,
    "TIMEOUT" => :timeout,
    "POOL_SIZE" => :pool_size,
    "MAX_RETRIES" => :max_retries,
    "DEBUG" => :debug,
    "LOG_LEVEL" => :log_level,
    "SSL_VERIFY" => :ssl_verify
  }

  defstruct [
    :otp_app,
    :module_name,
    :config_cache,
    :env,
    :subscribers
  ]

  @type t :: %__MODULE__{
          otp_app: atom(),
          module_name: atom(),
          config_cache: map(),
          env: Validator.env(),
          subscribers: [pid()]
        }

  ## 公共API

  @doc """
  启动配置管理器。

  ## 参数

    * `config` - 包含以下键的配置关键字列表：
      * `:otp_app` - OTP应用名称
      * `:module_name` - 模块名称
      * `:name` - GenServer进程名称（可选）
      * 其他初始化选项

  ## 返回值

    * `{:ok, pid}` - 启动成功
    * `{:error, reason}` - 启动失败

  ## 示例

      # 在应用的supervision tree中使用
      defmodule MyApp.Application do
        use Application

        def start(_type, _args) do
          children = [
            {LibOss.Config.Manager, [
              otp_app: :my_app,
              module_name: MyOss,
              name: MyOss.ConfigManager
            ]}
          ]

          Supervisor.start_link(children, strategy: :one_for_one)
        end
      end

      # 或者直接启动
      config = [
        otp_app: :my_app,
        module_name: MyOss,
        name: MyOss.ConfigManager
      ]
      {:ok, pid} = LibOss.Config.Manager.start_link(config)

  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(config) when is_list(config) do
    otp_app = Keyword.fetch!(config, :otp_app)
    module_name = Keyword.fetch!(config, :module_name)
    name = Keyword.get(config, :name, manager_name(module_name))

    GenServer.start_link(__MODULE__, {otp_app, module_name, config}, name: name)
  end

  @doc """
  启动配置管理器的便利函数（保持向后兼容）。

  ## 参数

    * `otp_app` - OTP应用名称
    * `module_name` - 模块名称
    * `opts` - 启动选项

  ## 返回值

    * `{:ok, pid}` - 启动成功
    * `{:error, reason}` - 启动失败

  """
  @spec start_link(atom(), atom(), keyword()) :: GenServer.on_start()
  def start_link(otp_app, module_name, opts \\ []) when is_atom(otp_app) and is_atom(module_name) do
    config = [otp_app: otp_app, module_name: module_name] ++ opts
    start_link(config)
  end

  @doc """
  获取配置。

  ## 参数

    * `module_name` - 模块名称
    * `key` - 配置键（可选）

  ## 返回值

    * 配置值或完整配置

  """
  @spec get_config(atom(), config_key() | nil) :: any()
  def get_config(module_name, key \\ nil) do
    manager_name = manager_name(module_name)

    try do
      GenServer.call(manager_name, {:get_config, key})
    catch
      :exit, {:noproc, _} ->
        # 如果进程不存在，尝试直接从应用配置加载
        load_fallback_config(module_name, key)
    end
  end

  @doc """
  更新配置。

  ## 参数

    * `module_name` - 模块名称
    * `config` - 新配置

  ## 返回值

    * `:ok` - 更新成功
    * `{:error, reason}` - 更新失败

  """
  @spec update_config(atom(), keyword()) :: :ok | {:error, String.t()}
  def update_config(module_name, config) when is_list(config) do
    manager_name = manager_name(module_name)
    GenServer.call(manager_name, {:update_config, config})
  end

  @doc """
  重新加载配置。

  ## 参数

    * `module_name` - 模块名称

  ## 返回值

    * `:ok` - 重新加载成功
    * `{:error, reason}` - 重新加载失败

  """
  @spec reload_config(atom()) :: :ok | {:error, String.t()}
  def reload_config(module_name) do
    manager_name = manager_name(module_name)
    GenServer.call(manager_name, :reload_config)
  end

  @doc """
  订阅配置变更通知。

  ## 参数

    * `module_name` - 模块名称
    * `subscriber` - 订阅者进程

  ## 返回值

    * `:ok` - 订阅成功

  """
  @spec subscribe(atom(), pid()) :: :ok
  def subscribe(module_name, subscriber \\ self()) do
    manager_name = manager_name(module_name)
    GenServer.cast(manager_name, {:subscribe, subscriber})
  end

  @doc """
  取消订阅配置变更通知。

  ## 参数

    * `module_name` - 模块名称
    * `subscriber` - 订阅者进程

  ## 返回值

    * `:ok` - 取消订阅成功

  """
  @spec unsubscribe(atom(), pid()) :: :ok
  def unsubscribe(module_name, subscriber \\ self()) do
    manager_name = manager_name(module_name)
    GenServer.cast(manager_name, {:unsubscribe, subscriber})
  end

  ## GenServer 回调

  @impl true
  def init({otp_app, module_name, _opts}) do
    env = get_current_env()

    state = %__MODULE__{
      otp_app: otp_app,
      module_name: module_name,
      config_cache: %{},
      env: env,
      subscribers: []
    }

    case load_and_validate_config(state) do
      {:ok, config} ->
        new_state = %{state | config_cache: config}
        {:ok, new_state}

      {:error, reason} ->
        {:stop, {:config_error, reason}}
    end
  end

  @impl true
  def handle_call({:get_config, nil}, _from, state) do
    {:reply, state.config_cache, state}
  end

  def handle_call({:get_config, key}, _from, state) do
    value = Map.get(state.config_cache, key)
    {:reply, value, state}
  end

  def handle_call({:update_config, new_config}, _from, state) do
    case validate_and_merge_config(state, new_config) do
      {:ok, updated_config} ->
        old_config = state.config_cache
        new_state = %{state | config_cache: updated_config}

        # 通知订阅者配置变更
        notify_subscribers(state.subscribers, old_config, updated_config)

        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:reload_config, _from, state) do
    case load_and_validate_config(state) do
      {:ok, new_config} ->
        old_config = state.config_cache
        new_state = %{state | config_cache: new_config}

        # 通知订阅者配置变更
        notify_subscribers(state.subscribers, old_config, new_config)

        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_cast({:subscribe, subscriber}, state) do
    # 监控订阅者进程
    Process.monitor(subscriber)
    subscribers = Enum.uniq([subscriber | state.subscribers])
    {:noreply, %{state | subscribers: subscribers}}
  end

  def handle_cast({:unsubscribe, subscriber}, state) do
    subscribers = List.delete(state.subscribers, subscriber)
    {:noreply, %{state | subscribers: subscribers}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # 订阅者进程退出，自动取消订阅
    subscribers = List.delete(state.subscribers, pid)
    {:noreply, %{state | subscribers: subscribers}}
  end

  ## 私有函数

  defp manager_name(module_name) do
    Module.concat(module_name, ConfigManager)
  end

  defp load_and_validate_config(state) do
    with {:ok, raw_config} <- load_config_from_sources(state),
         {:ok, validated_config} <- validate_config(raw_config, state.env) do
      {:ok, Map.new(validated_config)}
    end
  end

  defp load_config_from_sources(state) do
    config =
      Enum.reduce(@config_sources, [], fn source, acc ->
        source_config = load_config_from_source(source, state)
        Keyword.merge(acc, source_config)
      end)

    {:ok, config}
  end

  defp load_config_from_source(:app_config, state) do
    Application.get_env(state.otp_app, state.module_name, [])
  end

  defp load_config_from_source(:env_vars, _state) do
    Enum.reduce(@env_var_mapping, [], fn {env_key, config_key}, acc ->
      full_env_key = @env_prefix <> env_key

      case System.get_env(full_env_key) do
        nil -> acc
        value -> [{config_key, parse_env_value(config_key, value)} | acc]
      end
    end)
  end

  defp load_config_from_source(:runtime, _state) do
    # 运行时配置通过 update_config 设置，这里返回空列表
    []
  end

  defp parse_env_value(key, value) when key in [:timeout, :pool_size, :max_retries] do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> value
    end
  end

  defp parse_env_value(key, value)
       when key in [:debug, :ssl_verify, :mock_responses, :test_mode, :performance_monitoring] do
    case String.downcase(value) do
      val when val in ["true", "1", "yes", "on"] -> true
      val when val in ["false", "0", "no", "off"] -> false
      _ -> value
    end
  end

  defp parse_env_value(:log_level, value) do
    case String.downcase(value) do
      "debug" -> :debug
      "info" -> :info
      "warning" -> :warning
      "error" -> :error
      _ -> value
    end
  end

  defp parse_env_value(_key, value), do: value

  defp validate_config(config, env) do
    Validator.validate(config, env: env, runtime: true)
  end

  defp validate_and_merge_config(state, new_config) do
    current_config = Map.to_list(state.config_cache)
    merged_config = Keyword.merge(current_config, new_config)
    validate_config(merged_config, state.env)
  end

  defp notify_subscribers(subscribers, old_config, new_config) do
    changes = find_config_changes(old_config, new_config)

    unless Enum.empty?(changes) do
      message = {:config_changed, changes, new_config}

      Enum.each(subscribers, fn subscriber ->
        send(subscriber, message)
      end)
    end
  end

  defp find_config_changes(old_config, new_config) do
    old_map = if is_list(old_config), do: Map.new(old_config), else: old_config
    new_map = if is_list(new_config), do: Map.new(new_config), else: new_config

    all_keys = Map.keys(old_map) ++ Map.keys(new_map)

    all_keys
    |> Enum.uniq()
    |> Enum.reduce([], fn key, changes ->
      old_value = Map.get(old_map, key)
      new_value = Map.get(new_map, key)

      if old_value != new_value do
        [{key, {old_value, new_value}} | changes]
      else
        changes
      end
    end)
  end

  defp load_fallback_config(module_name, key) do
    # 从应用配置直接加载作为后备方案
    config =
      Enum.find_value(Application.loaded_applications(), [], fn {app, _, _} ->
        case Application.get_env(app, module_name) do
          nil -> nil
          config -> config
        end
      end)

    case key do
      nil -> config
      _ -> Keyword.get(config, key)
    end
  end

  defp get_current_env do
    case System.get_env("MIX_ENV") do
      "dev" -> :dev
      "test" -> :test
      "prod" -> :prod
      _ -> :dev
    end
  end
end
