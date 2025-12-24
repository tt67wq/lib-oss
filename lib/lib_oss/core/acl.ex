defmodule LibOss.Core.Acl do
  @moduledoc """
  ACL管理模块

  负责：
  - 对象ACL：put_object_acl, get_object_acl
  - 存储桶ACL：put_bucket_acl, get_bucket_acl
  - ACL验证逻辑
  """

  alias LibOss.Core
  alias LibOss.Core.RequestBuilder
  alias LibOss.Core.ResponseParser
  alias LibOss.Exception
  alias LibOss.Model.Http
  alias LibOss.Typespecs

  @type err_t() :: {:error, Exception.t()}

  # 有效的ACL值
  @valid_acls ["private", "public-read", "public-read-write", "default"]

  @doc """
  设置对象ACL

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 对象名称
  - acl: ACL权限值

  ## ACL权限值
  - "private": 私有权限
  - "public-read": 公共读权限
  - "public-read-write": 公共读写权限
  - "default": 继承存储桶权限

  ## 返回值
  - :ok | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Acl.put_object_acl(MyOss, "my-bucket", "my-object", "public-read")
      :ok
  """
  @spec put_object_acl(module(), Typespecs.bucket(), Typespecs.object(), Typespecs.acl()) :: :ok | err_t()
  def put_object_acl(name, bucket, object, acl) do
    with :ok <- validate_acl(acl) do
      req =
        RequestBuilder.build_base_request(:put, bucket, object,
          headers: [{"x-oss-object-acl", acl}],
          sub_resources: [{"acl", nil}]
        )

      with {:ok, _} <- Core.call(name, req), do: :ok
    end
  end

  @doc """
  获取对象ACL

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 对象名称

  ## 返回值
  - {:ok, map()} | {:error, Exception.t()}

  返回的map包含：
  - owner: 所有者信息
  - access_control_list: 访问控制列表

  ## 示例
      iex> LibOss.Core.Acl.get_object_acl(MyOss, "my-bucket", "my-object")
      {:ok, %{
        owner: %{id: "owner-id", display_name: "owner-name"},
        access_control_list: [%{permission: "FULL_CONTROL", ...}]
      }}
  """
  @spec get_object_acl(module(), Typespecs.bucket(), Typespecs.object()) :: {:ok, map()} | err_t()
  def get_object_acl(name, bucket, object) do
    req =
      RequestBuilder.build_base_request(:get, bucket, object, sub_resources: [{"acl", nil}])

    with {:ok, %Http.Response{body: body}} <- Core.call(name, req),
         {:ok, xml} <- ResponseParser.parse_xml_response(body) do
      {:ok, ResponseParser.extract_acl_info(xml)}
    end
  end

  @doc """
  设置存储桶ACL

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - acl: ACL权限值

  ## ACL权限值
  - "private": 私有权限
  - "public-read": 公共读权限
  - "public-read-write": 公共读写权限

  ## 返回值
  - :ok | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Acl.put_bucket_acl(MyOss, "my-bucket", "public-read")
      :ok
  """
  @spec put_bucket_acl(module(), Typespecs.bucket(), Typespecs.acl()) :: :ok | err_t()
  def put_bucket_acl(name, bucket, acl) do
    # 存储桶ACL不支持 "default" 值
    bucket_valid_acls = @valid_acls -- ["default"]

    if acl in bucket_valid_acls do
      req =
        RequestBuilder.build_base_request(:put, bucket, "",
          headers: [{"x-oss-acl", acl}],
          sub_resources: [{"acl", nil}]
        )

      with {:ok, _} <- Core.call(name, req), do: :ok
    else
      {:error,
       Exception.new("invalid_acl: Invalid ACL for bucket: #{acl}. Valid values: #{inspect(bucket_valid_acls)}", acl)}
    end
  end

  @doc """
  获取存储桶ACL

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称

  ## 返回值
  - {:ok, map()} | {:error, Exception.t()}

  返回的map包含：
  - owner: 所有者信息
  - access_control_list: 访问控制列表

  ## 示例
      iex> LibOss.Core.Acl.get_bucket_acl(MyOss, "my-bucket")
      {:ok, %{
        owner: %{id: "owner-id", display_name: "owner-name"},
        access_control_list: [%{permission: "FULL_CONTROL", ...}]
      }}
  """
  @spec get_bucket_acl(module(), Typespecs.bucket()) :: {:ok, map()} | err_t()
  def get_bucket_acl(name, bucket) do
    req =
      RequestBuilder.build_base_request(:get, bucket, "", sub_resources: [{"acl", nil}])

    with {:ok, %Http.Response{body: body}} <- Core.call(name, req),
         {:ok, xml} <- ResponseParser.parse_xml_response(body) do
      {:ok, ResponseParser.extract_acl_info(xml)}
    end
  end

  @doc """
  验证ACL值是否有效

  ## 参数
  - acl: 要验证的ACL值

  ## 返回值
  - :ok | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Acl.validate_acl("public-read")
      :ok

      iex> LibOss.Core.Acl.validate_acl("invalid-acl")
      {:error, %LibOss.Exception{}}
  """
  @spec validate_acl(Typespecs.acl()) :: :ok | {:error, Exception.t()}
  def validate_acl(acl) when acl in @valid_acls, do: :ok

  def validate_acl(acl) do
    {:error, Exception.new("invalid_acl: Invalid ACL: #{acl}. Valid values: #{inspect(@valid_acls)}", acl)}
  end

  @doc """
  获取有效的ACL值列表

  ## 返回值
  - [String.t()]

  ## 示例
      iex> LibOss.Core.Acl.valid_acls()
      ["private", "public-read", "public-read-write", "default"]
  """
  @spec valid_acls() :: [String.t()]
  def valid_acls, do: @valid_acls

  @doc """
  检查ACL是否为公共可读

  ## 参数
  - acl: ACL值

  ## 返回值
  - boolean()

  ## 示例
      iex> LibOss.Core.Acl.public_readable?("public-read")
      true

      iex> LibOss.Core.Acl.public_readable?("private")
      false
  """
  @spec public_readable?(Typespecs.acl()) :: boolean()
  def public_readable?(acl) when acl in ["public-read", "public-read-write"], do: true
  def public_readable?(_), do: false

  @doc """
  检查ACL是否为公共可写

  ## 参数
  - acl: ACL值

  ## 返回值
  - boolean()

  ## 示例
      iex> LibOss.Core.Acl.public_writable?("public-read-write")
      true

      iex> LibOss.Core.Acl.public_writable?("public-read")
      false
  """
  @spec public_writable?(Typespecs.acl()) :: boolean()
  def public_writable?("public-read-write"), do: true
  def public_writable?(_), do: false

  @doc """
  将ACL字符串转换为权限描述

  ## 参数
  - acl: ACL值

  ## 返回值
  - String.t()

  ## 示例
      iex> LibOss.Core.Acl.acl_to_description("public-read")
      "Public read access"
  """
  @spec acl_to_description(Typespecs.acl()) :: String.t()
  def acl_to_description("private"), do: "Private access"
  def acl_to_description("public-read"), do: "Public read access"
  def acl_to_description("public-read-write"), do: "Public read-write access"
  def acl_to_description("default"), do: "Inherit bucket ACL"
  def acl_to_description(acl), do: "Unknown ACL: #{acl}"
end
