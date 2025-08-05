defmodule LibOss.Config.ManagerTest do
  use ExUnit.Case, async: false

  alias LibOss.Config.Manager

  setup do
    # 清理环境变量
    System.delete_env("LIBOSS_ACCESS_KEY_ID")
    System.delete_env("LIBOSS_ACCESS_KEY_SECRET")
    System.delete_env("LIBOSS_ENDPOINT")
    System.delete_env("LIBOSS_TIMEOUT")
    System.delete_env("LIBOSS_DEBUG")

    :ok
  end

  describe "start_link/1" do
    test "启动配置管理器成功（新API风格）" do
      # 设置应用配置
      Application.put_env(:test_app, TestModule,
        access_key_id: "test_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      )

      config = [
        otp_app: :test_app,
        module_name: TestModule,
        name: TestConfigManager
      ]

      assert {:ok, pid} = Manager.start_link(config)
      assert is_pid(pid)
      assert Process.alive?(pid)

      # 清理
      GenServer.stop(pid)
      Application.delete_env(:test_app, TestModule)
    end

    test "启动配置管理器成功（向后兼容API）" do
      # 设置应用配置
      Application.put_env(:test_app, TestModule,
        access_key_id: "test_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      )

      assert {:ok, pid} = Manager.start_link(:test_app, TestModule, name: TestConfigManagerCompat)
      assert is_pid(pid)
      assert Process.alive?(pid)

      # 清理
      GenServer.stop(pid)
      Application.delete_env(:test_app, TestModule)
    end

    test "配置验证失败时启动失败" do
      # 设置无效配置
      Application.put_env(:test_app, TestModule,
        access_key_id: "test_id"
        # 缺少必需的 access_key_secret 和 endpoint
      )

      config = [
        otp_app: :test_app,
        module_name: TestModule,
        name: TestConfigManagerFail
      ]

      assert {:error, {:config_error, _reason}} = Manager.start_link(config)

      # 清理
      Application.delete_env(:test_app, TestModule)
    end
  end

  describe "get_config/2" do
    setup do
      Application.put_env(:test_app, TestModule,
        access_key_id: "test_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com",
        timeout: 60_000
      )

      config = [
        otp_app: :test_app,
        module_name: TestModule,
        name: TestConfigManagerGet
      ]

      {:ok, pid} = Manager.start_link(config)

      on_exit(fn ->
        GenServer.stop(pid)
        Application.delete_env(:test_app, TestModule)
      end)

      {:ok, pid: pid}
    end

    test "获取完整配置" do
      config = Manager.get_config(TestModule)

      assert is_map(config)
      assert config[:access_key_id] == "test_access_key_id_123"
      assert config[:access_key_secret] == "test_access_key_secret_12345678901234567890"
      assert config[:endpoint] == "oss-cn-hangzhou.aliyuncs.com"
      assert config[:timeout] == 60_000
    end

    test "获取特定配置项" do
      assert Manager.get_config(TestModule, :access_key_id) == "test_access_key_id_123"
      assert Manager.get_config(TestModule, :endpoint) == "oss-cn-hangzhou.aliyuncs.com"
      assert Manager.get_config(TestModule, :timeout) == 60_000
      assert Manager.get_config(TestModule, :nonexistent) == nil
    end

    test "配置管理器不存在时使用回退配置" do
      # 配置管理器不存在的情况
      config = Manager.get_config(NonexistentModule)
      assert is_nil(config) or config == []
    end
  end

  describe "update_config/2" do
    setup do
      Application.put_env(:test_app, TestModule,
        access_key_id: "test_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      )

      config = [
        otp_app: :test_app,
        module_name: TestModule,
        name: TestConfigManagerUpdate
      ]

      {:ok, pid} = Manager.start_link(config)

      on_exit(fn ->
        GenServer.stop(pid)
        Application.delete_env(:test_app, TestModule)
      end)

      {:ok, pid: pid}
    end

    test "更新配置成功" do
      # 更新配置
      assert :ok = Manager.update_config(TestModule, timeout: 90_000, debug: true)

      # 验证配置已更新
      config = Manager.get_config(TestModule)
      assert config[:timeout] == 90_000
      assert config[:debug] == true

      # 原有配置仍然存在
      assert config[:access_key_id] == "test_access_key_id_123"
    end

    test "更新无效配置失败" do
      # 尝试更新为无效配置
      assert {:error, _reason} = Manager.update_config(TestModule, access_key_id: "")

      # 验证原配置未被更改
      config = Manager.get_config(TestModule)
      assert config[:access_key_id] == "test_access_key_id_123"
    end
  end

  describe "reload_config/1" do
    setup do
      Application.put_env(:test_app, TestModule,
        access_key_id: "test_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      )

      config = [
        otp_app: :test_app,
        module_name: TestModule,
        name: TestConfigManagerReload
      ]

      {:ok, pid} = Manager.start_link(config)

      on_exit(fn ->
        GenServer.stop(pid)
        Application.delete_env(:test_app, TestModule)
      end)

      {:ok, pid: pid}
    end

    test "重新加载配置成功" do
      # 修改应用配置
      Application.put_env(:test_app, TestModule,
        access_key_id: "new_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-beijing.aliyuncs.com",
        timeout: 120_000
      )

      # 重新加载配置
      assert :ok = Manager.reload_config(TestModule)

      # 验证配置已更新
      config = Manager.get_config(TestModule)
      assert config[:access_key_id] == "new_access_key_id_123"
      assert config[:endpoint] == "oss-cn-beijing.aliyuncs.com"
      assert config[:timeout] == 120_000
    end
  end

  describe "环境变量配置" do
    setup do
      Application.put_env(:test_app, TestModule,
        access_key_id: "app_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      )

      on_exit(fn ->
        Application.delete_env(:test_app, TestModule)
        System.delete_env("LIBOSS_ACCESS_KEY_ID")
        System.delete_env("LIBOSS_ENDPOINT")
        System.delete_env("LIBOSS_TIMEOUT")
        System.delete_env("LIBOSS_DEBUG")
      end)

      :ok
    end

    test "环境变量覆盖应用配置" do
      # 设置环境变量
      System.put_env("LIBOSS_ACCESS_KEY_ID", "env_access_key_id_123")
      System.put_env("LIBOSS_ENDPOINT", "oss-cn-beijing.aliyuncs.com")
      System.put_env("LIBOSS_TIMEOUT", "45000")
      System.put_env("LIBOSS_DEBUG", "true")

      config = [
        otp_app: :test_app,
        module_name: TestModule,
        name: TestConfigManagerEnv
      ]

      {:ok, pid} = Manager.start_link(config)

      config = Manager.get_config(TestModule)

      # 环境变量应该覆盖应用配置
      assert config[:access_key_id] == "env_access_key_id_123"
      assert config[:endpoint] == "oss-cn-beijing.aliyuncs.com"
      assert config[:timeout] == 45_000
      assert config[:debug] == true

      # 未设置环境变量的项目使用应用配置
      assert config[:access_key_secret] == "test_access_key_secret_12345678901234567890"

      # 清理
      GenServer.stop(pid)
    end

    test "布尔值环境变量解析" do
      System.put_env("LIBOSS_DEBUG", "false")
      System.put_env("LIBOSS_SSL_VERIFY", "1")

      config = [
        otp_app: :test_app,
        module_name: TestModule,
        name: TestConfigManagerBool
      ]

      {:ok, pid} = Manager.start_link(config)

      config = Manager.get_config(TestModule)
      assert config[:debug] == false

      # 清理
      GenServer.stop(pid)
    end

    test "数值型环境变量解析" do
      System.put_env("LIBOSS_TIMEOUT", "75000")
      System.put_env("LIBOSS_POOL_SIZE", "150")
      System.put_env("LIBOSS_MAX_RETRIES", "5")

      config = [
        otp_app: :test_app,
        module_name: TestModule,
        name: TestConfigManagerNum
      ]

      {:ok, pid} = Manager.start_link(config)

      config = Manager.get_config(TestModule)
      assert config[:timeout] == 75_000
      assert config[:pool_size] == 150
      assert config[:max_retries] == 5

      # 清理
      GenServer.stop(pid)
    end
  end

  describe "配置变更通知" do
    setup do
      Application.put_env(:test_app, TestModule,
        access_key_id: "test_access_key_id_123",
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      )

      config = [
        otp_app: :test_app,
        module_name: TestModule,
        name: TestConfigManagerNotify
      ]

      {:ok, pid} = Manager.start_link(config)

      on_exit(fn ->
        GenServer.stop(pid)
        Application.delete_env(:test_app, TestModule)
      end)

      {:ok, pid: pid}
    end

    test "订阅和接收配置变更通知" do
      # 订阅配置变更
      Manager.subscribe(TestModule)

      # 更新配置
      Manager.update_config(TestModule, timeout: 90_000)

      # 验证收到通知
      assert_receive {:config_changed, changes, new_config}, 1000

      assert is_list(changes)
      assert {:timeout, {30_000, 90_000}} in changes
      assert is_map(new_config)
      assert new_config[:timeout] == 90_000
    end

    test "取消订阅后不再接收通知" do
      # 订阅配置变更
      Manager.subscribe(TestModule)

      # 取消订阅
      Manager.unsubscribe(TestModule)

      # 更新配置
      Manager.update_config(TestModule, timeout: 90_000)

      # 验证没有收到通知
      refute_receive {:config_changed, _, _}, 500
    end

    test "订阅者进程退出时自动清理" do
      # 启动一个临时进程订阅配置变更
      parent = self()

      subscriber_pid =
        spawn(fn ->
          Manager.subscribe(TestModule)
          send(parent, :subscribed)

          receive do
            :exit -> :ok
          end
        end)

      # 等待订阅完成
      assert_receive :subscribed, 1000

      # 让订阅者进程退出
      send(subscriber_pid, :exit)
      # 给一点时间让进程退出和清理
      Process.sleep(100)

      # 更新配置
      Manager.update_config(TestModule, timeout: 90_000)

      # 验证主进程没有收到通知（因为订阅者已经退出）
      refute_receive {:config_changed, _, _}, 500
    end
  end

  describe "错误处理" do
    test "无效的配置类型" do
      Application.put_env(:test_app, TestModule,
        # 无效类型
        access_key_id: 123,
        access_key_secret: "test_access_key_secret_12345678901234567890",
        endpoint: "oss-cn-hangzhou.aliyuncs.com"
      )

      config = [
        otp_app: :test_app,
        module_name: TestModule,
        name: TestConfigManagerError
      ]

      assert {:error, {:config_error, _reason}} = Manager.start_link(config)

      # 清理
      Application.delete_env(:test_app, TestModule)
    end

    test "缺少必需配置" do
      Application.put_env(:test_app, TestModule,
        access_key_id: "test_access_key_id_123"
        # 缺少 access_key_secret 和 endpoint
      )

      config = [
        otp_app: :test_app,
        module_name: TestModule,
        name: TestConfigManagerMissing
      ]

      assert {:error, {:config_error, _reason}} = Manager.start_link(config)

      # 清理
      Application.delete_env(:test_app, TestModule)
    end
  end
end
