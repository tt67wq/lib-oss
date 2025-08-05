# LibOss 最佳实践指南

本指南提供了使用 LibOss SDK 的最佳实践建议，帮助您高效、安全地使用阿里云对象存储服务。

## 目录

- [配置管理](#配置管理)
- [连接池管理](#连接池管理)
- [错误处理](#错误处理)
- [性能优化](#性能优化)
- [安全实践](#安全实践)
- [大文件处理](#大文件处理)
- [并发控制](#并发控制)
- [监控和日志](#监控和日志)

## 配置管理

### 环境隔离

为不同环境使用不同的配置：

```elixir
# config/dev.exs
config :my_app, MyOss,
  endpoint: "oss-cn-beijing.aliyuncs.com",
  access_key_id: System.get_env("OSS_ACCESS_KEY_ID"),
  access_key_secret: System.get_env("OSS_ACCESS_KEY_SECRET")

# config/prod.exs
config :my_app, MyOss,
  endpoint: "oss-cn-shanghai.aliyuncs.com",
  access_key_id: System.get_env("OSS_ACCESS_KEY_ID"),
  access_key_secret: System.get_env("OSS_ACCESS_KEY_SECRET")
```

### 配置验证

在应用启动时验证配置：

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    # 验证OSS配置
    case validate_oss_config() do
      :ok -> 
        children = [MyOss]
        Supervisor.start_link(children, strategy: :one_for_one)
      {:error, reason} ->
        {:error, "OSS配置错误: #{reason}"}
    end
  end

  defp validate_oss_config do
    config = Application.get_env(:my_app, MyOss)
    
    with {:ok, _} <- validate_endpoint(config[:endpoint]),
         {:ok, _} <- validate_credentials(config[:access_key_id], config[:access_key_secret]) do
      :ok
    end
  end
end
```

## 连接池管理

### HTTP客户端配置

配置合适的连接池参数：

```elixir
# config/config.exs
config :finch, MyApp.Finch,
  pools: %{
    default: [
      size: 25,
      count: 1,
      conn_opts: [
        transport_opts: [timeout: 30_000]
      ]
    ]
  }
```

### 连接重用

避免频繁创建新连接：

```elixir
# 好的做法：复用客户端
defmodule FileService do
  @client MyOss

  def upload_file(bucket, key, data) do
    @client.put_object(bucket, key, data)
  end

  def download_file(bucket, key) do
    @client.get_object(bucket, key)
  end
end
```

## 错误处理

### 分类错误处理

根据错误类型采取不同的处理策略：

```elixir
defmodule FileUploader do
  require Logger

  def upload_with_retry(bucket, key, data, retries \\ 3) do
    case MyOss.put_object(bucket, key, data) do
      :ok -> 
        :ok
      
      {:error, %LibOss.Exception{status_code: 429}} ->
        # 限流错误，等待后重试
        if retries > 0 do
          :timer.sleep(1000)
          upload_with_retry(bucket, key, data, retries - 1)
        else
          {:error, :rate_limited}
        end
      
      {:error, %LibOss.Exception{status_code: status}} when status >= 500 ->
        # 服务器错误，重试
        if retries > 0 do
          :timer.sleep(2000)
          upload_with_retry(bucket, key, data, retries - 1)
        else
          {:error, :server_error}
        end
      
      {:error, %LibOss.Exception{status_code: status}} when status >= 400 ->
        # 客户端错误，不重试
        Logger.error("上传失败，客户端错误: #{status}")
        {:error, :client_error}
      
      {:error, reason} ->
        Logger.error("上传失败，网络错误: #{inspect(reason)}")
        {:error, :network_error}
    end
  end
end
```

### 异常监控

实现异常监控和告警：

```elixir
defmodule OssErrorReporter do
  require Logger

  def handle_error(operation, bucket, key, error) do
    error_details = %{
      operation: operation,
      bucket: bucket,
      key: key,
      error: inspect(error),
      timestamp: DateTime.utc_now()
    }
    
    Logger.error("OSS操作失败", error_details)
    
    # 发送到监控系统
    send_to_monitoring(error_details)
  end

  defp send_to_monitoring(details) do
    # 集成您的监控系统
    # Sentry.capture_message("OSS操作失败", extra: details)
  end
end
```

## 性能优化

### 批量操作

使用批量操作提高效率：

```elixir
defmodule BatchUploader do
  def upload_files(bucket, files) when length(files) > 10 do
    # 对于大量文件，使用并发上传
    files
    |> Enum.chunk_every(10)
    |> Task.async_stream(fn chunk ->
      upload_chunk(bucket, chunk)
    end, max_concurrency: 5)
    |> Enum.reduce([], fn {:ok, results}, acc -> acc ++ results end)
  end

  def upload_files(bucket, files) do
    # 少量文件，顺序上传
    Enum.map(files, fn {key, data} ->
      MyOss.put_object(bucket, key, data)
    end)
  end

  defp upload_chunk(bucket, files) do
    Enum.map(files, fn {key, data} ->
      MyOss.put_object(bucket, key, data)
    end)
  end
end
```

### 内存管理

对于大文件，使用流式处理：

```elixir
defmodule StreamUploader do
  def upload_large_file(bucket, key, file_path) do
    file_path
    |> File.stream!([], 1_048_576)  # 1MB chunks
    |> Stream.with_index()
    |> Enum.reduce_while({:ok, []}, fn {chunk, index}, {:ok, parts} ->
      case upload_part(bucket, key, chunk, index) do
        {:ok, part_info} -> {:cont, {:ok, [part_info | parts]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, parts} -> complete_multipart_upload(bucket, key, Enum.reverse(parts))
      error -> error
    end
  end
end
```

## 安全实践

### 访问控制

使用最小权限原则：

```elixir
defmodule SecureFileService do
  # 只允许特定前缀的操作
  @allowed_prefixes ["uploads/", "temp/"]

  def put_object(bucket, key, data) do
    if key_allowed?(key) do
      MyOss.put_object(bucket, key, data)
    else
      {:error, :access_denied}
    end
  end

  defp key_allowed?(key) do
    Enum.any?(@allowed_prefixes, &String.starts_with?(key, &1))
  end
end
```

### 敏感信息保护

避免在日志中暴露敏感信息：

```elixir
defmodule SafeLogger do
  require Logger

  def log_operation(operation, bucket, key, result) do
    safe_key = mask_sensitive_path(key)
    Logger.info("OSS操作: #{operation}, bucket: #{bucket}, key: #{safe_key}, result: #{result}")
  end

  defp mask_sensitive_path(key) do
    # 隐藏敏感路径信息
    key
    |> String.split("/")
    |> Enum.map_join("/", fn segment ->
      if String.contains?(segment, ["user", "id", "token"]) do
        "***"
      else
        segment
      end
    end)
  end
end
```

## 大文件处理

### 分片上传策略

对大文件使用分片上传：

```elixir
defmodule MultipartUploader do
  @chunk_size 5 * 1024 * 1024  # 5MB per part

  def upload_large_file(bucket, key, file_path) do
    file_size = File.stat!(file_path).size
    
    if file_size > @chunk_size do
      upload_multipart(bucket, key, file_path, file_size)
    else
      upload_single(bucket, key, file_path)
    end
  end

  defp upload_multipart(bucket, key, file_path, file_size) do
    with {:ok, upload_id} <- MyOss.initiate_multipart_upload(bucket, key),
         {:ok, parts} <- upload_parts(bucket, key, upload_id, file_path, file_size),
         :ok <- MyOss.complete_multipart_upload(bucket, key, upload_id, parts) do
      :ok
    else
      error ->
        MyOss.abort_multipart_upload(bucket, key, upload_id)
        error
    end
  end

  defp upload_parts(bucket, key, upload_id, file_path, file_size) do
    part_count = div(file_size - 1, @chunk_size) + 1
    
    1..part_count
    |> Task.async_stream(fn part_number ->
      upload_single_part(bucket, key, upload_id, file_path, part_number)
    end, max_concurrency: 3)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, {:ok, part}}, {:ok, acc} -> {:cont, {:ok, [part | acc]}}
      {:ok, {:error, reason}}, _acc -> {:halt, {:error, reason}}
      {:error, reason}, _acc -> {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, parts} -> {:ok, Enum.reverse(parts)}
      error -> error
    end
  end
end
```

## 并发控制

### 限制并发数

避免过多并发请求：

```elixir
defmodule ConcurrencyController do
  def upload_files_with_limit(bucket, files, max_concurrency \\ 5) do
    files
    |> Task.async_stream(fn {key, data} ->
      MyOss.put_object(bucket, key, data)
    end, max_concurrency: max_concurrency, timeout: 30_000)
    |> Enum.to_list()
  end
end
```

### 使用Semaphore控制资源

```elixir
defmodule ResourceController do
  def start_link do
    # 创建信号量，限制同时进行的OSS操作
    :semaphore.start_link([{:local, :oss_semaphore}, 10])
  end

  def with_semaphore(fun) do
    :semaphore.acquire(:oss_semaphore)
    try do
      fun.()
    after
      :semaphore.release(:oss_semaphore)
    end
  end
end
```

## 监控和日志

### 操作指标收集

收集关键操作指标：

```elixir
defmodule OssMetrics do
  def track_operation(operation, bucket, key, fun) do
    start_time = System.monotonic_time(:millisecond)
    
    result = fun.()
    
    duration = System.monotonic_time(:millisecond) - start_time
    
    # 记录指标
    :telemetry.execute(
      [:lib_oss, :operation, :duration],
      %{duration: duration},
      %{operation: operation, bucket: bucket, result: elem(result, 0)}
    )
    
    result
  end
end

# 使用示例
OssMetrics.track_operation("put_object", bucket, key, fn ->
  MyOss.put_object(bucket, key, data)
end)
```

### 健康检查

实现OSS连接健康检查：

```elixir
defmodule OssHealthCheck do
  @test_bucket "health-check-bucket"
  @test_key "health-check/ping"

  def health_check do
    test_data = "ping-#{:erlang.system_time(:second)}"
    
    with :ok <- MyOss.put_object(@test_bucket, @test_key, test_data),
         {:ok, ^test_data} <- MyOss.get_object(@test_bucket, @test_key),
         :ok <- MyOss.delete_object(@test_bucket, @test_key) do
      {:ok, :healthy}
    else
      error -> {:error, error}
    end
  end
end
```

## 总结

遵循这些最佳实践可以帮助您：

1. **提高性能** - 通过连接复用、批量操作、并发控制
2. **增强可靠性** - 通过错误处理、重试机制、健康检查
3. **保证安全** - 通过访问控制、敏感信息保护
4. **便于维护** - 通过监控日志、指标收集

记住始终根据您的具体使用场景调整这些实践，并定期评估和优化您的实现。