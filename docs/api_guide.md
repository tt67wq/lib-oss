# LibOss API 使用指南

本指南详细介绍了 LibOss SDK 的所有API接口，包括使用方法、参数说明、返回值和实际应用示例。

## 目录

- [快速开始](#快速开始)
- [对象操作API](#对象操作api)
- [存储桶操作API](#存储桶操作api)
- [分片上传API](#分片上传api)
- [访问控制API](#访问控制api)
- [标签管理API](#标签管理api)
- [符号链接API](#符号链接api)
- [令牌生成API](#令牌生成api)
- [错误处理](#错误处理)
- [完整示例](#完整示例)

## 快速开始

### 环境要求

- Elixir 1.12+
- Erlang/OTP 24+

### 安装配置

1. 添加依赖到 `mix.exs`:

```elixir
def deps do
  [
    {:lib_oss, "~> 0.2"}
  ]
end
```

2. 创建OSS客户端模块：

```elixir
defmodule MyApp.Oss do
  use LibOss, otp_app: :my_app
end
```

3. 配置访问凭证：

```elixir
# config/config.exs
config :my_app, MyApp.Oss,
  endpoint: "oss-cn-beijing.aliyuncs.com",
  access_key_id: System.get_env("OSS_ACCESS_KEY_ID"),
  access_key_secret: System.get_env("OSS_ACCESS_KEY_SECRET")
```

4. 在应用中启动：

```elixir
# lib/my_app/application.ex
def start(_type, _args) do
  children = [
    MyApp.Oss
  ]
  
  Supervisor.start_link(children, strategy: :one_for_one)
end
```

## 对象操作API

对象操作是OSS的核心功能，包括文件的上传、下载、复制、删除等操作。

### put_object/4,5 - 上传文件

上传文件到OSS存储桶。

**语法：**
```elixir
put_object(bucket, object, data, headers \\ [])
```

**参数：**
- `bucket` - 存储桶名称
- `object` - 对象键名（包含路径）
- `data` - 文件内容（二进制或iodata）
- `headers` - 可选的HTTP头部（列表）

**返回值：**
- `:ok` - 上传成功
- `{:error, exception}` - 上传失败

**示例：**

```elixir
# 上传文本文件
MyApp.Oss.put_object("my-bucket", "docs/readme.txt", "Hello World")

# 上传二进制文件
{:ok, image_data} = File.read("photo.jpg")
headers = [{"Content-Type", "image/jpeg"}]
MyApp.Oss.put_object("my-bucket", "images/photo.jpg", image_data, headers)

# 设置自定义元数据
headers = [
  {"Content-Type", "application/json"},
  {"x-oss-meta-author", "张三"},
  {"x-oss-meta-version", "1.0"}
]
MyApp.Oss.put_object("my-bucket", "data/config.json", json_data, headers)
```

### get_object/3,4 - 下载文件

从OSS存储桶下载文件。

**语法：**
```elixir
get_object(bucket, object, headers \\ [])
```

**参数：**
- `bucket` - 存储桶名称
- `object` - 对象键名
- `headers` - 可选的请求头部

**返回值：**
- `{:ok, binary()}` - 下载成功，返回文件内容
- `{:error, exception}` - 下载失败

**示例：**

```elixir
# 基本下载
{:ok, content} = MyApp.Oss.get_object("my-bucket", "docs/readme.txt")

# 范围下载（下载前1KB）
headers = [{"Range", "bytes=0-1023"}]
{:ok, partial_content} = MyApp.Oss.get_object("my-bucket", "large-file.dat", headers)

# 条件下载
headers = [{"If-Modified-Since", "Mon, 01 Jan 2024 00:00:00 GMT"}]
case MyApp.Oss.get_object("my-bucket", "data.json", headers) do
  {:ok, content} -> # 文件已修改，返回新内容
  {:error, %{status_code: 304}} -> # 文件未修改
end
```

### copy_object/5,6 - 复制文件

在存储桶之间或同一存储桶内复制文件。

**语法：**
```elixir
copy_object(target_bucket, target_object, source_bucket, source_object, headers \\ [])
```

**示例：**

```elixir
# 基本复制
MyApp.Oss.copy_object("backup-bucket", "docs/readme.txt", 
                      "main-bucket", "docs/readme.txt")

# 复制时修改属性
headers = [{"x-oss-storage-class", "IA"}]
MyApp.Oss.copy_object("archive-bucket", "old-data.json",
                      "main-bucket", "data.json", headers)
```

### delete_object/2 - 删除文件

删除指定的文件。

**语法：**
```elixir
delete_object(bucket, object)
```

**示例：**

```elixir
# 删除单个文件
MyApp.Oss.delete_object("my-bucket", "temp/old-file.txt")

# 安全删除（先检查再删除）
case MyApp.Oss.head_object("my-bucket", "important.txt") do
  {:ok, _} -> 
    MyApp.Oss.delete_object("my-bucket", "important.txt")
  {:error, %{status_code: 404}} -> 
    {:error, :not_found}
end
```

### delete_multiple_objects/2 - 批量删除

一次删除多个文件（最多1000个）。

**语法：**
```elixir
delete_multiple_objects(bucket, objects)
```

**示例：**

```elixir
# 批量删除
objects = ["temp/file1.txt", "temp/file2.txt", "temp/file3.txt"]
MyApp.Oss.delete_multiple_objects("my-bucket", objects)

# 删除整个文件夹
{:ok, %{objects: objects}} = MyApp.Oss.list_objects_v2("my-bucket", prefix: "temp/")
object_keys = Enum.map(objects, & &1.key)
MyApp.Oss.delete_multiple_objects("my-bucket", object_keys)
```

### append_object/5,6 - 追加写入

向文件末尾追加内容。

**语法：**
```elixir
append_object(bucket, object, position, data, headers \\ [])
```

**示例：**

```elixir
# 创建追加文件
MyApp.Oss.append_object("my-bucket", "logs/app.log", 0, "应用启动\n")

# 继续追加
MyApp.Oss.append_object("my-bucket", "logs/app.log", 5, "用户登录\n")

# 日志追加辅助函数
defmodule LogAppender do
  def append_log(bucket, key, message) do
    timestamp = DateTime.utc_now() |> DateTime.to_string()
    log_entry = "#{timestamp} - #{message}\n"
    
    case get_current_size(bucket, key) do
      {:ok, size} -> 
        MyApp.Oss.append_object(bucket, key, size, log_entry)
      {:error, :not_found} -> 
        MyApp.Oss.append_object(bucket, key, 0, log_entry)
    end
  end
  
  defp get_current_size(bucket, key) do
    case MyApp.Oss.head_object(bucket, key) do
      {:ok, headers} -> 
        size = String.to_integer(headers["content-length"])
        {:ok, size}
      {:error, %{status_code: 404}} -> 
        {:error, :not_found}
      error -> error
    end
  end
end
```

### head_object/3,4 - 获取文件元信息

获取文件的完整元信息，不返回文件内容。

**语法：**
```elixir
head_object(bucket, object, headers \\ [])
```

**示例：**

```elixir
# 获取文件信息
{:ok, meta} = MyApp.Oss.head_object("my-bucket", "docs/readme.txt")
IO.inspect(meta["content-length"]) # 文件大小
IO.inspect(meta["last-modified"])  # 最后修改时间

# 检查文件是否存在
def file_exists?(bucket, key) do
  case MyApp.Oss.head_object(bucket, key) do
    {:ok, _} -> true
    {:error, %{status_code: 404}} -> false
    _ -> false
  end
end
```

### get_object_meta/2 - 获取基本元信息

获取文件的基本元信息（更轻量）。

**语法：**
```elixir
get_object_meta(bucket, object)
```

**示例：**

```elixir
# 快速获取基本信息
{:ok, meta} = MyApp.Oss.get_object_meta("my-bucket", "data.json")
size = String.to_integer(meta["content-length"])
etag = meta["etag"]
```

## 存储桶操作API

存储桶是OSS的命名空间，用于存储对象。

### put_bucket/1 - 创建存储桶

创建新的存储桶。

**语法：**
```elixir
put_bucket(bucket)
```

**示例：**

```elixir
# 创建存储桶
MyApp.Oss.put_bucket("my-new-bucket")

# 批量创建
buckets = ["bucket1", "bucket2", "bucket3"]
results = Enum.map(buckets, &MyApp.Oss.put_bucket/1)
```

### delete_bucket/1 - 删除存储桶

删除空的存储桶。

**语法：**
```elixir
delete_bucket(bucket)
```

**示例：**

```elixir
# 删除存储桶（必须为空）
MyApp.Oss.delete_bucket("old-bucket")

# 强制删除（先清空再删除）
defmodule BucketManager do
  def force_delete_bucket(bucket) do
    with :ok <- clear_bucket(bucket),
         :ok <- MyApp.Oss.delete_bucket(bucket) do
      :ok
    end
  end
  
  defp clear_bucket(bucket) do
    case MyApp.Oss.list_objects_v2(bucket) do
      {:ok, %{objects: []}} -> :ok
      {:ok, %{objects: objects}} ->
        object_keys = Enum.map(objects, & &1.key)
        MyApp.Oss.delete_multiple_objects(bucket, object_keys)
        clear_bucket(bucket) # 递归清理
      error -> error
    end
  end
end
```

### list_objects_v2/2,3 - 列出对象（推荐）

列出存储桶中的对象。

**语法：**
```elixir
list_objects_v2(bucket, options \\ [])
```

**选项：**
- `prefix` - 对象名前缀过滤
- `delimiter` - 分隔符（用于目录结构）
- `max_keys` - 最大返回数量（默认100，最大1000）
- `start_after` - 起始对象名
- `continuation_token` - 分页令牌

**示例：**

```elixir
# 列出所有对象
{:ok, result} = MyApp.Oss.list_objects_v2("my-bucket")
IO.inspect(length(result.objects))

# 按前缀过滤
{:ok, result} = MyApp.Oss.list_objects_v2("my-bucket", prefix: "images/")

# 分页列出
{:ok, result} = MyApp.Oss.list_objects_v2("my-bucket", max_keys: 10)
if result.is_truncated do
  {:ok, next_result} = MyApp.Oss.list_objects_v2("my-bucket", 
    continuation_token: result.next_continuation_token)
end

# 目录结构列出
{:ok, result} = MyApp.Oss.list_objects_v2("my-bucket", 
  prefix: "docs/", delimiter: "/")
IO.inspect(result.common_prefixes) # 子目录
```

## 分片上传API

用于上传大文件（>100MB推荐使用）。

### initiate_multipart_upload/2,3 - 初始化分片上传

**语法：**
```elixir
initiate_multipart_upload(bucket, object, headers \\ [])
```

**示例：**

```elixir
# 初始化分片上传
{:ok, upload_id} = MyApp.Oss.initiate_multipart_upload("my-bucket", "large-file.dat")

# 设置文件属性
headers = [{"Content-Type", "application/octet-stream"}]
{:ok, upload_id} = MyApp.Oss.initiate_multipart_upload("my-bucket", "video.mp4", headers)
```

### upload_part/5,6 - 上传分片

**语法：**
```elixir
upload_part(bucket, object, upload_id, part_number, data, headers \\ [])
```

**示例：**

```elixir
# 上传单个分片
{:ok, etag} = MyApp.Oss.upload_part("my-bucket", "large-file.dat", 
                                   upload_id, 1, chunk_data)

# 完整分片上传示例
defmodule MultipartUploader do
  @chunk_size 5 * 1024 * 1024  # 5MB per part
  
  def upload_large_file(bucket, key, file_path) do
    with {:ok, upload_id} <- MyApp.Oss.initiate_multipart_upload(bucket, key),
         {:ok, parts} <- upload_file_parts(bucket, key, upload_id, file_path),
         :ok <- MyApp.Oss.complete_multipart_upload(bucket, key, upload_id, parts) do
      :ok
    else
      error ->
        MyApp.Oss.abort_multipart_upload(bucket, key, upload_id)
        error
    end
  end
  
  defp upload_file_parts(bucket, key, upload_id, file_path) do
    file_path
    |> File.stream!([], @chunk_size)
    |> Stream.with_index(1)
    |> Task.async_stream(fn {chunk, part_number} ->
         MyApp.Oss.upload_part(bucket, key, upload_id, part_number, chunk)
       end, max_concurrency: 3)
    |> Enum.reduce_while({:ok, []}, fn
         {:ok, {:ok, etag}}, {:ok, acc} -> 
           {:cont, {:ok, [{part_number, etag} | acc]}}
         _, _ -> 
           {:halt, {:error, :upload_failed}}
       end)
    |> case do
         {:ok, parts} -> {:ok, Enum.reverse(parts)}
         error -> error
       end
  end
end
```

### complete_multipart_upload/4 - 完成分片上传

**语法：**
```elixir
complete_multipart_upload(bucket, object, upload_id, parts)
```

**示例：**

```elixir
# 完成分片上传
parts = [{1, "etag1"}, {2, "etag2"}, {3, "etag3"}]
MyApp.Oss.complete_multipart_upload("my-bucket", "large-file.dat", upload_id, parts)
```

### abort_multipart_upload/3 - 中止分片上传

**语法：**
```elixir
abort_multipart_upload(bucket, object, upload_id)
```

**示例：**

```elixir
# 中止上传
MyApp.Oss.abort_multipart_upload("my-bucket", "large-file.dat", upload_id)

# 清理未完成的分片上传
defmodule MultipartCleaner do
  def cleanup_incomplete_uploads(bucket) do
    case MyApp.Oss.list_multipart_uploads(bucket) do
      {:ok, uploads} ->
        uploads
        |> Enum.each(fn upload ->
             MyApp.Oss.abort_multipart_upload(bucket, upload.key, upload.upload_id)
           end)
      error -> error
    end
  end
end
```

## 访问控制API

管理存储桶和对象的访问权限。

### put_object_acl/3,4 - 设置对象ACL

**语法：**
```elixir
put_object_acl(bucket, object, acl, headers \\ [])
```

**ACL类型：**
- `"private"` - 私有（默认）
- `"public-read"` - 公开读
- `"public-read-write"` - 公开读写

**示例：**

```elixir
# 设置文件为公开读
MyApp.Oss.put_object_acl("my-bucket", "public/image.jpg", "public-read")

# 设置为私有
MyApp.Oss.put_object_acl("my-bucket", "private/secret.txt", "private")
```

### get_object_acl/2 - 获取对象ACL

**示例：**

```elixir
{:ok, acl} = MyApp.Oss.get_object_acl("my-bucket", "image.jpg")
IO.inspect(acl.grant) # "public-read"
```

## 标签管理API

为对象添加标签进行分类管理。

### put_object_tagging/3 - 设置对象标签

**语法：**
```elixir
put_object_tagging(bucket, object, tags)
```

**示例：**

```elixir
# 设置标签
tags = %{"category" => "document", "author" => "张三", "version" => "1.0"}
MyApp.Oss.put_object_tagging("my-bucket", "docs/report.pdf", tags)

# 批量标签管理
defmodule TagManager do
  def tag_images_by_date(bucket, date) do
    prefix = "images/#{date}/"
    {:ok, result} = MyApp.Oss.list_objects_v2(bucket, prefix: prefix)
    
    tags = %{"date" => date, "type" => "image", "processed" => "false"}
    
    result.objects
    |> Enum.each(fn obj ->
         MyApp.Oss.put_object_tagging(bucket, obj.key, tags)
       end)
  end
end
```

### get_object_tagging/2 - 获取对象标签

**示例：**

```elixir
{:ok, tags} = MyApp.Oss.get_object_tagging("my-bucket", "docs/report.pdf")
IO.inspect(tags) # %{"category" => "document", "author" => "张三"}
```

### delete_object_tagging/2 - 删除对象标签

**示例：**

```elixir
MyApp.Oss.delete_object_tagging("my-bucket", "docs/report.pdf")
```

## 符号链接API

创建和管理符号链接。

### put_symlink/3,4 - 创建符号链接

**语法：**
```elixir
put_symlink(bucket, symlink, target, headers \\ [])
```

**示例：**

```elixir
# 创建符号链接
MyApp.Oss.put_symlink("my-bucket", "latest/app.zip", "releases/v1.2.3/app.zip")

# 版本管理示例
defmodule VersionManager do
  def publish_version(bucket, version, file_path) do
    release_key = "releases/#{version}/#{Path.basename(file_path)}"
    latest_key = "latest/#{Path.basename(file_path)}"
    
    with {:ok, content} <- File.read(file_path),
         :ok <- MyApp.Oss.put_object(bucket, release_key, content),
         :ok <- MyApp.Oss.put_symlink(bucket, latest_key, release_key) do
      :ok
    end
  end
end
```

### get_symlink/2 - 获取符号链接目标

**示例：**

```elixir
{:ok, target} = MyApp.Oss.get_symlink("my-bucket", "latest/app.zip")
IO.puts("链接指向: #{target}")
```

## 令牌生成API

生成前端直传和回调的签名令牌。

### get_token/3,4 - 生成上传令牌

**语法：**
```elixir
get_token(bucket, expire_time, conditions, options \\ [])
```

**示例：**

```elixir
# 生成基本上传令牌
expire_time = System.system_time(:second) + 3600  # 1小时后过期
conditions = [
  ["content-length-range", 0, 10485760],  # 文件大小限制0-10MB
  ["starts-with", "$key", "uploads/"]     # 上传路径限制
]

{:ok, token} = MyApp.Oss.get_token("my-bucket", expire_time, conditions)

# 前端使用令牌
%{
  "OSSAccessKeyId" => token.access_key_id,
  "policy" => token.policy,
  "signature" => token.signature,
  "key" => "uploads/${filename}",
  "success_action_status" => "200"
}
```

### get_token_with_callback/4,5 - 生成带回调的令牌

**示例：**

```elixir
# 生成带回调的令牌
callback_url = "https://my-app.com/api/oss-callback"
callback_body = %{
  "filename" => "${object}",
  "size" => "${size}",
  "mimeType" => "${mimeType}"
}

{:ok, token} = MyApp.Oss.get_token_with_callback(
  "my-bucket", expire_time, conditions, callback_url, callback_body
)
```

## 错误处理

LibOss使用结构化的错误处理机制。

### 错误类型

所有API返回的错误都是 `LibOss.Exception` 结构：

```elixir
%LibOss.Exception{
  status_code: 404,
  code: "NoSuchKey",
  message: "The specified key does not exist.",
  request_id: "61D2B3E8BF0D7E4F"
}
```

### 通用错误处理模式

```elixir
defmodule ErrorHandler do
  require Logger
  
  def safe_operation(fun) when is_function(fun, 0) do
    case fun.() do
      :ok -> :ok
      {:ok, result} -> {:ok, result}
      
      {:error, %LibOss.Exception{status_code: 404}} ->
        {:error, :not_found}
      
      {:error, %LibOss.Exception{status_code: 403}} ->
        {:error, :access_denied}
      
      {:error, %LibOss.Exception{status_code: 429}} ->
        # 限流，可以重试
        :timer.sleep(1000)
        safe_operation(fun)
      
      {:error, %LibOss.Exception{status_code: status} = error} when status >= 500 ->
        Logger.error("OSS服务器错误: #{inspect(error)}")
        {:error, :server_error}
      
      {:error, error} ->
        Logger.error("OSS操作失败: #{inspect(error)}")
        {:error, :unknown}
    end
  end
end

# 使用示例
ErrorHandler.safe_operation(fn ->
  MyApp.Oss.get_object("my-bucket", "file.txt")
end)
```

### 重试机制

```elixir
defmodule RetryHelper do
  def with_retry(fun, retries \\ 3) do
    case fun.() do
      {:error, %LibOss.Exception{status_code: status}} when status >= 500 and retries > 0 ->
        :timer.sleep(2000)
        with_retry(fun, retries - 1)
      
      {:error, %LibOss.Exception{status_code: 429}} when retries > 0 ->
        :timer.sleep(1000)
        with_retry(fun, retries - 1)
      
      result -> result
    end
  end
end
```

## 完整示例

### 文件管理服务

```elixir
defmodule FileService do
  alias MyApp.Oss
  require Logger
  
  @bucket "my-app-files"
  @upload_timeout 30_000
  
  def upload_file(key, content, opts \\ []) do
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")
    acl = Keyword.get(opts, :acl, "private")
    
    headers = [
      {"Content-Type", content_type},
      {"x-oss-object-acl", acl}
    ]
    
    case Oss.put_object(@bucket, key, content, headers) do
      :ok -> 
        Logger.info("文件上传成功: #{key}")
        {:ok, key}
      
      error ->
        Logger.error("文件上传失败: #{key}, 错误: #{inspect(error)}")
        error
    end
  end
  
  def download_file(key) do
    case Oss.get_object(@bucket, key) do
      {:ok, content} ->
        Logger.info("文件下载成功: #{key}")
        {:ok, content}
      
      {:error, %LibOss.Exception{status_code: 404}} ->
        Logger.warn("文件不存在: #{key}")
        {:error, :not_found}
      
      error ->
        Logger.error("文件下载失败: #{key}, 错误: #{inspect(error)}")
        error
    end
  end
  
  def delete_file(key) do
    case Oss.delete_object(@bucket, key) do
      :ok ->
        Logger.info("文件删除成功: #{key}")
        :ok
      
      error ->
        Logger.error("文件删除失败: #{key}, 错误: #{inspect(error)}")
        error
    end
  end
  
  def list_files(prefix \\ "") do
    case Oss.list_objects_v2(@bucket, prefix: prefix) do
      {:ok, result} ->
        files = Enum.map(result.objects, fn obj ->
          %{
            key: obj.key,
            size: obj.size,
            modified: obj.last_modified,
            etag: obj.etag
          }
        end)
        {:ok, files}
      
      error ->
        Logger.error("文件列表获取失败, 错误: #{inspect(error)}")
        error
    end
  end
  
  def file_exists?(key) do
    case Oss.head_object(@bucket, key) do
      {:ok, _} -> true
      {:error, %LibOss.Exception{status_code: 404}} -> false
      _ -> false
    end
  end
  
  def get_file_info(key) do
    case Oss.head_object(@bucket, key) do
      {:ok, headers} ->
        info = %{
          size: String.to_integer(headers["content-length"]),
          content_type: headers["content-type"],
          last_modified: headers["last-modified"],
          etag: headers["etag"]
        }
        {:ok, info}
      
      {:error, %LibOss.Exception{status_code: 404}} ->
        {:error, :not_found}
      
      error -> error
    end
  end
end
```

### 图片处理服务

```elixir
defmodule ImageService do
  alias MyApp.Oss
  
  @bucket "my-app-images"
  
  def upload_image(key, image_data, opts \\ []) do
    # 验证图片格式
    case detect_image_type(image_data) do
      {:ok, content_type} ->
        headers = [
          {"Content-Type", content_type},
          {"x-oss-object-acl", "public-read"},
          {"Cache-Control", "max-age=86400"}
        ]
        
        Oss.put_object(@bucket, key, image_data, headers)
      
      {:error, :invalid_format} ->
        {:error, :invalid_image_format}
    end
  end
  
  def get_image_url(key, process \\ nil) do
    base_url = "https://#{@bucket}.oss-cn-beijing.aliyuncs.com/#{key}"
    
    case process do
      nil -> base_url
      params -> "#{base_url}?x-oss-process=#{params}"
    end
  end
  
  def get_thumbnail_url(key, width, height) do
    process = "image/resize,w_#{width},h_#{height},m_fill"
    get_image_url(key, process)
  end
  
  defp detect_image_type(<<0x89, 0x50, 0x4E, 0x47, _::binary>>), do: {:ok, "image/png"}
  defp detect_image_type(<<0xFF, 0xD8, 0xFF, _::binary>>), do: {:ok, "image/jpeg"}
  defp detect_image_type(<<0x47, 0x49, 0x46, _::binary>>), do: {:ok, "image/gif"}
  defp detect_image_type(_), do: {:error, :invalid_format}
end
```

### 备份服务

```elixir
defmodule BackupService do
  alias MyApp.Oss
  
  @source_bucket "main-data"
  @backup_bucket "backup-data"
  
  def backup_files(prefix) do
    with {:ok, result} <- Oss.list_objects_v2(@source_bucket, prefix: prefix),
         :ok <- backup_objects(result.objects) do
      Logger.info("备份完成，共 #{length(result.objects)} 个文件")
      :ok
    end
  end
  
  defp backup_objects(objects) do
    objects
    |> Task.async_stream(fn obj ->
         backup_key = "#{Date.utc_today()}/#{obj.key}"
         Oss.copy_object(@backup_bucket, backup_key, @source_bucket, obj.key)
       end, max_concurrency: 5)
    |> Enum.reduce_while(:ok, fn
         {:ok, :ok}, :ok -> {:cont, :ok}
         {:ok, error}, _ -> {:halt, error}
         error, _ -> {:halt, error}
       end)
  end
  
  def restore_file(backup_date, key) do
    backup_key = "#{backup_date}/#{key}"
    Oss.copy_object(@source_bucket, key, @backup_bucket, backup_key)
  end
end
```

## 性能建议

1. **使用连接池**: 配置适当的HTTP连接池大小
2. **批量操作**: 优先使用批量删除等批量API
3. **并发控制**: 合理控制并发请求数量，避免限流
4. **缓存策略**: 对频繁访问的文件信息进行缓存
5. **分片上传**: 大文件使用分片上传提高成功率
6. **错误重试**: 实现指数退避的重试机制
7. **监控日志**: 记录关键操作的性能指标

通过本指南，您应该能够熟练使用LibOss SDK的所有功能。如有疑问，请参考[最佳实践指南](best_practices.md)和[故障排除指南](troubleshooting.md)。