defmodule LibOss.Core.Bucket do
  @moduledoc """
  存储桶操作模块

  负责：
  - 基础操作：put_bucket, delete_bucket
  - 对象列表：get_bucket, list_object_v2
  - 存储桶信息：get_bucket_info, get_bucket_location, get_bucket_stat
  """

  alias LibOss.Core
  alias LibOss.Core.RequestBuilder
  alias LibOss.Core.ResponseParser
  alias LibOss.Exception
  alias LibOss.Model.Http
  alias LibOss.Typespecs

  @type err_t() :: {:error, Exception.t()}

  # 有效的存储类型
  @valid_storage_classes ["Standard", "IA", "Archive", "ColdArchive"]
  # 有效的冗余类型
  @valid_redundancy_types ["LRS", "ZRS"]

  @doc """
  创建存储桶

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - storage_class: 存储类型（可选，默认"Standard"）
  - data_redundancy_type: 数据冗余类型（可选，默认"LRS"）
  - headers: 可选的HTTP请求头

  ## 存储类型
  - "Standard": 标准存储
  - "IA": 低频访问存储
  - "Archive": 归档存储
  - "ColdArchive": 冷归档存储

  ## 数据冗余类型
  - "LRS": 本地冗余存储
  - "ZRS": 同城冗余存储

  ## 返回值
  - :ok | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Bucket.put_bucket(MyOss, "my-bucket")
      :ok

      iex> LibOss.Core.Bucket.put_bucket(MyOss, "my-bucket", "IA", "ZRS")
      :ok

  ## 相关文档
  https://help.aliyun.com/document_detail/31946.html
  """
  @spec put_bucket(module(), Typespecs.bucket(), String.t(), String.t(), Typespecs.headers()) :: :ok | err_t()
  def put_bucket(name, bucket, storage_class \\ "Standard", data_redundancy_type \\ "LRS", headers \\ []) do
    with :ok <- validate_storage_class(storage_class),
         :ok <- validate_redundancy_type(data_redundancy_type) do
      body = build_create_bucket_xml(storage_class, data_redundancy_type)

      req =
        RequestBuilder.build_base_request(:put, bucket, "",
          body: body,
          headers: headers
        )

      with {:ok, _} <- Core.call(name, req), do: :ok
    end
  end

  @doc """
  删除存储桶

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称

  ## 返回值
  - :ok | {:error, Exception.t()}

  注意：只能删除空的存储桶

  ## 示例
      iex> LibOss.Core.Bucket.delete_bucket(MyOss, "my-bucket")
      :ok

  ## 相关文档
  https://help.aliyun.com/document_detail/31947.html
  """
  @spec delete_bucket(module(), Typespecs.bucket()) :: :ok | err_t()
  def delete_bucket(name, bucket) do
    req = RequestBuilder.build_base_request(:delete, bucket, "")

    with {:ok, _} <- Core.call(name, req), do: :ok
  end

  @doc """
  列出存储桶中的对象（v1 API）

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - query_params: 查询参数

  ## 查询参数
  - prefix: 对象名前缀
  - marker: 起始对象名
  - max-keys: 最大返回数量
  - delimiter: 分隔符

  ## 返回值
  - {:ok, map()} | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Bucket.get_bucket(MyOss, "my-bucket", %{"prefix" => "photos/"})
      {:ok, %{objects: [...], is_truncated: false}}

  ## 相关文档
  https://help.aliyun.com/document_detail/31948.html
  """
  @spec get_bucket(module(), Typespecs.bucket(), Typespecs.params()) :: {:ok, map()} | err_t()
  def get_bucket(name, bucket, query_params) do
    req =
      RequestBuilder.build_base_request(:get, bucket, "", params: query_params)

    with {:ok, %Http.Response{body: body}} <- Core.call(name, req),
         {:ok, xml} <- ResponseParser.parse_xml_response(body) do
      {:ok, ResponseParser.extract_object_list(xml)}
    end
  end

  @doc """
  列出存储桶中的对象（v2 API）

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - query_params: 查询参数

  ## 查询参数
  - prefix: 对象名前缀
  - continuation-token: 继续标记
  - max-keys: 最大返回数量
  - start-after: 起始对象名
  - delimiter: 分隔符

  ## 返回值
  - {:ok, map()} | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Bucket.list_object_v2(MyOss, "my-bucket", %{"prefix" => "photos/"})
      {:ok, %{objects: [...], is_truncated: false}}

  ## 相关文档
  https://help.aliyun.com/document_detail/187544.html
  """
  @spec list_object_v2(module(), Typespecs.bucket(), Typespecs.params()) :: {:ok, map()} | err_t()
  def list_object_v2(name, bucket, query_params) do
    # 添加list-type=2参数以使用v2 API
    params_with_list_type = Map.put(query_params, "list-type", "2")

    req =
      RequestBuilder.build_base_request(:get, bucket, "", params: params_with_list_type)

    with {:ok, %Http.Response{body: body}} <- Core.call(name, req),
         {:ok, xml} <- ResponseParser.parse_xml_response(body) do
      {:ok, extract_object_list_v2(xml)}
    end
  end

  @doc """
  获取存储桶信息

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称

  ## 返回值
  - {:ok, map()} | {:error, Exception.t()}

  返回的map包含：
  - name: 存储桶名称
  - location: 数据中心
  - creation_date: 创建时间
  - storage_class: 存储类型
  - owner: 所有者信息

  ## 示例
      iex> LibOss.Core.Bucket.get_bucket_info(MyOss, "my-bucket")
      {:ok, %{
        name: "my-bucket",
        location: "oss-cn-hangzhou",
        creation_date: "2023-01-01T00:00:00.000Z",
        storage_class: "Standard"
      }}

  ## 相关文档
  https://help.aliyun.com/document_detail/31968.html
  """
  @spec get_bucket_info(module(), Typespecs.bucket()) :: {:ok, map()} | err_t()
  def get_bucket_info(name, bucket) do
    req =
      RequestBuilder.build_base_request(:get, bucket, "", sub_resources: [{"bucketInfo", nil}])

    with {:ok, %Http.Response{body: body}} <- Core.call(name, req),
         {:ok, xml} <- ResponseParser.parse_xml_response(body) do
      {:ok, extract_bucket_info(xml)}
    end
  end

  @doc """
  获取存储桶位置信息

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称

  ## 返回值
  - {:ok, String.t()} | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Bucket.get_bucket_location(MyOss, "my-bucket")
      {:ok, "oss-cn-hangzhou"}

  ## 相关文档
  https://help.aliyun.com/document_detail/31967.html
  """
  @spec get_bucket_location(module(), Typespecs.bucket()) :: {:ok, String.t()} | err_t()
  def get_bucket_location(name, bucket) do
    req =
      RequestBuilder.build_base_request(:get, bucket, "", sub_resources: [{"location", nil}])

    with {:ok, %Http.Response{body: body}} <- Core.call(name, req),
         {:ok, xml} <- ResponseParser.parse_xml_response(body) do
      location = ResponseParser.extract_from_xml(xml, "LocationConstraint") || ""
      {:ok, location}
    end
  end

  @doc """
  获取存储桶统计信息

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称

  ## 返回值
  - {:ok, map()} | {:error, Exception.t()}

  返回的map包含：
  - storage: 存储量统计
  - object_count: 对象数量统计
  - multipart_upload_count: 分片上传任务数量

  ## 示例
      iex> LibOss.Core.Bucket.get_bucket_stat(MyOss, "my-bucket")
      {:ok, %{
        storage: 1024000,
        object_count: 100,
        multipart_upload_count: 5
      }}

  ## 相关文档
  https://help.aliyun.com/document_detail/426056.html
  """
  @spec get_bucket_stat(module(), Typespecs.bucket()) :: {:ok, map()} | err_t()
  def get_bucket_stat(name, bucket) do
    req =
      RequestBuilder.build_base_request(:get, bucket, "", sub_resources: [{"stat", nil}])

    with {:ok, %Http.Response{body: body}} <- Core.call(name, req),
         {:ok, xml} <- ResponseParser.parse_xml_response(body) do
      {:ok, extract_bucket_stat(xml)}
    end
  end

  @doc """
  检查存储桶是否存在

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称

  ## 返回值
  - boolean()

  ## 示例
      iex> LibOss.Core.Bucket.bucket_exists?(MyOss, "my-bucket")
      true
  """
  @spec bucket_exists?(module(), Typespecs.bucket()) :: boolean()
  def bucket_exists?(name, bucket) do
    case get_bucket_info(name, bucket) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  获取存储桶中对象的总数（近似值）

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - prefix: 对象名前缀（可选）

  ## 返回值
  - {:ok, non_neg_integer()} | {:error, Exception.t()}

  注意：这是一个近似值，通过分页获取所有对象计算得出

  ## 示例
      iex> LibOss.Core.Bucket.get_object_count(MyOss, "my-bucket")
      {:ok, 1500}
  """
  @spec get_object_count(module(), Typespecs.bucket(), String.t()) :: {:ok, non_neg_integer()} | err_t()
  def get_object_count(name, bucket, prefix \\ "") do
    params = %{"max-keys" => "1", "prefix" => prefix}

    case list_object_v2(name, bucket, params) do
      {:ok, %{key_count: key_count}} when is_binary(key_count) ->
        {:ok, String.to_integer(key_count)}

      {:ok, %{key_count: key_count}} when is_integer(key_count) ->
        {:ok, key_count}

      {:ok, _} ->
        {:ok, 0}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  验证存储类型是否有效

  ## 参数
  - storage_class: 存储类型

  ## 返回值
  - :ok | {:error, Exception.t()}
  """
  @spec validate_storage_class(String.t()) :: :ok | err_t()
  def validate_storage_class(storage_class) when storage_class in @valid_storage_classes, do: :ok

  def validate_storage_class(storage_class) do
    {:error,
     Exception.new(
       "invalid_storage_class: Invalid storage class: #{storage_class}. Valid values: #{inspect(@valid_storage_classes)}",
       storage_class
     )}
  end

  @doc """
  验证数据冗余类型是否有效

  ## 参数
  - redundancy_type: 数据冗余类型

  ## 返回值
  - :ok | {:error, Exception.t()}
  """
  @spec validate_redundancy_type(String.t()) :: :ok | err_t()
  def validate_redundancy_type(redundancy_type) when redundancy_type in @valid_redundancy_types, do: :ok

  def validate_redundancy_type(redundancy_type) do
    {:error,
     Exception.new(
       "invalid_redundancy_type: Invalid redundancy type: #{redundancy_type}. Valid values: #{inspect(@valid_redundancy_types)}",
       redundancy_type
     )}
  end

  @doc """
  获取有效的存储类型列表

  ## 返回值
  - [String.t()]
  """
  @spec valid_storage_classes() :: [String.t()]
  def valid_storage_classes, do: @valid_storage_classes

  @doc """
  获取有效的数据冗余类型列表

  ## 返回值
  - [String.t()]
  """
  @spec valid_redundancy_types() :: [String.t()]
  def valid_redundancy_types, do: @valid_redundancy_types

  # 私有辅助函数

  defp build_create_bucket_xml(storage_class, data_redundancy_type) do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <CreateBucketConfiguration>
        <StorageClass>#{storage_class}</StorageClass>
        <DataRedundancyType>#{data_redundancy_type}</DataRedundancyType>
    </CreateBucketConfiguration>
    """
  end

  defp extract_object_list_v2(xml) do
    contents = ResponseParser.extract_from_xml(xml, "Contents") || []
    contents = if is_list(contents), do: contents, else: [contents]

    objects =
      Enum.map(contents, fn content ->
        %{
          key: ResponseParser.extract_from_xml(content, "Key"),
          last_modified: ResponseParser.extract_from_xml(content, "LastModified"),
          etag: ResponseParser.extract_from_xml(content, "ETag"),
          size: ResponseParser.extract_from_xml(content, "Size"),
          storage_class: ResponseParser.extract_from_xml(content, "StorageClass"),
          owner: %{
            id: ResponseParser.extract_from_xml(content, "Owner.ID"),
            display_name: ResponseParser.extract_from_xml(content, "Owner.DisplayName")
          }
        }
      end)

    %{
      name: ResponseParser.extract_from_xml(xml, "Name"),
      prefix: ResponseParser.extract_from_xml(xml, "Prefix"),
      start_after: ResponseParser.extract_from_xml(xml, "StartAfter"),
      continuation_token: ResponseParser.extract_from_xml(xml, "ContinuationToken"),
      next_continuation_token: ResponseParser.extract_from_xml(xml, "NextContinuationToken"),
      key_count: ResponseParser.extract_from_xml(xml, "KeyCount"),
      max_keys: ResponseParser.extract_from_xml(xml, "MaxKeys"),
      is_truncated: ResponseParser.extract_from_xml(xml, "IsTruncated") == "true",
      objects: objects
    }
  end

  defp extract_bucket_info(xml) do
    bucket_info = ResponseParser.extract_from_xml(xml, "BucketInfo") || %{}

    %{
      name: ResponseParser.extract_from_xml(bucket_info, "Name"),
      location: ResponseParser.extract_from_xml(bucket_info, "Location"),
      creation_date: ResponseParser.extract_from_xml(bucket_info, "CreationDate"),
      storage_class: ResponseParser.extract_from_xml(bucket_info, "StorageClass"),
      redundancy_type: ResponseParser.extract_from_xml(bucket_info, "DataRedundancyType"),
      owner: %{
        id: ResponseParser.extract_from_xml(bucket_info, "Owner.ID"),
        display_name: ResponseParser.extract_from_xml(bucket_info, "Owner.DisplayName")
      }
    }
  end

  defp extract_bucket_stat(xml) do
    bucket_stat = ResponseParser.extract_from_xml(xml, "BucketStat") || %{}

    %{
      storage: parse_integer(ResponseParser.extract_from_xml(bucket_stat, "Storage")),
      object_count: parse_integer(ResponseParser.extract_from_xml(bucket_stat, "ObjectCount")),
      multipart_upload_count: parse_integer(ResponseParser.extract_from_xml(bucket_stat, "MultipartUploadCount"))
    }
  end

  defp parse_integer(nil), do: 0
  defp parse_integer(value) when is_binary(value), do: String.to_integer(value)
  defp parse_integer(value) when is_integer(value), do: value
  defp parse_integer(_), do: 0
end
