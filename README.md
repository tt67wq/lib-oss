<!-- MDOC !-->
# LibOss

LibOss是Elixir实现的一个[阿里云oss](https://help.aliyun.com/product/31815.html)的SDK，目前支持的功能有：

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


## 使用方法

```elixir
Mix.install([
  {:lib_oss, "~> 0.1"}
])

# 创建一个oss客户端
defmodule MyOss do
  use LibOss, otp_app: :my_app
end

# 配置客户端
config :my_app, MyOss,
    endpoint: "oss-cn-somewhere.aliyuncs.com",
    access_key_id: "your access key id",
    access_key_secret: "your access key secret"

# 在superivsor中启动
Supervisor.start_link(
  [
    MyOss
  ],
  strategy: :one_for_one
)

# 上传文件
{:ok, content} = File.read("./test.txt")
MyOss.put_object("hope-data", "/test/test.txt", content)
```

更多使用方法请参考[API文档](https://hexdocs.pm/lib_oss/LibOss.html)