defmodule LibOss.Core.Multipart do
  @moduledoc """
  分片上传模块

  负责：
  - 初始化：init_multi_upload
  - 上传分片：upload_part
  - 列表操作：list_multipart_uploads, list_parts
  - 完成/中止：complete_multipart_upload, abort_multipart_upload
  """

  alias LibOss.Core
  alias LibOss.Core.RequestBuilder
  alias LibOss.Core.ResponseParser
  alias LibOss.Exception
  alias LibOss.Model.Http
  alias LibOss.Typespecs

  @type err_t() :: {:error, Exception.t()}

  # 分片大小限制（5MB - 5GB）
  @min_part_size 5 * 1024 * 1024
  @max_part_size 5 * 1024 * 1024 * 1024
  # 最大分片数量
  @max_parts 10_000

  @doc """
  初始化分片上传

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 对象名称
  - req_headers: 可选的HTTP请求头

  ## 返回值
  - {:ok, upload_id} | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Multipart.init_multi_upload(MyOss, "my-bucket", "large-file.zip")
      {:ok, "upload-id-123456"}

  ## 相关文档
  https://help.aliyun.com/document_detail/31992.html
  """
  @spec init_multi_upload(
          module(),
          Typespecs.bucket(),
          Typespecs.object(),
          Typespecs.headers()
        ) ::
          {:ok, Typespecs.upload_id()} | err_t()
  def init_multi_upload(name, bucket, object, req_headers \\ []) do
    req =
      RequestBuilder.build_base_request(:post, bucket, object,
        headers: req_headers,
        sub_resources: [{"uploads", nil}]
      )

    with {:ok, %Http.Response{body: body}} <- Core.call(name, req),
         {:ok, xml} <- ResponseParser.parse_xml_response(body) do
      case ResponseParser.extract_from_xml(xml, "UploadId") do
        nil -> {:error, Exception.new("invalid_response: UploadId not found in response", "missing_upload_id")}
        upload_id -> {:ok, upload_id}
      end
    end
  end

  @doc """
  上传分片

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 对象名称
  - upload_id: 上传ID
  - part_number: 分片号（1-10000）
  - data: 分片数据

  ## 返回值
  - {:ok, etag} | {:error, Exception.t()}

  ## 分片限制
  - 分片号范围：1-10000
  - 分片大小：5MB-5GB（最后一个分片可以小于5MB）

  ## 示例
      iex> LibOss.Core.Multipart.upload_part(MyOss, "my-bucket", "large-file.zip", "upload-id-123456", 1, data)
      {:ok, "\"etag-value\""}

  ## 相关文档
  https://help.aliyun.com/document_detail/31993.html
  """
  @spec upload_part(
          module(),
          Typespecs.bucket(),
          Typespecs.object(),
          Typespecs.upload_id(),
          Typespecs.part_num(),
          binary()
        ) ::
          {:ok, binary()} | err_t()
  def upload_part(name, bucket, object, upload_id, part_number, data) do
    with :ok <- validate_part_number(part_number),
         :ok <- validate_part_size(data) do
      req =
        RequestBuilder.build_base_request(:put, bucket, object,
          body: data,
          sub_resources: [{"partNumber", "#{part_number}"}, {"uploadId", upload_id}]
        )

      with {:ok, %Http.Response{headers: headers}} <- Core.call(name, req) do
        case find_etag_header(headers) do
          {:ok, etag} -> {:ok, etag}
          :error -> {:error, Exception.new("etag_not_found: ETag header not found in response", "missing_etag")}
        end
      end
    end
  end

  @doc """
  列出分片上传任务

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - query_params: 查询参数

  ## 查询参数
  - key-marker: 起始对象名
  - upload-id-marker: 起始上传ID
  - max-uploads: 最大返回数量

  ## 返回值
  - {:ok, map()} | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Multipart.list_multipart_uploads(MyOss, "my-bucket", %{"max-uploads" => "100"})
      {:ok, %{uploads: [...], is_truncated: false}}

  ## 相关文档
  https://help.aliyun.com/document_detail/31997.html
  """
  @spec list_multipart_uploads(
          module(),
          Typespecs.bucket(),
          Typespecs.params()
        ) ::
          {:ok, map()} | err_t()
  def list_multipart_uploads(name, bucket, query_params) do
    req =
      RequestBuilder.build_base_request(:get, bucket, "", params: Map.put(query_params, "uploads", ""))

    with {:ok, %Http.Response{body: body}} <- Core.call(name, req),
         {:ok, xml} <- ResponseParser.parse_xml_response(body) do
      {:ok, extract_multipart_uploads(xml)}
    end
  end

  @doc """
  完成分片上传

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 对象名称
  - upload_id: 上传ID
  - parts: 分片列表，格式为 [{part_number, etag}, ...]
  - headers: 可选的HTTP请求头

  ## 返回值
  - :ok | {:error, Exception.t()}

  ## 示例
      iex> parts = [{1, "\"etag1\""}, {2, "\"etag2\""}]
      iex> LibOss.Core.Multipart.complete_multipart_upload(MyOss, "my-bucket", "large-file.zip", "upload-id-123456", parts)
      :ok

  ## 相关文档
  https://help.aliyun.com/document_detail/31995.html
  """
  @spec complete_multipart_upload(
          module(),
          Typespecs.bucket(),
          Typespecs.object(),
          Typespecs.upload_id(),
          [{Typespecs.part_num(), Typespecs.etag()}],
          Typespecs.headers()
        ) :: :ok | err_t()
  def complete_multipart_upload(name, bucket, object, upload_id, parts, headers \\ []) do
    with :ok <- validate_parts_list(parts) do
      body = build_complete_multipart_xml(parts)

      req =
        RequestBuilder.build_base_request(:post, bucket, object,
          body: body,
          headers: headers,
          sub_resources: [{"uploadId", upload_id}]
        )

      with {:ok, _} <- Core.call(name, req), do: :ok
    end
  end

  @doc """
  中止分片上传

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 对象名称
  - upload_id: 上传ID

  ## 返回值
  - :ok | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Multipart.abort_multipart_upload(MyOss, "my-bucket", "large-file.zip", "upload-id-123456")
      :ok

  ## 相关文档
  https://help.aliyun.com/document_detail/31996.html
  """
  @spec abort_multipart_upload(
          module(),
          Typespecs.bucket(),
          Typespecs.object(),
          Typespecs.upload_id()
        ) :: :ok | err_t()
  def abort_multipart_upload(name, bucket, object, upload_id) do
    req =
      RequestBuilder.build_base_request(:delete, bucket, object, sub_resources: [{"uploadId", upload_id}])

    with {:ok, _} <- Core.call(name, req), do: :ok
  end

  @doc """
  列出已上传的分片

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 对象名称
  - upload_id: 上传ID
  - query_params: 查询参数（可选）

  ## 查询参数
  - part-number-marker: 起始分片号
  - max-parts: 最大返回数量

  ## 返回值
  - {:ok, map()} | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Multipart.list_parts(MyOss, "my-bucket", "large-file.zip", "upload-id-123456")
      {:ok, %{parts: [...], is_truncated: false}}

  ## 相关文档
  https://help.aliyun.com/document_detail/31998.html
  """
  @spec list_parts(
          module(),
          Typespecs.bucket(),
          Typespecs.object(),
          Typespecs.upload_id(),
          Typespecs.params()
        ) ::
          {:ok, map()} | err_t()
  def list_parts(name, bucket, object, upload_id, query_params \\ %{}) do
    req =
      RequestBuilder.build_base_request(:get, bucket, object,
        params: query_params,
        sub_resources: [{"uploadId", upload_id}]
      )

    with {:ok, %Http.Response{body: body}} <- Core.call(name, req),
         {:ok, xml} <- ResponseParser.parse_xml_response(body) do
      {:ok, extract_parts_list(xml)}
    end
  end

  @doc """
  计算文件分片数量

  ## 参数
  - file_size: 文件大小（字节）
  - part_size: 分片大小（字节，可选，默认5MB）

  ## 返回值
  - non_neg_integer()

  ## 示例
      iex> LibOss.Core.Multipart.calculate_part_count(100 * 1024 * 1024)
      20
  """
  @spec calculate_part_count(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def calculate_part_count(file_size, part_size \\ @min_part_size) do
    (file_size / part_size) |> :math.ceil() |> trunc()
  end

  @doc """
  获取推荐的分片大小

  ## 参数
  - file_size: 文件大小（字节）

  ## 返回值
  - non_neg_integer()

  根据文件大小自动计算合适的分片大小，确保分片数量不超过10000个

  ## 示例
      iex> LibOss.Core.Multipart.recommended_part_size(1024 * 1024 * 1024)
      5242880
  """
  @spec recommended_part_size(non_neg_integer()) :: non_neg_integer()
  def recommended_part_size(file_size) do
    # 计算最小分片大小以确保不超过最大分片数量
    min_required_size = (file_size / @max_parts) |> :math.ceil() |> trunc()
    max(@min_part_size, min_required_size)
  end

  @doc """
  验证分片上传参数

  ## 参数
  - file_size: 文件大小
  - part_size: 分片大小

  ## 返回值
  - :ok | {:error, Exception.t()}
  """
  @spec validate_multipart_params(non_neg_integer(), non_neg_integer()) :: :ok | err_t()
  def validate_multipart_params(file_size, part_size) do
    part_count = calculate_part_count(file_size, part_size)

    cond do
      part_size < @min_part_size ->
        {:error, Exception.new("invalid_part_size: Part size must be at least #{@min_part_size} bytes", part_size)}

      part_size > @max_part_size ->
        {:error, Exception.new("invalid_part_size: Part size cannot exceed #{@max_part_size} bytes", part_size)}

      part_count > @max_parts ->
        {:error,
         Exception.new("too_many_parts: File would require #{part_count} parts, maximum is #{@max_parts}", part_count)}

      true ->
        :ok
    end
  end

  @doc """
  获取分片上传限制信息

  ## 返回值
  - map()

  ## 示例
      iex> LibOss.Core.Multipart.multipart_limits()
      %{
        min_part_size: 5242880,
        max_part_size: 5368709120,
        max_parts: 10000
      }
  """
  @spec multipart_limits() :: map()
  def multipart_limits do
    %{
      min_part_size: @min_part_size,
      max_part_size: @max_part_size,
      max_parts: @max_parts
    }
  end

  # 私有辅助函数

  defp validate_part_number(part_number) when part_number >= 1 and part_number <= @max_parts, do: :ok

  defp validate_part_number(part_number) do
    {:error,
     Exception.new(
       "invalid_part_number: Part number must be between 1 and #{@max_parts}, got #{part_number}",
       part_number
     )}
  end

  defp validate_part_size(data) when byte_size(data) >= @min_part_size, do: :ok
  # 最后一个分片可以小于5MB
  defp validate_part_size(data) when byte_size(data) > 0, do: :ok

  defp validate_part_size(data) do
    {:error,
     Exception.new("invalid_part_size: Part size is #{byte_size(data)} bytes, must be at least 1 byte", byte_size(data))}
  end

  defp validate_parts_list([]), do: {:error, Exception.new("empty_parts_list: Parts list cannot be empty", [])}

  defp validate_parts_list(parts) when length(parts) > @max_parts do
    {:error, Exception.new("too_many_parts: Cannot have more than #{@max_parts} parts", length(parts))}
  end

  defp validate_parts_list(parts) do
    # 验证分片号是否连续且唯一
    part_numbers = Enum.map(parts, fn {part_num, _etag} -> part_num end)
    sorted_numbers = Enum.sort(part_numbers)
    expected_numbers = Enum.to_list(1..length(parts))

    if sorted_numbers == expected_numbers and length(Enum.uniq(part_numbers)) == length(parts) do
      :ok
    else
      {:error, Exception.new("invalid_parts_list: Part numbers must be consecutive and unique starting from 1", parts)}
    end
  end

  defp find_etag_header(headers) do
    headers
    |> Enum.find(fn
      {"etag", _} -> true
      {"ETag", _} -> true
      _ -> false
    end)
    |> case do
      {_, value} -> {:ok, value}
      nil -> :error
    end
  end

  defp build_complete_multipart_xml(parts) do
    parts_xml =
      Enum.map_join(parts, "", fn {part_number, etag} ->
        "<Part><PartNumber>#{part_number}</PartNumber><ETag>#{escape_xml(etag)}</ETag></Part>"
      end)

    "<CompleteMultipartUpload>#{parts_xml}</CompleteMultipartUpload>"
  end

  defp extract_multipart_uploads(xml) do
    uploads = ResponseParser.extract_from_xml(xml, "Upload") || []
    uploads = if is_list(uploads), do: uploads, else: [uploads]

    upload_list =
      Enum.map(uploads, fn upload ->
        %{
          key: ResponseParser.extract_from_xml(upload, "Key"),
          upload_id: ResponseParser.extract_from_xml(upload, "UploadId"),
          initiated: ResponseParser.extract_from_xml(upload, "Initiated")
        }
      end)

    %{
      bucket: ResponseParser.extract_from_xml(xml, "Bucket"),
      key_marker: ResponseParser.extract_from_xml(xml, "KeyMarker"),
      upload_id_marker: ResponseParser.extract_from_xml(xml, "UploadIdMarker"),
      next_key_marker: ResponseParser.extract_from_xml(xml, "NextKeyMarker"),
      next_upload_id_marker: ResponseParser.extract_from_xml(xml, "NextUploadIdMarker"),
      max_uploads: ResponseParser.extract_from_xml(xml, "MaxUploads"),
      is_truncated: ResponseParser.extract_from_xml(xml, "IsTruncated") == "true",
      uploads: upload_list
    }
  end

  defp extract_parts_list(xml) do
    parts = ResponseParser.extract_from_xml(xml, "Part") || []
    parts = if is_list(parts), do: parts, else: [parts]

    parts_list =
      Enum.map(parts, fn part ->
        %{
          part_number: ResponseParser.extract_from_xml(part, "PartNumber"),
          last_modified: ResponseParser.extract_from_xml(part, "LastModified"),
          etag: ResponseParser.extract_from_xml(part, "ETag"),
          size: ResponseParser.extract_from_xml(part, "Size")
        }
      end)

    %{
      bucket: ResponseParser.extract_from_xml(xml, "Bucket"),
      key: ResponseParser.extract_from_xml(xml, "Key"),
      upload_id: ResponseParser.extract_from_xml(xml, "UploadId"),
      part_number_marker: ResponseParser.extract_from_xml(xml, "PartNumberMarker"),
      next_part_number_marker: ResponseParser.extract_from_xml(xml, "NextPartNumberMarker"),
      max_parts: ResponseParser.extract_from_xml(xml, "MaxParts"),
      is_truncated: ResponseParser.extract_from_xml(xml, "IsTruncated") == "true",
      parts: parts_list
    }
  end

  defp escape_xml(text) do
    text
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
