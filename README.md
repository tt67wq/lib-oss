<!-- MDOC !-->
# LibOss

LibOss是Elixir实现的一个[阿里云OSS](https://help.aliyun.com/product/31815.html)的SDK，为Elixir/Phoenix应用提供完整的对象存储解决方案。

## 特性

- 🚀 **完整功能**: 支持OSS核心功能，包括对象操作、存储桶管理、分片上传等
- 🏗️ **模块化架构**: 按功能域组织API，易于使用和维护
- 🔒 **类型安全**: 完整的TypeSpec定义，编译时类型检查
- ⚡ **高性能**: 基于Finch HTTP客户端，支持连接池和并发控制
- 🛡️ **错误处理**: 结构化的错误处理和重试机制
- 📖 **文档完善**: 详细的中文文档和丰富的使用示例
- 🔧 **易于集成**: 遵循OTP设计原则，与Phoenix无缝集成

## 支持的功能

- [ ] Object:
  - [ ] 基础操作:
    - [x] 上传文件
    - [x] 获取文件
    - [x] 删除文件
    - [x] 删除多个文件
    - [x] 获取前端直传签名
    - [x] 文件在bucket间拷贝
    - [x] 追加写文件
    - [x] 获取文件元信息
    - [ ] 通过HTML表单上传的方式将文件
    - [ ] 归档解冻
    - [ ] 执行SQL语句

  - [x] 分片上传:
    - [x] 分片上传发起
    - [x] 分片上传完成
    - [x] 分片上传取消
    - [x] 分片上传列表
    - [x] 列举指定uploadid已经成功上传的part

  - [x] 权限控制ACL
    - [x] 设置文件ACL
    - [x] 获取文件ACL
  - [x] 软连接
    - [x] 创建软连接
    - [x] 获取软连接
  - [x] 标签
    - [x] 设置标签
    - [x] 获取标签
    - [x] 删除标签
 
- [ ] Bucket:
  - [x] 基础操作:
    - [x] 创建bucket
    - [x] 删除bucket
    - [x] 获取bucket中文件
    - [x] 获取bucket中文件V2
    - [x] 查看bucket的相关信息
    - [x] 获取bucket存储容量以及文件（Object）数量
    - [x] 查看bucket的位置信息

  - [ ] 接入点
    - [ ] 创建接入点
    - [ ] 删除接入点
    - [ ] 获取接入点
    - [ ] 列举接入点
    - [ ] 配置接入点策略配置
    - [ ] 获取接入点策略配置
    - [ ] 删除接入点策略配置

  - [x] 权限控制
    - [x] 设置bucket ACL
    - [x] 获取bucket ACL

  - [ ] 生命周期
  - [ ] 传输加速
  - [ ] 版本控制
  - [ ] 数据复制
  - [ ] 授权策略
  - [ ] 清单
  - [ ] 日志管理
  - [ ] 静态网站
  - [ ] 防盗链
  - [ ] 标签
  - [ ] 加密
  - [ ] 请求者付费
  - [ ] 访问跟踪
  - [ ] 数据索引
  - [ ] 高防
  - [ ] 资源组
  - [ ] 自定义域名
  - [ ] 图片样式
  - [ ] 归档直读

- [ ] LiveChannel


## 快速开始

### 安装

添加LibOss到你的`mix.exs`依赖中：

```elixir
def deps do
  [
    {:lib_oss, "~> 0.3"}
  ]
end
```

### 配置

1. 创建OSS客户端模块:

```elixir
defmodule MyApp.Oss do
  use LibOss, otp_app: :my_app
end
```

2. 配置访问凭证:

```elixir
# config/config.exs
config :my_app, MyApp.Oss,
  endpoint: "oss-cn-beijing.aliyuncs.com",
  access_key_id: System.get_env("OSS_ACCESS_KEY_ID"),
  access_key_secret: System.get_env("OSS_ACCESS_KEY_SECRET")
```

3. 在应用的Supervisor中启动:

```elixir
# lib/my_app/application.ex
def start(_type, _args) do
  children = [
    MyApp.Oss
  ]
  
  Supervisor.start_link(children, strategy: :one_for_one)
end
```

### 基本使用

```elixir
# 上传文件
{:ok, content} = File.read("document.pdf")
MyApp.Oss.put_object("my-bucket", "docs/document.pdf", content)

# 下载文件
{:ok, content} = MyApp.Oss.get_object("my-bucket", "docs/document.pdf")

# 删除文件
MyApp.Oss.delete_object("my-bucket", "docs/document.pdf")

# 列出文件
{:ok, result} = MyApp.Oss.list_objects_v2("my-bucket", prefix: "docs/")
```

## 架构设计

LibOss采用模块化架构，按功能域组织代码，提供清晰的API接口：

```
lib/
├── lib_oss.ex                 # 主入口模块
├── lib_oss/
│   ├── api/                   # API层（按功能分离）
│   │   ├── object.ex          # 对象操作
│   │   ├── bucket.ex          # 存储桶管理
│   │   ├── multipart.ex       # 分片上传
│   │   ├── acl.ex             # 访问控制
│   │   ├── tagging.ex         # 标签管理
│   │   ├── symlink.ex         # 符号链接
│   │   └── token.ex           # 令牌生成
│   ├── core.ex               # 核心业务逻辑
│   ├── config/               # 配置管理
│   ├── http/                 # HTTP客户端
│   └── model/                # 数据模型
```

### 设计特点

- **模块化**: 功能按域分离，职责单一
- **类型安全**: 完整的TypeSpec定义
- **可扩展**: 易于添加新功能
- **高性能**: 连接池和并发优化
- **容错性**: 完善的错误处理机制

## 高级功能

### 大文件分片上传

```elixir
defmodule FileUploader do
  def upload_large_file(bucket, key, file_path) do
    with {:ok, upload_id} <- MyApp.Oss.initiate_multipart_upload(bucket, key),
         {:ok, parts} <- upload_parts(bucket, key, upload_id, file_path),
         :ok <- MyApp.Oss.complete_multipart_upload(bucket, key, upload_id, parts) do
      :ok
    else
      error ->
        MyApp.Oss.abort_multipart_upload(bucket, key, upload_id)
        error
    end
  end
  
  defp upload_parts(bucket, key, upload_id, file_path) do
    file_path
    |> File.stream!([], 5_242_880)  # 5MB chunks
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
  end
end
```

### 前端直传令牌

```elixir
# 生成前端上传令牌
expire_time = System.system_time(:second) + 3600
conditions = [
  ["content-length-range", 0, 10485760],  # 10MB限制
  ["starts-with", "$key", "uploads/"]     # 路径限制
]

{:ok, token} = MyApp.Oss.get_token("my-bucket", expire_time, conditions)

# 返回给前端的数据
%{
  "OSSAccessKeyId" => token.access_key_id,
  "policy" => token.policy,
  "signature" => token.signature,
  "host" => "https://my-bucket.oss-cn-beijing.aliyuncs.com",
  "key" => "uploads/${filename}"
}
```

### 批量操作

```elixir
# 批量删除文件
files_to_delete = ["temp/file1.txt", "temp/file2.txt", "temp/file3.txt"]
MyApp.Oss.delete_multiple_objects("my-bucket", files_to_delete)

# 批量获取文件信息
files = ["doc1.txt", "doc2.txt", "doc3.txt"]
file_info = files
|> Task.async_stream(fn file ->
     MyApp.Oss.head_object("my-bucket", file)
   end, max_concurrency: 10)
|> Enum.map(fn {:ok, result} -> result end)
```

- 📖 [在线文档](https://hexdocs.pm/lib_oss/LibOss.html) - HexDocs API文档

## 配置选项

支持多种配置方式和环境：

```elixir
config :my_app, MyApp.Oss,
  # 必需配置
  endpoint: "oss-cn-beijing.aliyuncs.com",
  access_key_id: "your_access_key_id", 
  access_key_secret: "your_access_key_secret",
  
  # 可选配置
  timeout: 30_000,           # 请求超时时间
  pool_size: 10,             # 连接池大小
  debug: false               # 调试模式
```

支持通过环境变量覆盖配置：

```bash
export OSS_ENDPOINT="oss-cn-shanghai.aliyuncs.com"
export OSS_ACCESS_KEY_ID="your_key_id"
export OSS_ACCESS_KEY_SECRET="your_secret"
```

## 测试

运行测试需要配置有效的OSS凭证：

```bash
# 设置测试环境变量
export OSS_ENDPOINT="your-test-endpoint"
export OSS_ACCESS_KEY_ID="your-test-key-id"
export OSS_ACCESS_KEY_SECRET="your-test-secret"

# 运行测试
mix test

# 运行特定测试
mix test test/lib_oss/api/object_test.exs
```

## 贡献

欢迎贡献代码和文档！请参考以下步骤：

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -am 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建Pull Request

## 许可证

本项目采用 [MIT License](LICENSE) 许可证。

## 更新日志

### v3.0.x
- ✅ **类型安全性大幅提升**: 修复33个Dialyzer类型问题，类型错误减少86.8%（38→5）
- ✅ **类型规范完善**: 添加完整的TypeSpec定义和类型约束
- ✅ **异常处理优化**: 统一异常消息格式，提升错误可读性
- ✅ **HTTP模型改进**: 修复URI类型匹配问题，使用标准URI构造方式
- ✅ **核心模块类型修复**: 修复token、acl、bucket、multipart、tagging等核心模块的类型违规
- ✅ **编译警告清除**: 消除struct类型更新相关的编译警告
- ✅ **代码质量提升**: 通过Dialyzer静态分析，确保类型安全
- ✅ **模块类型定义**: 新增tags等缺失的类型定义
- ✅ **兼容性保证**: 所有修复保持向后兼容，不破坏现有API

### v0.2.x
- ✅ 重构模块架构，按功能域分离
- ✅ 增强配置验证和管理
- ✅ 替换XML解析库，提高稳定性
- ✅ 完善文档和使用指南
- ✅ 优化错误处理机制

### v0.1.x
- ✅ 基础对象操作功能
- ✅ 分片上传支持
- ✅ 访问控制管理
- ✅ 前端直传令牌生成

## 支持

如果您在使用过程中遇到问题：

2. 搜索 [GitHub Issues](https://github.com/your-repo/lib_oss/issues)
3. 提交新的Issue描述问题
4. 参考[阿里云OSS官方文档](https://help.aliyun.com/product/31815.html)
