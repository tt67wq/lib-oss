defmodule LibOss.Core.ResponseParser do
  @moduledoc """
  响应解析模块，负责XML响应解析、错误处理和数据提取
  """

  alias LibOss.Exception
  alias LibOss.Model.Http

  @doc """
  解析HTTP响应

  ## 参数
  - response: HTTP响应结构

  ## 返回值
  - {:ok, parsed_data} | {:error, Exception.t()}
  """
  @spec parse_response(Http.Response.t()) :: {:ok, any()} | {:error, Exception.t()}
  def parse_response(%Http.Response{status_code: status_code, body: body, headers: headers}) do
    case status_code do
      code when code in 200..299 ->
        {:ok, %{body: body, headers: headers, status_code: status_code}}

      code when code >= 400 ->
        parse_error_response(body, code, headers)

      code ->
        {:error, Exception.new(:unexpected_status_code, "Unexpected status code: #{code}")}
    end
  end

  @doc """
  解析XML响应体

  ## 参数
  - body: 响应体内容
  - extract_path: XML路径，用于提取特定内容 (可选)

  ## 返回值
  - {:ok, parsed_xml} | {:error, Exception.t()}
  """
  @spec parse_xml_response(binary(), binary() | nil) :: {:ok, any()} | {:error, Exception.t()}
  def parse_xml_response(body, extract_path \\ nil) do
    case LibOss.Xml.naive_map(body) do
      parsed when is_map(parsed) ->
        if extract_path do
          {:ok, extract_from_xml(parsed, extract_path)}
        else
          {:ok, parsed}
        end

      _ ->
        {:error, Exception.new("Failed to parse XML response")}
    end
  end

  @doc """
  解析错误响应

  ## 参数
  - body: 响应体内容
  - status_code: HTTP状态码
  - headers: 响应头

  ## 返回值
  - {:error, Exception.t()}
  """
  @spec parse_error_response(binary(), integer(), list()) :: {:error, Exception.t()}
  def parse_error_response(body, status_code, headers) do
    case parse_xml_response(body) do
      {:ok, parsed_xml} ->
        error_code = extract_from_xml(parsed_xml, "Code") || "UnknownError"
        error_message = extract_from_xml(parsed_xml, "Message") || "Unknown error occurred"
        request_id = extract_from_xml(parsed_xml, "RequestId") || get_request_id_from_headers(headers)

        {:error,
         Exception.new("#{error_code}: #{error_message}", %{
           status_code: status_code,
           request_id: request_id,
           headers: headers
         })}

      {:error, _} ->
        # 如果XML解析失败，使用状态码创建通用错误
        {:error,
         Exception.new("HTTP #{status_code}: #{body}", %{
           status_code: status_code,
           headers: headers
         })}
    end
  end

  @doc """
  从XML中提取指定路径的值

  ## 参数
  - xml: 解析后的XML结构
  - path: 要提取的XML路径

  ## 返回值
  - 提取的值或nil
  """
  @spec extract_from_xml(any(), binary()) :: any()
  def extract_from_xml(xml, path) when is_binary(path) do
    path_parts = String.split(path, ".")
    extract_by_path(xml, path_parts)
  end

  @doc """
  提取分片上传信息

  ## 参数
  - xml: 解析后的XML结构

  ## 返回值
  - 分片上传信息结构
  """
  @spec extract_multipart_info(any()) :: map()
  def extract_multipart_info(xml) do
    %{
      upload_id: extract_from_xml(xml, "UploadId"),
      bucket: extract_from_xml(xml, "Bucket"),
      key: extract_from_xml(xml, "Key")
    }
  end

  @doc """
  提取对象列表信息

  ## 参数
  - xml: 解析后的XML结构

  ## 返回值
  - 对象列表信息结构
  """
  @spec extract_object_list(any()) :: map()
  def extract_object_list(xml) do
    contents = extract_from_xml(xml, "Contents") || []
    contents = if is_list(contents), do: contents, else: [contents]

    objects =
      Enum.map(contents, fn content ->
        %{
          key: extract_from_xml(content, "Key"),
          last_modified: extract_from_xml(content, "LastModified"),
          etag: extract_from_xml(content, "ETag"),
          size: extract_from_xml(content, "Size"),
          storage_class: extract_from_xml(content, "StorageClass"),
          owner: %{
            id: extract_from_xml(content, "Owner.ID"),
            display_name: extract_from_xml(content, "Owner.DisplayName")
          }
        }
      end)

    %{
      name: extract_from_xml(xml, "Name"),
      prefix: extract_from_xml(xml, "Prefix"),
      marker: extract_from_xml(xml, "Marker"),
      max_keys: extract_from_xml(xml, "MaxKeys"),
      is_truncated: extract_from_xml(xml, "IsTruncated") == "true",
      next_marker: extract_from_xml(xml, "NextMarker"),
      objects: objects
    }
  end

  @doc """
  提取ACL信息

  ## 参数
  - xml: 解析后的XML结构

  ## 返回值
  - ACL信息结构
  """
  @spec extract_acl_info(any()) :: map()
  def extract_acl_info(xml) do
    %{
      owner: %{
        id: extract_from_xml(xml, "Owner.ID"),
        display_name: extract_from_xml(xml, "Owner.DisplayName")
      },
      access_control_list: extract_access_control_grants(xml)
    }
  end

  @doc """
  提取标签信息

  ## 参数
  - xml: 解析后的XML结构

  ## 返回值
  - 标签列表
  """
  @spec extract_tags(any()) :: list()
  def extract_tags(xml) do
    tag_set = extract_from_xml(xml, "TagSet.Tag") || []
    tag_set = if is_list(tag_set), do: tag_set, else: [tag_set]

    Enum.map(tag_set, fn tag ->
      %{
        key: extract_from_xml(tag, "Key"),
        value: extract_from_xml(tag, "Value")
      }
    end)
  end

  # 私有函数

  defp extract_by_path(data, []), do: data

  defp extract_by_path(data, [head | tail]) when is_map(data) do
    case Map.get(data, head) do
      nil -> nil
      value -> extract_by_path(value, tail)
    end
  end

  defp extract_by_path(data, [head | tail]) when is_list(data) do
    # 对于列表，尝试在第一个元素中查找
    case List.first(data) do
      nil -> nil
      first_item -> extract_by_path(first_item, [head | tail])
    end
  end

  defp extract_by_path(_, _), do: nil

  defp get_request_id_from_headers(headers) do
    Enum.find_value(headers, fn
      {"x-oss-request-id", value} -> value
      {"X-Oss-Request-Id", value} -> value
      _ -> nil
    end)
  end

  defp extract_access_control_grants(xml) do
    grants = extract_from_xml(xml, "AccessControlList.Grant") || []
    grants = if is_list(grants), do: grants, else: [grants]

    Enum.map(grants, fn grant ->
      %{
        grantee: %{
          id: extract_from_xml(grant, "Grantee.ID"),
          display_name: extract_from_xml(grant, "Grantee.DisplayName"),
          uri: extract_from_xml(grant, "Grantee.URI")
        },
        permission: extract_from_xml(grant, "Permission")
      }
    end)
  end
end
