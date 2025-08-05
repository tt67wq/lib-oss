defmodule LibOss.Api.Object do
  @moduledoc """
  OSS对象操作相关API

  提供对象的基本CRUD操作，包括上传、下载、复制、删除、追加写等功能。

  ## 主要功能

  - **文件上传**: 支持普通上传和追加写入
  - **文件下载**: 支持完整下载和范围下载
  - **文件复制**: 在同一地域内的存储桶间复制文件
  - **文件删除**: 支持单个和批量删除
  - **元数据获取**: 获取文件的基本信息和元数据

  ## 使用场景

  - 文档管理系统
  - 图片和视频存储
  - 备份和归档
  - 静态资源托管
  - 数据交换和分发

  ## 注意事项

  - 对象名称不能以正斜线(/)或反斜线(\\)开头
  - 对象名称长度必须在1-1023字节之间
  - 对象名称使用UTF-8编码
  - 单次上传文件大小不能超过5GB，大文件请使用分片上传
  - 删除操作不可逆，请谨慎操作

  ## 示例

      # 基本使用
      defmodule MyApp.FileService do
        def upload_file(bucket, key, content) do
          MyOss.put_object(bucket, key, content)
        end

        def download_file(bucket, key) do
          MyOss.get_object(bucket, key)
        end
      end
  """

  alias LibOss.Typespecs

  @doc """
  调用PutObject接口上传文件（Object）。

  支持上传各种类型的文件，包括文本、图片、视频等。可以通过headers参数设置
  文件的Content-Type、缓存策略、访问权限等属性。

  ## 参数说明

  - `client`: OSS客户端模块
  - `bucket`: 存储桶名称
  - `object`: 对象名称（包含路径）
  - `data`: 文件内容，可以是二进制数据或iodata
  - `headers`: 可选的HTTP头部信息

  ## 常用Headers

  - `{"Content-Type", "image/jpeg"}` - 设置文件MIME类型
  - `{"Cache-Control", "max-age=3600"}` - 设置缓存策略
  - `{"Content-Disposition", "attachment; filename=file.txt"}` - 设置下载文件名
  - `{"x-oss-storage-class", "IA"}` - 设置存储类型（Standard/IA/Archive）
  - `{"x-oss-object-acl", "public-read"}` - 设置访问权限

  ## 返回值

  - `:ok` - 上传成功
  - `{:error, %LibOss.Exception{}}` - 上传失败，包含错误详情

  ## 使用场景

  - 用户头像上传
  - 文档文件存储
  - 静态资源部署
  - 数据备份

  Doc: https://help.aliyun.com/document_detail/31978.html

  ## Examples

      # 基本文本文件上传
      iex> put_object(MyOss, "my-bucket", "docs/readme.txt", "Hello World")
      :ok

      # 上传图片文件
      iex> {:ok, image_data} = File.read("photo.jpg")
      iex> headers = [{"Content-Type", "image/jpeg"}]
      iex> put_object(MyOss, "my-bucket", "images/photo.jpg", image_data, headers)
      :ok

      # 设置文件为私有访问
      iex> headers = [{"x-oss-object-acl", "private"}]
      iex> put_object(MyOss, "my-bucket", "private/secret.txt", "secret data", headers)
      :ok

      # 上传并设置缓存策略
      iex> headers = [
      ...>   {"Content-Type", "text/css"},
      ...>   {"Cache-Control", "max-age=86400"}
      ...> ]
      iex> put_object(MyOss, "my-bucket", "static/style.css", css_content, headers)
      :ok
  """
  @spec put_object(module(), Typespecs.bucket(), Typespecs.object(), iodata(), Typespecs.headers()) ::
          :ok | {:error, LibOss.Exception.t()}
  def put_object(client, bucket, object, data, headers \\ []) do
    LibOss.Core.Object.put_object(client, bucket, object, data, headers)
  end

  @doc """
  GetObject接口用于获取某个文件（Object）。此操作需要对此Object具有读权限。

  支持完整下载和范围下载，可以通过请求头参数控制下载行为，如设置下载范围、
  条件下载等。

  ## 参数说明

  - `client`: OSS客户端模块
  - `bucket`: 存储桶名称
  - `object`: 对象名称（包含路径）
  - `req_headers`: 可选的请求头部信息

  ## 常用请求Headers

  - `{"Range", "bytes=0-1023"}` - 范围下载，下载前1024字节
  - `{"If-Modified-Since", "Wed, 01 Jan 2020 00:00:00 GMT"}` - 条件下载
  - `{"If-None-Match", "etag_value"}` - 如果ETag不匹配则下载
  - `{"x-oss-process", "image/resize,w_100"}` - 图片处理参数

  ## 返回值

  - `{:ok, binary()}` - 下载成功，返回文件内容
  - `{:error, %LibOss.Exception{}}` - 下载失败，包含错误详情

  ## 使用场景

  - 文件内容读取
  - 图片和视频下载
  - 备份文件恢复
  - 缩略图生成

  Doc: https://help.aliyun.com/document_detail/31980.html

  ## Examples

      # 基本文件下载
      iex> get_object(MyOss, "my-bucket", "docs/readme.txt")
      {:ok, "Hello World"}

      # 范围下载（下载前100字节）
      iex> headers = [{"Range", "bytes=0-99"}]
      iex> get_object(MyOss, "my-bucket", "large-file.dat", headers)
      {:ok, <<binary_data::binary-size(100)>>}

      # 条件下载（仅在文件修改后下载）
      iex> headers = [{"If-Modified-Since", "Mon, 01 Jan 2024 00:00:00 GMT"}]
      iex> get_object(MyOss, "my-bucket", "docs/changelog.txt", headers)
      {:ok, "最新的更改日志内容"}

      # 图片处理下载（生成缩略图）
      iex> headers = [{"x-oss-process", "image/resize,w_200,h_200"}]
      iex> get_object(MyOss, "my-bucket", "images/photo.jpg", headers)
      {:ok, <<thumbnail_data::binary>>}

      # 错误处理示例
      iex> case get_object(MyOss, "my-bucket", "nonexistent.txt") do
      ...>   {:ok, content} -> {:ok, content}
      ...>   {:error, %LibOss.Exception{status_code: 404}} -> {:error, :not_found}
      ...>   {:error, error} -> {:error, error}
      ...> end
      {:error, :not_found}
  """
  @spec get_object(module(), Typespecs.bucket(), Typespecs.object(), Typespecs.headers()) ::
          {:ok, binary()} | {:error, LibOss.Exception.t()}
  def get_object(client, bucket, object, req_headers \\ []) do
    LibOss.Core.Object.get_object(client, bucket, object, req_headers)
  end

  @doc """
  调用CopyObject接口拷贝同一地域下相同或不同存储空间（Bucket）之间的文件（Object）。

  复制操作是服务器端操作，不需要下载和重新上传，效率更高。可以在复制的同时
  修改文件的元数据、存储类型、访问权限等属性。

  ## 参数说明

  - `client`: OSS客户端模块
  - `bucket`: 目标存储桶名称
  - `object`: 目标对象名称
  - `source_bucket`: 源存储桶名称
  - `source_object`: 源对象名称
  - `headers`: 可选的HTTP头部信息

  ## 常用Headers

  - `{"x-oss-metadata-directive", "REPLACE"}` - 替换元数据
  - `{"x-oss-storage-class", "IA"}` - 修改存储类型
  - `{"x-oss-object-acl", "public-read"}` - 修改访问权限
  - `{"Content-Type", "application/json"}` - 修改内容类型
  - `{"x-oss-copy-source-if-match", "etag"}` - 条件复制

  ## 返回值

  - `:ok` - 复制成功
  - `{:error, %LibOss.Exception{}}` - 复制失败，包含错误详情

  ## 使用场景

  - 文件备份和迁移
  - 跨存储桶数据同步
  - 文件版本管理
  - 批量数据处理

  ## 限制条件

  - 源文件和目标文件必须在同一地域
  - 需要对源文件有读权限，对目标存储桶有写权限
  - 文件大小不能超过1GB，大文件请使用CopyPart

  Doc: https://help.aliyun.com/document_detail/31979.html

  ## Examples

      # 基本文件复制
      iex> copy_object(MyOss, "backup-bucket", "docs/readme_backup.txt",
      ...>              "main-bucket", "docs/readme.txt")
      :ok

      # 同一存储桶内复制（文件重命名）
      iex> copy_object(MyOss, "my-bucket", "docs/readme_v2.txt",
      ...>              "my-bucket", "docs/readme.txt")
      :ok

      # 复制并修改存储类型
      iex> headers = [{"x-oss-storage-class", "IA"}]
      iex> copy_object(MyOss, "archive-bucket", "data/file.dat",
      ...>              "main-bucket", "data/file.dat", headers)
      :ok

      # 条件复制（仅当ETag匹配时复制）
      iex> headers = [{"x-oss-copy-source-if-match", "\"5d41402abc4b2a76b9719d911017c592\""}]
      iex> copy_object(MyOss, "target-bucket", "file.txt",
      ...>              "source-bucket", "file.txt", headers)
      :ok

      # 复制并替换所有元数据
      iex> headers = [
      ...>   {"x-oss-metadata-directive", "REPLACE"},
      ...>   {"Content-Type", "application/json"},
      ...>   {"x-oss-object-acl", "private"},
      ...>   {"x-oss-meta-author", "new-author"}
      ...> ]
      iex> copy_object(MyOss, "new-bucket", "data.json",
      ...>              "old-bucket", "data.json", headers)
      :ok
  """
  @spec copy_object(
          module(),
          Typespecs.bucket(),
          Typespecs.object(),
          Typespecs.bucket(),
          Typespecs.object(),
          Typespecs.headers()
        ) :: :ok | {:error, LibOss.Exception.t()}
  def copy_object(client, bucket, object, source_bucket, source_object, headers \\ []) do
    LibOss.Core.Object.copy_object(client, bucket, object, source_bucket, source_object, headers)
  end

  @doc """
  调用DeleteObject删除某个文件（Object）。

  删除操作是不可逆的，一旦删除无法恢复。如果文件不存在，删除操作仍然返回成功。
  删除操作需要对存储桶有写权限。

  ## 参数说明

  - `client`: OSS客户端模块
  - `bucket`: 存储桶名称
  - `object`: 要删除的对象名称

  ## 返回值

  - `:ok` - 删除成功（包括文件不存在的情况）
  - `{:error, %LibOss.Exception{}}` - 删除失败，包含错误详情

  ## 使用场景

  - 清理临时文件
  - 删除过期数据
  - 用户删除操作
  - 存储空间管理

  ## 注意事项

  - 删除操作不可逆，请确认后再执行
  - 删除版本控制的文件时，实际是添加删除标记
  - 删除正在进行分片上传的文件需要先中止分片上传

  Doc: https://help.aliyun.com/document_detail/31982.html

  ## Examples

      # 基本文件删除
      iex> delete_object(MyOss, "my-bucket", "docs/old-file.txt")
      :ok

      # 删除不存在的文件（仍然返回成功）
      iex> delete_object(MyOss, "my-bucket", "nonexistent-file.txt")
      :ok

      # 错误处理示例
      iex> case delete_object(MyOss, "my-bucket", "protected/system-file.txt") do
      ...>   :ok ->
      ...>     Logger.info("文件删除成功")
      ...>     :ok
      ...>   {:error, %LibOss.Exception{status_code: 403}} ->
      ...>     Logger.error("没有删除权限")
      ...>     {:error, :access_denied}
      ...>   {:error, error} ->
      ...>     Logger.error("删除失败: \#{inspect(error)}")
      ...>     {:error, error}
      ...> end
      :ok

      # 安全删除模式（先检查文件是否存在）
      iex> safe_delete = fn bucket, object ->
      ...>   case head_object(MyOss, bucket, object) do
      ...>     {:ok, _meta} -> delete_object(MyOss, bucket, object)
      ...>     {:error, %LibOss.Exception{status_code: 404}} -> {:error, :not_found}
      ...>     error -> error
      ...>   end
      ...> end
      iex> safe_delete.("my-bucket", "docs/important.txt")
      :ok
  """
  @spec delete_object(module(), Typespecs.bucket(), Typespecs.object()) :: :ok | {:error, LibOss.Exception.t()}
  def delete_object(client, bucket, object) do
    LibOss.Core.Object.delete_object(client, bucket, object)
  end

  @doc """
  DeleteMultipleObjects接口用于删除同一个存储空间（Bucket）中的多个文件（Object）。

  批量删除比单个删除更高效，可以在一次请求中删除最多1000个文件。
  操作是原子性的，要么全部成功，要么全部失败。

  ## 参数说明

  - `client`: OSS客户端模块
  - `bucket`: 存储桶名称
  - `objects`: 要删除的对象名称列表（最多1000个）

  ## 返回值

  - `:ok` - 批量删除成功
  - `{:error, %LibOss.Exception{}}` - 删除失败，包含错误详情

  ## 使用场景

  - 清理临时文件夹
  - 批量删除过期数据
  - 用户批量删除操作
  - 定期清理任务

  ## 性能优势

  - 减少网络请求次数
  - 提高删除效率
  - 减少API调用成本
  - 原子性操作保证

  ## 限制条件

  - 单次最多删除1000个文件
  - 所有文件必须在同一存储桶中
  - 请求体大小不能超过2MB

  Doc: https://help.aliyun.com/document_detail/31983.html

  ## Examples

      # 基本批量删除
      iex> objects = ["docs/file1.txt", "docs/file2.txt", "docs/file3.txt"]
      iex> delete_multiple_objects(MyOss, "my-bucket", objects)
      :ok

      # 删除指定前缀的所有文件
      iex> # 首先列出所有文件
      iex> {:ok, %{objects: objects}} = list_objects_v2(MyOss, "my-bucket", prefix: "temp/")
      iex> object_keys = Enum.map(objects, & &1.key)
      iex> delete_multiple_objects(MyOss, "my-bucket", object_keys)
      :ok

      # 分批删除大量文件
      iex> all_objects = ["file1.txt", "file2.txt", ...] # 假设有2500个文件
      iex> results = all_objects
      ...> |> Enum.chunk_every(1000)  # 每批最多1000个
      ...> |> Enum.map(fn batch ->
      ...>      delete_multiple_objects(MyOss, "my-bucket", batch)
      ...>    end)
      iex> # 检查所有批次是否都成功
      iex> Enum.all?(results, &(&1 == :ok))
      true

      # 错误处理和重试
      iex> delete_with_retry = fn bucket, objects, retries \\ 3 ->
      ...>   case delete_multiple_objects(MyOss, bucket, objects) do
      ...>     :ok -> :ok
      ...>     {:error, _} when retries > 0 ->
      ...>       :timer.sleep(1000)
      ...>       delete_with_retry.(bucket, objects, retries - 1)
      ...>     error -> error
      ...>   end
      ...> end
      iex> delete_with_retry.("my-bucket", ["file1.txt", "file2.txt"])
      :ok

      # 安全删除（记录删除的文件）
      iex> safe_batch_delete = fn bucket, objects ->
      ...>   Logger.info("开始批量删除 \#{length(objects)} 个文件")
      ...>   case delete_multiple_objects(MyOss, bucket, objects) do
      ...>     :ok ->
      ...>       Logger.info("批量删除成功: \#{inspect(objects)}")
      ...>       :ok
      ...>     error ->
      ...>       Logger.error("批量删除失败: \#{inspect(error)}")
      ...>       error
      ...>   end
      ...> end
      iex> safe_batch_delete.("my-bucket", ["old1.txt", "old2.txt"])
      :ok
  """
  @spec delete_multiple_objects(module(), Typespecs.bucket(), [Typespecs.object()]) ::
          :ok | {:error, LibOss.Exception.t()}
  def delete_multiple_objects(client, bucket, objects) do
    LibOss.Core.Object.delete_multiple_objects(client, bucket, objects)
  end

  @doc """
  调用AppendObject接口用于以追加写的方式上传文件（Object）。

  追加写允许您向现有文件的末尾追加内容，适用于日志文件、数据流等场景。
  每次追加操作都需要指定正确的位置参数。

  ## 参数说明

  - `client`: OSS客户端模块
  - `bucket`: 存储桶名称
  - `object`: 对象名称
  - `since`: 追加位置，必须等于文件当前长度
  - `data`: 要追加的数据内容
  - `headers`: 可选的HTTP头部信息

  ## 常用Headers

  - `{"Content-Type", "text/plain"}` - 设置内容类型
  - `{"x-oss-storage-class", "Standard"}` - 设置存储类型
  - `{"Cache-Control", "no-cache"}` - 设置缓存策略

  ## 返回值

  - `:ok` - 追加成功
  - `{:error, %LibOss.Exception{}}` - 追加失败，包含错误详情

  ## 使用场景

  - 日志文件写入
  - 数据流处理
  - 增量数据更新
  - 实时数据采集

  ## 注意事项

  - `since`参数必须等于文件当前长度，否则会失败
  - 追加类型的文件不支持CopyObject操作
  - 首次追加时，文件如果不存在会自动创建
  - 追加文件的存储类型只能是Standard

  Doc: https://help.aliyun.com/document_detail/31981.html

  ## Examples

      # 创建新的追加文件
      iex> append_object(MyOss, "my-bucket", "logs/app.log", 0, "应用启动\n")
      :ok

      # 继续追加内容
      iex> append_object(MyOss, "my-bucket", "logs/app.log", 5, "用户登录\n")
      :ok

      # 设置内容类型的追加
      iex> headers = [{"Content-Type", "text/plain; charset=utf-8"}]
      iex> append_object(MyOss, "my-bucket", "data/stream.txt", 0, "数据开始\n", headers)
      :ok

      # 日志追加示例
      iex> log_entry = "#{DateTime.utc_now()} - INFO - 处理完成\n"
      iex> current_size = get_file_size("my-bucket", "logs/system.log")
      iex> append_object(MyOss, "my-bucket", "logs/system.log", current_size, log_entry)
      :ok

      # 错误处理（位置参数错误）
      iex> case append_object(MyOss, "my-bucket", "logs/app.log", 999, "错误位置") do
      ...>   :ok -> :ok
      ...>   {:error, %LibOss.Exception{code: "PositionNotEqualToLength"}} ->
      ...>     # 获取正确的文件长度后重试
      ...>     {:ok, meta} = head_object(MyOss, "my-bucket", "logs/app.log")
      ...>     size = String.to_integer(meta["content-length"])
      ...>     append_object(MyOss, "my-bucket", "logs/app.log", size, "正确追加")
      ...>   error -> error
      ...> end
      :ok
  """
  @spec append_object(
          module(),
          Typespecs.bucket(),
          Typespecs.object(),
          non_neg_integer(),
          binary(),
          Typespecs.headers()
        ) :: :ok | {:error, LibOss.Exception.t()}
  def append_object(client, bucket, object, since, data, headers \\ []) do
    LibOss.Core.Object.append_object(client, bucket, object, since, data, headers)
  end

  @doc """
  HeadObject接口用于获取某个文件（Object）的元信息。使用此接口不会返回文件内容。

  相比GetObject，HeadObject只返回HTTP头部信息，不传输文件内容，因此更加高效，
  适用于检查文件是否存在、获取文件大小、最后修改时间等场景。

  ## 参数说明

  - `client`: OSS客户端模块
  - `bucket`: 存储桶名称
  - `object`: 对象名称
  - `headers`: 可选的请求头部信息

  ## 常用请求Headers

  - `{"If-Modified-Since", "date"}` - 条件检查，仅在修改后返回
  - `{"If-Unmodified-Since", "date"}` - 条件检查，仅在未修改时返回
  - `{"If-Match", "etag"}` - 条件检查，仅在ETag匹配时返回
  - `{"If-None-Match", "etag"}` - 条件检查，仅在ETag不匹配时返回

  ## 返回的元信息

  - `content-length`: 文件大小（字节）
  - `content-type`: 文件MIME类型
  - `etag`: 文件的ETag值
  - `last-modified`: 最后修改时间
  - `x-oss-storage-class`: 存储类型
  - `x-oss-object-type`: 对象类型（Normal/Multipart/Appendable）
  - 其他自定义元数据

  ## 返回值

  - `{:ok, headers_map}` - 成功，返回包含元信息的Map
  - `{:error, %LibOss.Exception{}}` - 失败，包含错误详情

  ## 使用场景

  - 检查文件是否存在
  - 获取文件大小和类型
  - 实现缓存策略
  - 文件同步检查
  - 批量文件信息获取

  ## 性能优势

  - 不传输文件内容，节省带宽
  - 响应速度快
  - 适合大文件信息查询
  - 支持条件检查

  Doc: https://help.aliyun.com/document_detail/31984.html

  ## Examples

      # 基本用法：获取文件元信息
      iex> head_object(MyOss, "my-bucket", "docs/readme.txt")
      {:ok,
       %{
         "accept-ranges" => "bytes",
         "connection" => "keep-alive",
         "content-length" => "11",
         "content-md5" => "XrY7u+Ae7tCTyyK7j1rNww==",
         "content-type" => "text/plain",
         "date" => "Tue, 18 Jul 2023 06:27:36 GMT",
         "etag" => "\"5EB63BBBE01EEED093CB22BB8F5ACDC3\"",
         "last-modified" => "Tue, 18 Jul 2023 06:27:33 GMT",
         "server" => "AliyunOSS",
         "x-oss-hash-crc64ecma" => "5981764153023615706",
         "x-oss-object-type" => "Normal",
         "x-oss-request-id" => "64B630D8E0DCB93335001974",
         "x-oss-server-time" => "1",
         "x-oss-storage-class" => "Standard"
       }}

      # 检查文件是否存在
      iex> file_exists? = fn bucket, key ->
      ...>   case head_object(MyOss, bucket, key) do
      ...>     {:ok, _} -> true
      ...>     {:error, %LibOss.Exception{status_code: 404}} -> false
      ...>     _ -> false
      ...>   end
      ...> end
      iex> file_exists?.("my-bucket", "docs/readme.txt")
      true

      # 获取文件大小
      iex> get_file_size = fn bucket, key ->
      ...>   case head_object(MyOss, bucket, key) do
      ...>     {:ok, headers} ->
      ...>       String.to_integer(headers["content-length"])
      ...>     {:error, _} -> 0
      ...>   end
      ...> end
      iex> get_file_size.("my-bucket", "images/photo.jpg")
      1048576

      # 条件检查：仅在文件修改后获取信息
      iex> last_check = "Mon, 01 Jan 2024 00:00:00 GMT"
      iex> headers = [{"If-Modified-Since", last_check}]
      iex> case head_object(MyOss, "my-bucket", "data/file.json", headers) do
      ...>   {:ok, meta} -> {:modified, meta}
      ...>   {:error, %LibOss.Exception{status_code: 304}} -> {:not_modified}
      ...>   error -> error
      ...> end
      {:modified, %{...}}

      # 批量检查文件信息
      iex> files = ["file1.txt", "file2.txt", "file3.txt"]
      iex> file_info = files
      ...> |> Task.async_stream(fn file ->
      ...>      case head_object(MyOss, "my-bucket", file) do
      ...>        {:ok, meta} -> {file, :exists, meta["content-length"]}
      ...>        {:error, %LibOss.Exception{status_code: 404}} -> {file, :not_found, 0}
      ...>        _ -> {file, :error, 0}
      ...>      end
      ...>    end, max_concurrency: 10)
      ...> |> Enum.map(fn {:ok, result} -> result end)
      [
        {"file1.txt", :exists, "1024"},
        {"file2.txt", :not_found, 0},
        {"file3.txt", :exists, "2048"}
      ]
  """
  @spec head_object(module(), Typespecs.bucket(), Typespecs.object(), Typespecs.headers()) ::
          {:ok, Typespecs.dict()} | {:error, LibOss.Exception.t()}
  def head_object(client, bucket, object, headers \\ []) do
    LibOss.Core.Object.head_object(client, bucket, object, headers)
  end

  @doc """
  GetObjectMeta接口用于获取某个文件（Object）的基本元信息，包括该Object的ETag、Size、LastModified信息，并不返回该Object的内容。

  与HeadObject相比，GetObjectMeta返回更精简的元信息，主要包含文件的核心属性，
  响应更快，适用于只需要基本信息的场景。

  ## 参数说明

  - `client`: OSS客户端模块
  - `bucket`: 存储桶名称
  - `object`: 对象名称

  ## 返回的核心信息

  - `content-length`: 文件大小（字节）
  - `etag`: 文件的ETag值（用于完整性校验）
  - `last-modified`: 最后修改时间
  - `date`: 请求处理时间
  - `x-oss-request-id`: 请求ID（用于问题追踪）

  ## 返回值

  - `{:ok, meta_map}` - 成功，返回包含基本元信息的Map
  - `{:error, %LibOss.Exception{}}` - 失败，包含错误详情

  ## 使用场景

  - 快速文件校验
  - 文件同步检查
  - 批量文件信息统计
  - 缓存有效性验证
  - 文件变更监控

  ## 与HeadObject的区别

  | 特性 | GetObjectMeta | HeadObject |
  |------|---------------|------------|
  | 响应速度 | 更快 | 较快 |
  | 返回信息 | 基本信息 | 完整信息 |
  | 自定义元数据 | 不包含 | 包含 |
  | 条件请求 | 不支持 | 支持 |
  | 用途 | 快速检查 | 详细查询 |

  Doc: https://help.aliyun.com/document_detail/31985.html

  ## Examples

      # 基本用法：获取文件基本元信息
      iex> get_object_meta(MyOss, "my-bucket", "docs/readme.txt")
      {:ok,
       %{
         "connection" => "keep-alive",
         "content-length" => "11",
         "date" => "Tue, 18 Jul 2023 06:27:36 GMT",
         "etag" => "\"5EB63BBBE01EEED093CB22BB8F5ACDC3\"",
         "last-modified" => "Tue, 18 Jul 2023 06:27:33 GMT",
         "server" => "AliyunOSS",
         "x-oss-request-id" => "64B630D8E0DCB93335001974"
       }}

      # 文件完整性校验
      iex> verify_file_integrity = fn bucket, key, expected_etag ->
      ...>   case get_object_meta(MyOss, bucket, key) do
      ...>     {:ok, meta} ->
      ...>       actual_etag = meta["etag"]
      ...>       if actual_etag == expected_etag do
      ...>         {:ok, :verified}
      ...>       else
      ...>         {:error, :etag_mismatch}
      ...>       end
      ...>     error -> error
      ...>   end
      ...> end
      iex> verify_file_integrity.("my-bucket", "data.json", "\"abc123\"")
      {:ok, :verified}

      # 批量获取文件大小统计
      iex> files = ["doc1.txt", "doc2.txt", "doc3.txt"]
      iex> total_size = files
      ...> |> Task.async_stream(fn file ->
      ...>      case get_object_meta(MyOss, "my-bucket", file) do
      ...>        {:ok, meta} -> String.to_integer(meta["content-length"])
      ...>        _ -> 0
      ...>      end
      ...>    end, max_concurrency: 10)
      ...> |> Enum.reduce(0, fn {:ok, size}, acc -> acc + size end)
      iex> IO.puts("总大小: \#{total_size} 字节")
      总大小: 3072 字节

      # 文件变更检测
      iex> check_file_changes = fn bucket, key, last_etag ->
      ...>   case get_object_meta(MyOss, bucket, key) do
      ...>     {:ok, meta} ->
      ...>       current_etag = meta["etag"]
      ...>       if current_etag != last_etag do
      ...>         {:changed, current_etag, meta["last-modified"]}
      ...>       else
      ...>         {:unchanged, current_etag}
      ...>       end
      ...>     {:error, %LibOss.Exception{status_code: 404}} ->
      ...>       {:deleted}
      ...>     error -> error
      ...>   end
      ...> end
      iex> check_file_changes.("my-bucket", "config.json", "\"old_etag\"")
      {:changed, "\"new_etag\"", "Wed, 27 Jan 2024 10:30:00 GMT"}

      # 简单的文件监控
      iex> monitor_files = fn bucket, files ->
      ...>   files
      ...>   |> Enum.map(fn file ->
      ...>        case get_object_meta(MyOss, bucket, file) do
      ...>          {:ok, meta} ->
      ...>            %{
      ...>              file: file,
      ...>              size: String.to_integer(meta["content-length"]),
      ...>              modified: meta["last-modified"],
      ...>              etag: meta["etag"]
      ...>            }
      ...>          {:error, %LibOss.Exception{status_code: 404}} ->
      ...>            %{file: file, status: :not_found}
      ...>          _ ->
      ...>            %{file: file, status: :error}
      ...>        end
      ...>      end)
      ...> end
      iex> monitor_files.("my-bucket", ["app.log", "config.json"])
      [
        %{file: "app.log", size: 2048, modified: "...", etag: "..."},
        %{file: "config.json", status: :not_found}
      ]
  """
  @spec get_object_meta(module(), Typespecs.bucket(), Typespecs.object()) ::
          {:ok, Typespecs.dict()} | {:error, LibOss.Exception.t()}
  def get_object_meta(client, bucket, object) do
    LibOss.Core.Object.get_object_meta(client, bucket, object)
  end

  @doc """
  创建宏，用于在客户端模块中导入所有对象操作函数
  """
  defmacro __using__(_opts) do
    quote do
      alias LibOss.Api.Object

      # 定义委托函数，自动传入客户端模块名
      def put_object(bucket, object, data, headers \\ []) do
        Object.put_object(__MODULE__, bucket, object, data, headers)
      end

      def get_object(bucket, object, req_headers \\ []) do
        Object.get_object(__MODULE__, bucket, object, req_headers)
      end

      def copy_object(bucket, object, source_bucket, source_object, headers \\ []) do
        Object.copy_object(__MODULE__, bucket, object, source_bucket, source_object, headers)
      end

      def delete_object(bucket, object) do
        Object.delete_object(__MODULE__, bucket, object)
      end

      def delete_multiple_objects(bucket, objects) do
        Object.delete_multiple_objects(__MODULE__, bucket, objects)
      end

      def append_object(bucket, object, since, data, headers \\ []) do
        Object.append_object(__MODULE__, bucket, object, since, data, headers)
      end

      def head_object(bucket, object, headers \\ []) do
        Object.head_object(__MODULE__, bucket, object, headers)
      end

      def get_object_meta(bucket, object) do
        Object.get_object_meta(__MODULE__, bucket, object)
      end
    end
  end
end
