# LibOss 故障排除指南

本指南帮助您诊断和解决使用 LibOss SDK 时可能遇到的常见问题。

## 目录

- [配置问题](#配置问题)
- [连接问题](#连接问题)
- [认证问题](#认证问题)
- [上传下载问题](#上传下载问题)
- [权限问题](#权限问题)
- [性能问题](#性能问题)
- [错误代码参考](#错误代码参考)
- [调试技巧](#调试技巧)

## 配置问题

### 问题：应用启动时报配置错误

**症状：**
```
** (RuntimeError) OSS配置错误: endpoint不能为空
```

**解决方案：**

1. 检查配置文件是否正确设置：
```elixir
# config/config.exs
config :my_app, MyOss,
  endpoint: "oss-cn-beijing.aliyuncs.com",
  access_key_id: "your_access_key_id",
  access_key_secret: "your_access_key_secret"
```

2. 确认环境变量是否设置：
```bash
export OSS_ACCESS_KEY_ID="your_access_key_id"
export OSS_ACCESS_KEY_SECRET="your_access_key_secret"
```

3. 验证配置格式：
```elixir
# 在 iex 中测试
config = Application.get_env(:my_app, MyOss)
LibOss.Config.Validator.validate(config)
```

### 问题：endpoint格式错误

**症状：**
```
** (ArgumentError) endpoint格式错误，应该类似: oss-cn-beijing.aliyuncs.com
```

**解决方案：**

确保endpoint格式正确，不要包含协议前缀：
```elixir
# 错误
endpoint: "https://oss-cn-beijing.aliyuncs.com"

# 正确
endpoint: "oss-cn-beijing.aliyuncs.com"
```

## 连接问题

### 问题：连接超时

**症状：**
```
{:error, %LibOss.Exception{message: "连接超时", status_code: nil}}
```

**解决方案：**

1. 检查网络连接：
```bash
ping oss-cn-beijing.aliyuncs.com
```

2. 配置更长的超时时间：
```elixir
# config/config.exs
config :finch, MyApp.Finch,
  pools: %{
    default: [
      conn_opts: [
        transport_opts: [timeout: 60_000]  # 60秒超时
      ]
    ]
  }
```

3. 检查防火墙设置，确保443端口可访问

### 问题：DNS解析失败

**症状：**
```
{:error, %LibOss.Exception{message: "域名解析失败"}}
```

**解决方案：**

1. 检查DNS设置：
```bash
nslookup oss-cn-beijing.aliyuncs.com
```

2. 尝试使用不同的endpoint区域
3. 检查网络代理设置

## 认证问题

### 问题：签名错误

**症状：**
```
{:error, %LibOss.Exception{
  status_code: 403,
  code: "SignatureDoesNotMatch",
  message: "签名不匹配"
}}
```

**解决方案：**

1. 验证Access Key ID和Secret是否正确：
```elixir
# 在生产环境中，不要直接打印secret
IO.inspect(Application.get_env(:my_app, MyOss)[:access_key_id])
```

2. 检查系统时间是否准确：
```bash
date
# 如果时间不准确，同步时间
sudo ntpdate -s time.nist.gov
```

3. 确认endpoint与Access Key匹配的区域

### 问题：Access Key失效

**症状：**
```
{:error, %LibOss.Exception{
  status_code: 403,
  code: "InvalidAccessKeyId"
}}
```

**解决方案：**

1. 登录阿里云控制台检查Access Key状态
2. 确认Access Key未被删除或禁用
3. 检查Access Key是否有OSS服务权限

## 上传下载问题

### 问题：上传大文件失败

**症状：**
```
{:error, %LibOss.Exception{message: "请求体过大"}}
```

**解决方案：**

使用分片上传处理大文件：
```elixir
defmodule LargeFileUploader do
  def upload_large_file(bucket, key, file_path) do
    file_size = File.stat!(file_path).size
    
    if file_size > 5 * 1024 * 1024 do  # 5MB
      upload_multipart(bucket, key, file_path)
    else
      MyOss.put_object(bucket, key, File.read!(file_path))
    end
  end
  
  defp upload_multipart(bucket, key, file_path) do
    with {:ok, upload_id} <- MyOss.initiate_multipart_upload(bucket, key),
         {:ok, parts} <- upload_parts(bucket, key, upload_id, file_path),
         :ok <- MyOss.complete_multipart_upload(bucket, key, upload_id, parts) do
      :ok
    else
      error ->
        MyOss.abort_multipart_upload(bucket, key, upload_id)
        error
    end
  end
end
```

### 问题：下载文件损坏

**症状：**
文件下载成功但内容不完整或损坏

**解决方案：**

1. 验证Content-MD5：
```elixir
def download_with_verification(bucket, key) do
  case MyOss.get_object(bucket, key) do
    {:ok, data} ->
      # 获取对象元数据验证
      case MyOss.head_object(bucket, key) do
        {:ok, headers} ->
          expected_md5 = headers["content-md5"]
          actual_md5 = :crypto.hash(:md5, data) |> Base.encode64()
          
          if expected_md5 == actual_md5 do
            {:ok, data}
          else
            {:error, :checksum_mismatch}
          end
        error -> error
      end
    error -> error
  end
end
```

2. 使用Range请求分段下载：
```elixir
def download_by_range(bucket, key, start_pos, end_pos) do
  headers = [{"Range", "bytes=#{start_pos}-#{end_pos}"}]
  MyOss.get_object(bucket, key, headers)
end
```

## 权限问题

### 问题：访问被拒绝

**症状：**
```
{:error, %LibOss.Exception{
  status_code: 403,
  code: "AccessDenied"
}}
```

**解决方案：**

1. 检查Bucket权限：
```elixir
# 获取Bucket ACL
case MyOss.get_bucket_acl(bucket) do
  {:ok, acl} -> IO.inspect(acl)
  error -> IO.inspect(error)
end
```

2. 检查Object权限：
```elixir
# 获取Object ACL
case MyOss.get_object_acl(bucket, key) do
  {:ok, acl} -> IO.inspect(acl)
  error -> IO.inspect(error)
end
```

3. 验证RAM用户权限策略

### 问题：Bucket不存在

**症状：**
```
{:error, %LibOss.Exception{
  status_code: 404,
  code: "NoSuchBucket"
}}
```

**解决方案：**

1. 确认Bucket名称拼写正确
2. 检查Bucket是否在正确的区域
3. 创建Bucket（如果需要）：
```elixir
MyOss.put_bucket("my-new-bucket")
```

## 性能问题

### 问题：上传速度慢

**解决方案：**

1. 使用并发上传：
```elixir
files
|> Task.async_stream(fn {key, data} ->
  MyOss.put_object(bucket, key, data)
end, max_concurrency: 5)
|> Enum.to_list()
```

2. 选择更近的区域endpoint
3. 增加连接池大小：
```elixir
config :finch, MyApp.Finch,
  pools: %{
    default: [size: 50, count: 1]
  }
```

### 问题：内存使用过高

**解决方案：**

1. 使用流式处理大文件：
```elixir
file_path
|> File.stream!([], 1_048_576)  # 1MB chunks
|> Enum.each(fn chunk ->
  # 处理每个chunk
end)
```

2. 及时释放大数据：
```elixir
data = File.read!(large_file)
result = MyOss.put_object(bucket, key, data)
data = nil  # 显式释放引用
result
```

## 错误代码参考

### 常见HTTP状态码

| 状态码 | 含义 | 常见原因 |
|--------|------|----------|
| 400 | Bad Request | 请求参数错误 |
| 403 | Forbidden | 权限不足或签名错误 |
| 404 | Not Found | Bucket或Object不存在 |
| 409 | Conflict | Bucket已存在或操作冲突 |
| 411 | Length Required | 缺少Content-Length头 |
| 412 | Precondition Failed | 条件检查失败 |
| 416 | Range Not Satisfiable | Range请求超出文件大小 |
| 429 | Too Many Requests | 请求频率过高 |
| 500 | Internal Server Error | 服务器内部错误 |
| 503 | Service Unavailable | 服务暂时不可用 |

### OSS特有错误代码

| 错误代码 | 描述 | 解决方案 |
|----------|------|----------|
| AccessDenied | 访问被拒绝 | 检查权限设置 |
| BucketAlreadyExists | Bucket已存在 | 使用不同的Bucket名 |
| BucketNotEmpty | Bucket不为空 | 先删除所有Object |
| EntityTooLarge | 文件过大 | 使用分片上传 |
| InvalidArgument | 参数无效 | 检查参数格式 |
| InvalidBucketName | Bucket名称无效 | 使用有效的Bucket名 |
| InvalidDigest | 摘要无效 | 检查Content-MD5 |
| InvalidObjectName | Object名称无效 | 检查Object名称格式 |
| NoSuchBucket | Bucket不存在 | 创建Bucket或检查名称 |
| NoSuchKey | Object不存在 | 检查Object路径 |
| SignatureDoesNotMatch | 签名不匹配 | 检查Access Key和时间 |

## 调试技巧

### 启用调试日志

在开发环境启用详细日志：
```elixir
# config/dev.exs
config :logger, level: :debug

# 或者在代码中临时启用
Logger.configure(level: :debug)
```

### 使用调试模块

LibOss提供了内置的调试工具：
```elixir
# 在开发环境中会输出详细信息
LibOss.Debug.debug(data, "调试信息")
```

### 网络抓包分析

使用工具分析HTTP请求：
```bash
# 使用curl测试基本连接
curl -I https://oss-cn-beijing.aliyuncs.com

# 使用tcpdump抓包（需要root权限）
sudo tcpdump -i any -s 0 -w oss_traffic.pcap host oss-cn-beijing.aliyuncs.com
```

### 单元测试验证

创建简单测试验证功能：
```elixir
defmodule OssTest do
  use ExUnit.Case
  
  test "basic connectivity" do
    bucket = "test-bucket"
    key = "test-key"
    data = "test data"
    
    assert :ok = MyOss.put_object(bucket, key, data)
    assert {:ok, ^data} = MyOss.get_object(bucket, key)
    assert :ok = MyOss.delete_object(bucket, key)
  end
end
```

### 健康检查端点

实现健康检查以监控OSS连接状态：
```elixir
defmodule HealthCheck do
  def oss_health do
    test_bucket = "health-check-#{:rand.uniform(1000)}"
    
    case MyOss.put_bucket(test_bucket) do
      :ok -> 
        MyOss.delete_bucket(test_bucket)
        :healthy
      error -> 
        {:unhealthy, error}
    end
  end
end
```

## 获取帮助

如果问题仍未解决：

1. **查看日志** - 检查应用和系统日志
2. **搜索文档** - 查阅[阿里云OSS官方文档](https://help.aliyun.com/product/31815.html)
3. **检查状态** - 访问[阿里云服务状态页面](https://status.alibabacloud.com/)
4. **社区支持** - 在GitHub Issues中搜索相关问题
5. **技术支持** - 联系阿里云技术支持

## 预防措施

为避免常见问题：

1. **充分测试** - 在生产环境部署前进行充分测试
2. **监控告警** - 设置监控和告警机制
3. **备份策略** - 制定数据备份和恢复策略
4. **权限最小化** - 使用最小权限原则
5. **定期检查** - 定期检查配置和权限设置
6. **版本管理** - 记录SDK版本和配置变更

遵循这些指导原则可以帮助您避免大多数常见问题，并在问题发生时快速诊断和解决。