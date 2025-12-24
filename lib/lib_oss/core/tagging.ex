defmodule LibOss.Core.Tagging do
  @moduledoc """
  标签管理模块

  负责：
  - 对象标签：put_object_tagging, get_object_tagging, delete_object_tagging
  - 标签验证和处理
  """

  alias LibOss.Core
  alias LibOss.Core.RequestBuilder
  alias LibOss.Core.ResponseParser
  alias LibOss.Exception
  alias LibOss.Model.Http
  alias LibOss.Typespecs

  @type err_t() :: {:error, Exception.t()}

  # 标签数量限制
  @max_tags 10
  # 标签键值长度限制
  @max_key_length 128
  @max_value_length 256

  @doc """
  设置对象标签

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 对象名称
  - tags: 标签map或关键字列表

  ## 标签限制
  - 最多10个标签
  - 标签键最长128字符
  - 标签值最长256字符

  ## 返回值
  - :ok | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Tagging.put_object_tagging(MyOss, "my-bucket", "my-object", %{"env" => "prod", "team" => "backend"})
      :ok

      iex> LibOss.Core.Tagging.put_object_tagging(MyOss, "my-bucket", "my-object", [{"env", "prod"}, {"team", "backend"}])
      :ok

  ## 相关文档
  https://help.aliyun.com/document_detail/114878.html
  """
  @spec put_object_tagging(module(), Typespecs.bucket(), Typespecs.object(), Typespecs.dict() | keyword()) ::
          :ok | err_t()
  def put_object_tagging(name, bucket, object, tags) do
    with :ok <- validate_tags(tags) do
      body = build_tagging_xml(tags)

      req =
        RequestBuilder.build_base_request(:put, bucket, object,
          body: body,
          sub_resources: [{"tagging", nil}]
        )

      with {:ok, _} <- Core.call(name, req), do: :ok
    end
  end

  @doc """
  获取对象标签

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 对象名称

  ## 返回值
  - {:ok, [map()]} | {:error, Exception.t()}

  返回标签列表，每个标签包含key和value字段

  ## 示例
      iex> LibOss.Core.Tagging.get_object_tagging(MyOss, "my-bucket", "my-object")
      {:ok, [%{key: "env", value: "prod"}, %{key: "team", value: "backend"}]}

  ## 相关文档
  https://help.aliyun.com/document_detail/114878.html
  """
  @spec get_object_tagging(module(), Typespecs.bucket(), Typespecs.object()) :: {:ok, [map()]} | err_t()
  def get_object_tagging(name, bucket, object) do
    req =
      RequestBuilder.build_base_request(:get, bucket, object, sub_resources: [{"tagging", nil}])

    with {:ok, %Http.Response{body: body}} <- Core.call(name, req),
         {:ok, xml} <- ResponseParser.parse_xml_response(body) do
      {:ok, ResponseParser.extract_tags(xml)}
    end
  end

  @doc """
  删除对象标签

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 对象名称

  ## 返回值
  - :ok | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Tagging.delete_object_tagging(MyOss, "my-bucket", "my-object")
      :ok

  ## 相关文档
  https://help.aliyun.com/document_detail/114878.html
  """
  @spec delete_object_tagging(module(), Typespecs.bucket(), Typespecs.object()) :: :ok | err_t()
  def delete_object_tagging(name, bucket, object) do
    req =
      RequestBuilder.build_base_request(:delete, bucket, object, sub_resources: [{"tagging", nil}])

    with {:ok, _} <- Core.call(name, req), do: :ok
  end

  @doc """
  检查对象是否有标签

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 对象名称

  ## 返回值
  - boolean()

  ## 示例
      iex> LibOss.Core.Tagging.has_tags?(MyOss, "my-bucket", "my-object")
      true
  """
  @spec has_tags?(module(), Typespecs.bucket(), Typespecs.object()) :: boolean()
  def has_tags?(name, bucket, object) do
    case get_object_tagging(name, bucket, object) do
      {:ok, [_ | _]} -> true
      {:ok, []} -> false
      {:error, _} -> false
    end
  end

  @doc """
  获取对象标签数量

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 对象名称

  ## 返回值
  - {:ok, non_neg_integer()} | {:error, Exception.t()}

  ## 示例
      iex> LibOss.Core.Tagging.get_tag_count(MyOss, "my-bucket", "my-object")
      {:ok, 2}
  """
  @spec get_tag_count(module(), Typespecs.bucket(), Typespecs.object()) :: {:ok, non_neg_integer()} | err_t()
  def get_tag_count(name, bucket, object) do
    case get_object_tagging(name, bucket, object) do
      {:ok, tags} -> {:ok, length(tags)}
      {:error, _} = error -> error
    end
  end

  @doc """
  更新对象标签（合并现有标签）

  ## 参数
  - name: Agent进程名称
  - bucket: 存储桶名称
  - object: 对象名称
  - new_tags: 新的标签map或关键字列表

  ## 返回值
  - :ok | {:error, Exception.t()}

  该函数会先获取现有标签，然后与新标签合并后更新

  ## 示例
      iex> LibOss.Core.Tagging.update_object_tagging(MyOss, "my-bucket", "my-object", %{"version" => "1.0"})
      :ok
  """
  @spec update_object_tagging(module(), Typespecs.bucket(), Typespecs.object(), Typespecs.dict() | keyword()) ::
          :ok | err_t()
  def update_object_tagging(name, bucket, object, new_tags) do
    with {:ok, existing_tags} <- get_object_tagging(name, bucket, object) do
      # 将现有标签转换为map
      existing_map =
        Map.new(existing_tags, fn %{key: k, value: v} -> {k, v} end)

      # 合并标签
      merged_tags =
        new_tags
        |> normalize_tags()
        |> Map.merge(existing_map)

      put_object_tagging(name, bucket, object, merged_tags)
    end
  end

  @doc """
  验证标签是否符合OSS规范

  ## 参数
  - tags: 标签map或关键字列表

  ## 返回值
  - :ok | {:error, Exception.t()}

  ## 验证规则
  - 标签数量不超过10个
  - 标签键长度不超过128字符
  - 标签值长度不超过256字符
  - 标签键不能为空

  ## 示例
      iex> LibOss.Core.Tagging.validate_tags(%{"key1" => "value1"})
      :ok

      iex> LibOss.Core.Tagging.validate_tags(%{})
      :ok
  """
  @spec validate_tags(Typespecs.dict() | keyword()) :: :ok | {:error, Exception.t()}
  def validate_tags(tags) do
    normalized_tags = normalize_tags(tags)

    cond do
      map_size(normalized_tags) > @max_tags ->
        {:error,
         Exception.new(
           "too_many_tags: Maximum #{@max_tags} tags allowed, got #{map_size(normalized_tags)}",
           map_size(normalized_tags)
         )}

      Enum.any?(normalized_tags, fn {k, _v} -> String.length(to_string(k)) == 0 end) ->
        {:error, Exception.new("empty_tag_key: Tag key cannot be empty", normalized_tags)}

      Enum.any?(normalized_tags, fn {k, _v} -> String.length(to_string(k)) > @max_key_length end) ->
        {:error, Exception.new("tag_key_too_long: Tag key cannot exceed #{@max_key_length} characters", normalized_tags)}

      Enum.any?(normalized_tags, fn {_k, v} -> String.length(to_string(v)) > @max_value_length end) ->
        {:error,
         Exception.new("tag_value_too_long: Tag value cannot exceed #{@max_value_length} characters", normalized_tags)}

      true ->
        :ok
    end
  end

  @doc """
  获取标签限制信息

  ## 返回值
  - map()

  ## 示例
      iex> LibOss.Core.Tagging.tag_limits()
      %{
        max_tags: 10,
        max_key_length: 128,
        max_value_length: 256
      }
  """
  @spec tag_limits() :: map()
  def tag_limits do
    %{
      max_tags: @max_tags,
      max_key_length: @max_key_length,
      max_value_length: @max_value_length
    }
  end

  # 私有辅助函数

  defp normalize_tags(tags) when is_map(tags), do: tags

  defp normalize_tags(tags) when is_list(tags) do
    Map.new(tags)
  end

  defp build_tagging_xml(tags) do
    normalized_tags = normalize_tags(tags)

    tags_xml =
      Enum.map_join(normalized_tags, "", fn {k, v} ->
        "<Tag><Key>#{escape_xml(to_string(k))}</Key><Value>#{escape_xml(to_string(v))}</Value></Tag>"
      end)

    "<Tagging><TagSet>#{tags_xml}</TagSet></Tagging>"
  end

  defp escape_xml(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
