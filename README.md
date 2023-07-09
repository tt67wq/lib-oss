# LibOss

LibOss是Elixir实现的一个[阿里云oss](https://help.aliyun.com/product/31815.html)的SDK，目前支持的功能有：

- Object：
  - [x] 上传文件
  - [x] 获取文件
  - [x] 删除文件
  - [x] 分片上传
  - [x] 获取前端直传签名



## 使用方法

### 在mix.exs中添加依赖

```elixir
# 尚未上传至hex.pm，暂时使用github地址
def deps do
  [
    {:lib_oss, github: "tt67wq/lib-oss", branch: "master"}
  ]
end
```


### 创建Oss客户端

```elixir
client = LibOss.new(
  endpoint: "your oss endpoint",
  access_key_id: "your access key id",
  access_key_secret: "your access key secret",
)
```

### 将LibOss添加至Supervisor

```elixir
children = [
  {LibOss, client: client}
]
```

