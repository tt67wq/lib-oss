defmodule LibOss.Core do
  @moduledoc false

  use Agent

  alias LibOss.Exception
  alias LibOss.Model.Config
  alias LibOss.Model.Http
  alias LibOss.Model.Request
  alias LibOss.Typespecs

  @type err_t() :: {:error, Exception.t()}

  @http_impl LibOss.Http.Finch
  @callback_body """
  filename=${object}&size=${size}&mimeType=${mimeType}&height=${imageInfo.height}&width=${imageInfo.width}
  """

  def start_link({name, http_name, config}) do
    config =
      config
      |> Config.validate!()
      |> Keyword.put(:http_name, http_name)

    Agent.start_link(fn -> config end, name: name)
  end

  def get(name) do
    Agent.get(name, & &1)
  end

  defp call_http(name, req) do
    apply(@http_impl, :do_request, [name, req])
  end

  @spec make_request(Config.t(), Request.t()) :: Http.Request.t()
  defp make_request(config, req) do
    req =
      req
      |> Request.build_headers(config)
      |> Request.auth(config)

    endpoint = config[:endpoint]
    %Request{host: host, bucket: bucket, sub_resources: sub_resources, object: object, debug: debug} = req

    host =
      if host != "" do
        host
      else
        case bucket do
          "" -> endpoint
          _ -> "#{bucket}.#{endpoint}"
        end
      end

    object =
      sub_resources
      |> Enum.map_join("&", fn
        {k, nil} -> k
        {k, v} -> "#{k}=#{v}"
      end)
      |> case do
        "" -> object
        query_string -> "#{object}?#{query_string}"
      end

    # to http request
    %Http.Request{
      scheme: "https",
      port: 443,
      host: host,
      method: req.method,
      path: Path.join(["/", object]),
      headers: req.headers,
      body: req.body,
      params: req.params,
      opts: [debug: debug]
    }
  end

  @spec call(Config.t(), Request.t()) :: {:ok, Http.Response.t()} | err_t()
  defp call(config, req) do
    http_req = make_request(config, req)
    call_http(config[:http_name], http_req)
  end

  @spec get_token(module(), Typespecs.bucket(), Typespecs.object(), non_neg_integer(), binary()) ::
          {:ok, binary()} | err_t()
  def get_token(name, bucket, object, expire_sec \\ 3600, callback \\ "")

  def get_token(name, bucket, object, expire_sec, callback) do
    config = get(name)

    expire =
      "Etc/UTC"
      |> DateTime.now!()
      |> DateTime.add(expire_sec, :second)

    policy =
      %{
        "expiration" => DateTime.to_iso8601(expire),
        "conditions" => [["starts-with", "$key", object]]
      }
      |> Jason.encode!()
      |> String.trim()
      |> Base.encode64()

    signature =
      LibOss.Utils.do_sign(policy, config[:access_key_secret])

    base64_callback_body =
      %{
        "callbackUrl" => callback,
        "callbackBody" => @callback_body,
        "callbackBodyType" => "application/x-www-form-urlencoded"
      }
      |> Jason.encode!()
      |> String.trim()
      |> Base.encode64()

    Jason.encode(%{
      "accessid" => config[:access_key_id],
      "host" => "https://#{bucket}.#{config[:endpoint]}",
      "policy" => policy,
      "signature" => signature,
      "expire" => DateTime.to_unix(expire),
      "dir" => object,
      "callback" => base64_callback_body
    })
  end

  # ------------------- object ------------------

  @spec put_object(module(), Typespecs.bucket(), Typespecs.object(), iodata(), Typespecs.headers()) :: :ok | err_t()
  def put_object(name, bucket, object, data, headers \\ []) do
    config = get(name)

    req =
      %Request{
        method: :put,
        object: object,
        resource: Path.join(["/", bucket, object]),
        bucket: bucket,
        body: data,
        headers: headers
      }

    with {:ok, _} <- call(config, req), do: :ok
  end

  @spec copy_object(
          module(),
          Typespecs.bucket(),
          Typespecs.object(),
          Typespecs.bucket(),
          Typespecs.object(),
          Typespecs.headers()
        ) :: :ok | err_t()
  def copy_object(name, bucket, object, source_bucket, source_object, headers \\ []) do
    config = get(name)

    req = %Request{
      method: :put,
      object: object,
      resource: Path.join(["/", bucket, object]),
      bucket: bucket,
      headers: [{"x-oss-copy-source", Path.join(["/", source_bucket, source_object])} | headers]
    }

    with {:ok, _} <- call(config, req), do: :ok
  end

  @spec get_object(module(), Typespecs.bucket(), Typespecs.object(), Typespecs.headers()) :: {:ok, binary()} | err_t()
  def get_object(name, bucket, object, req_headers \\ []) do
    config = get(name)

    req = %Request{
      method: :get,
      object: object,
      resource: Path.join(["/", bucket, object]),
      bucket: bucket,
      headers: req_headers
    }

    with {:ok, %Http.Response{body: body}} <- call(config, req), do: {:ok, body}
  end

  @spec delete_object(module(), Typespecs.bucket(), Typespecs.object()) :: :ok | err_t()
  def delete_object(name, bucket, object) do
    config = get(name)

    req = %Request{
      method: :delete,
      object: object,
      resource: Path.join(["/", bucket, object]),
      bucket: bucket
    }

    with {:ok, _} <- call(config, req), do: :ok
  end

  @spec delete_multiple_objects(module(), Typespecs.bucket(), [Typespecs.object()]) :: :ok | err_t()
  def delete_multiple_objects(name, bucket, objects) do
    config = get(name)

    body =
      Enum.map_join(objects, "", fn object -> "<Object><Key>#{object}</Key></Object>" end)

    req = %Request{
      method: :post,
      object: "",
      resource: Path.join(["/", bucket]) <> "/",
      sub_resources: [{"delete", nil}],
      bucket: bucket,
      body: "<Delete><Quiet>true</Quiet>#{body}</Delete>"
    }

    with {:ok, _} <- call(config, req), do: :ok
  end

  @spec append_object(module(), Typespecs.bucket(), Typespecs.object(), non_neg_integer(), binary(), Typespecs.headers()) ::
          :ok | err_t()
  def append_object(name, bucket, object, since, data, headers \\ []) do
    config = get(name)

    req = %Request{
      method: :post,
      object: object,
      resource: Path.join(["/", bucket, object]),
      sub_resources: [{"append", nil}, {"position", "#{since}"}],
      bucket: bucket,
      headers: headers,
      body: data
    }

    with {:ok, _} <- call(config, req), do: :ok
  end

  @spec head_object(module(), Typespecs.bucket(), Typespecs.object(), Typespecs.headers()) ::
          {:ok, Typespecs.dict()} | err_t()
  def head_object(name, bucket, object, headers \\ []) do
    config = get(name)

    req = %Request{
      method: :head,
      object: object,
      resource: Path.join(["/", bucket, object]),
      bucket: bucket,
      headers: headers
    }

    with {:ok, %Http.Response{headers: headers}} <- call(config, req) do
      {:ok, Map.new(headers)}
    end
  end

  @spec get_object_meta(module(), Typespecs.bucket(), Typespecs.object()) ::
          {:ok, Typespecs.dict()} | err_t()
  def get_object_meta(name, bucket, object) do
    config = get(name)

    req = %Request{
      method: :head,
      object: object,
      resource: Path.join(["/", bucket, object]),
      bucket: bucket
    }

    with {:ok, %Http.Response{headers: headers}} <- call(config, req) do
      {:ok, Map.new(headers)}
    end
  end

  @spec put_object_acl(module(), Typespecs.bucket(), Typespecs.object(), Typespecs.acl()) :: :ok | err_t()
  def put_object_acl(name, bucket, object, acl) do
    config = get(name)

    unless acl in ["private", "public-read", "public-read-write", "default"] do
      raise Exception.new("invalid acl", acl)
    end

    req = %Request{
      method: :put,
      object: object,
      resource: Path.join(["/", bucket, object]),
      bucket: bucket,
      sub_resources: [{"acl", nil}],
      headers: [{"x-oss-object-acl", acl}]
    }

    with {:ok, _} <- call(config, req), do: :ok
  end

  @spec get_object_acl(module(), Typespecs.bucket(), Typespecs.object()) ::
          {:ok, Typespecs.acl()} | err_t()
  def get_object_acl(name, bucket, object) do
    config = get(name)

    req = %Request{
      method: :get,
      object: object,
      resource: Path.join(["/", bucket, object]),
      bucket: bucket,
      sub_resources: [{"acl", nil}]
    }

    with {:ok, %Http.Response{body: body}} <- call(config, req) do
      body
      |> XmlToMap.naive_map()
      |> case do
        %{"AccessControlPolicy" => %{"AccessControlList" => %{"Grant" => grant}}} ->
          {:ok, grant}

        _ ->
          {:error, Exception.new("invalid response", body)}
      end
    end
  end

  @spec put_symlink(module(), Typespecs.bucket(), Typespecs.object(), String.t(), Typespecs.headers()) ::
          :ok | err_t()
  def put_symlink(name, bucket, object, target_object, headers \\ []) do
    config = get(name)

    req = %Request{
      method: :put,
      object: object,
      resource: Path.join(["/", bucket, object]),
      sub_resources: [{"symlink", nil}],
      bucket: bucket,
      headers: [{"x-oss-symlink-target", target_object} | headers]
    }

    with {:ok, _} <- call(config, req), do: :ok
  end

  @spec get_symlink(module(), Typespecs.bucket(), Typespecs.object()) ::
          {:ok, binary()} | err_t()
  def get_symlink(name, bucket, object) do
    config = get(name)

    req = %Request{
      method: :get,
      object: object,
      resource: Path.join(["/", bucket, object]),
      bucket: bucket,
      sub_resources: [{"symlink", nil}]
    }

    with {:ok, %Http.Response{headers: headers}} <- call(config, req) do
      headers
      |> Enum.find(fn {k, _} -> k == "x-oss-symlink-target" end)
      |> then(fn
        {_, v} -> {:ok, URI.decode(v)}
        nil -> {:error, Exception.new("x-oss-symlink-target not found")}
      end)
    end
  end

  @spec put_object_tagging(module(), Typespecs.bucket(), Typespecs.object(), Typespecs.dict()) ::
          :ok | err_t()
  def put_object_tagging(name, bucket, object, tags) do
    config = get(name)

    tagging =
      Enum.map(tags, fn {k, v} -> "<Tag><Key>#{k}</Key><Value>#{v}</Value></Tag>" end)

    req = %Request{
      method: :put,
      object: object,
      resource: Path.join(["/", bucket, object]),
      sub_resources: [{"tagging", nil}],
      bucket: bucket,
      body: "<Tagging><TagSet>#{tagging}</TagSet></Tagging>"
    }

    with {:ok, _} <- call(config, req), do: :ok
  end

  @spec get_object_tagging(module(), Typespecs.bucket(), Typespecs.object()) ::
          {:ok, Typespecs.dict()} | err_t()
  def get_object_tagging(name, bucket, object) do
    config = get(name)

    req = %Request{
      method: :get,
      object: object,
      resource: Path.join(["/", bucket, object]),
      bucket: bucket,
      sub_resources: [{"tagging", nil}]
    }

    with {:ok, %Http.Response{body: body}} <- call(config, req) do
      body
      |> XmlToMap.naive_map()
      |> case do
        %{"Tagging" => %{"TagSet" => %{"Tag" => tags}}} ->
          {:ok, tags}

        _ ->
          {:error, Exception.new("invalid response", body)}
      end
    end
  end

  @spec delete_object_tagging(module(), Typespecs.bucket(), Typespecs.object()) ::
          :ok | err_t()
  def delete_object_tagging(name, bucket, object) do
    config = get(name)

    req = %Request{
      method: :delete,
      object: object,
      resource: Path.join(["/", bucket, object]),
      bucket: bucket,
      sub_resources: [{"tagging", nil}]
    }

    with {:ok, _} <- call(config, req), do: :ok
  end

  # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  multipart operations  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # https://help.aliyun.com/document_detail/155825.html
  # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  multipart operations  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  @spec init_multi_upload(
          module(),
          Typespecs.bucket(),
          Typespecs.object(),
          Typespecs.headers()
        ) ::
          {:ok, Typespecs.upload_id()} | err_t()
  def init_multi_upload(name, bucket, object, req_headers \\ []) do
    config = get(name)

    req = %Request{
      method: :post,
      object: object,
      resource: Path.join(["/", bucket, object]),
      bucket: bucket,
      headers: req_headers,
      sub_resources: [{"uploads", nil}]
    }

    with {:ok, %Http.Response{body: body}} <- call(config, req) do
      body
      |> XmlToMap.naive_map()
      |> case do
        %{"InitiateMultipartUploadResult" => %{"UploadId" => upload_id}} ->
          {:ok, upload_id}

        _ ->
          {:error, Exception.new("invalid response", body)}
      end
    end
  end

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
    config = get(name)

    req = %Request{
      method: :put,
      object: object,
      resource: Path.join(["/", bucket, object]),
      sub_resources: [{"partNumber", "#{part_number}"}, {"uploadId", upload_id}],
      bucket: bucket,
      body: data
    }

    with {:ok, %Http.Response{headers: headers}} <- call(config, req) do
      headers
      |> Enum.find(fn {k, _} -> k == "etag" end)
      |> then(fn
        {_, v} -> {:ok, v}
        nil -> {:error, Exception.new("etag not found")}
      end)
    end
  end

  @spec list_multipart_uploads(
          module(),
          Typespecs.bucket(),
          Typespecs.params()
        ) ::
          {:ok, list(Typespecs.dict())} | err_t()
  def list_multipart_uploads(name, bucket, query_params) do
    config = get(name)

    req = %Request{
      method: :get,
      object: "?uploads",
      resource: Path.join(["/", bucket]) <> "/",
      bucket: bucket,
      params: query_params
    }

    with {:ok, %Http.Response{body: body}} <- call(config, req) do
      body
      |> XmlToMap.naive_map()
      |> case do
        # NOTE
        %{"ListBucketResult" => %{"Contents" => ret}} ->
          {:ok, ret}

        _ ->
          {:error, Exception.new("invalid response", body)}
      end
    end
  end

  @spec complete_multipart_upload(
          module(),
          Typespecs.bucket(),
          Typespecs.object(),
          Typespecs.upload_id(),
          [{Typespecs.part_num(), Typespecs.etag()}],
          Typespecs.headers()
        ) :: :ok | err_t()
  def complete_multipart_upload(name, bucket, object, upload_id, parts, headers \\ []) do
    config = get(name)

    body =
      Enum.map_join(parts, "", fn {part_number, etag} ->
        "<Part><PartNumber>#{part_number}</PartNumber><ETag>#{etag}</ETag></Part>"
      end)

    req = %Request{
      method: :post,
      object: object,
      resource: Path.join(["/", bucket, object]),
      sub_resources: [{"uploadId", upload_id}],
      bucket: bucket,
      body: "<CompleteMultipartUpload>#{body}</CompleteMultipartUpload>",
      headers: headers
    }

    with {:ok, _} <- call(config, req), do: :ok
  end

  @spec abort_multipart_upload(
          module(),
          Typespecs.bucket(),
          Typespecs.object(),
          Typespecs.upload_id()
        ) :: :ok | err_t()
  def abort_multipart_upload(name, bucket, object, upload_id) do
    config = get(name)

    req = %Request{
      method: :delete,
      object: object,
      resource: Path.join(["/", bucket, object]),
      sub_resources: [{"uploadId", upload_id}],
      bucket: bucket
    }

    with {:ok, _} <- call(config, req), do: :ok
  end

  @spec list_parts(
          module(),
          Typespecs.bucket(),
          Typespecs.object(),
          Typespecs.upload_id(),
          Typespecs.params()
        ) ::
          {:ok, list(Typespecs.dict())} | err_t()
  def list_parts(name, bucket, object, upload_id, query_params \\ %{}) do
    config = get(name)

    req = %Request{
      method: :get,
      object: object,
      resource: Path.join(["/", bucket, object]),
      sub_resources: [{"uploadId", upload_id}],
      bucket: bucket,
      params: query_params
    }

    with {:ok, %Http.Response{body: body}} <- call(config, req) do
      {:ok, XmlToMap.naive_map(body)}
    end
  end

  # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ bucket parts  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  @spec put_bucket(module(), Typespecs.bucket(), String.t(), String.t(), Typespecs.headers()) :: :ok | err_t()
  def put_bucket(name, bucket, storage_class \\ "Standard", data_redundancy_type \\ "LRS", headers \\ [])

  def put_bucket(name, bucket, storage_class, data_redundancy_type, headers) do
    config = get(name)

    body = """
    <?xml version="1.0" encoding="UTF-8"?>
    <CreateBucketConfiguration>
        <StorageClass>#{storage_class}</StorageClass>
        <DataRedundancyType>#{data_redundancy_type}</DataRedundancyType>
    </CreateBucketConfiguration>
    """

    req = %Request{
      method: :put,
      bucket: bucket,
      resource: "/" <> bucket <> "/",
      body: body,
      headers: headers
    }

    with {:ok, _} <- call(config, req), do: :ok
  end

  @spec delete_bucket(module(), Typespecs.bucket()) :: :ok | err_t()
  def delete_bucket(name, bucket) do
    config = get(name)

    req = %Request{
      method: :delete,
      resource: "/" <> bucket <> "/",
      bucket: bucket
    }

    with {:ok, _} <- call(config, req), do: :ok
  end

  @spec get_bucket(module(), Typespecs.bucket(), Typespecs.params()) ::
          {:ok, list(Typespecs.dict())} | err_t()
  def get_bucket(name, bucket, query_params) do
    config = get(name)

    req = %Request{
      method: :get,
      bucket: bucket,
      resource: "/" <> bucket <> "/",
      params: query_params
    }

    with {:ok, %Http.Response{body: body}} <- call(config, req) do
      body
      |> XmlToMap.naive_map()
      |> case do
        %{"ListBucketResult" => ret} ->
          {:ok, Map.get(ret, "Contents", [])}

        _ ->
          {:error, Exception.new("invalid response", body)}
      end
    end
  end

  @spec list_object_v2(module(), Typespecs.bucket(), Typespecs.params()) ::
          {:ok, list(Typespecs.dict())} | err_t()
  def list_object_v2(name, bucket, query_params) do
    config = get(name)

    req = %Request{
      method: :get,
      bucket: bucket,
      resource: "/" <> bucket <> "/",
      params: Map.put(query_params, "list-type", "2")
    }

    with {:ok, %Http.Response{body: body}} <- call(config, req) do
      body
      |> XmlToMap.naive_map()
      |> case do
        %{"ListBucketResult" => ret} -> {:ok, Map.get(ret, "Contents", [])}
        _ -> {:error, Exception.new("invalid response", body)}
      end
    end
  end

  @spec get_bucket_info(module(), Typespecs.bucket()) :: {:ok, Typespecs.dict()} | err_t()
  def get_bucket_info(name, bucket) do
    config = get(name)

    req = %Request{
      method: :get,
      bucket: bucket,
      resource: "/" <> bucket <> "/",
      sub_resources: [{"bucketInfo", nil}]
    }

    with {:ok, %Http.Response{body: body}} <- call(config, req) do
      body
      |> XmlToMap.naive_map()
      |> case do
        %{"BucketInfo" => ret} -> {:ok, ret}
        _ -> {:error, Exception.new("invalid response", body)}
      end
    end
  end

  @spec get_bucket_location(module(), Typespecs.bucket()) :: {:ok, String.t()} | err_t()
  def get_bucket_location(name, bucket) do
    config = get(name)

    req = %Request{
      method: :get,
      bucket: bucket,
      resource: "/" <> bucket <> "/",
      sub_resources: [{"location", nil}]
    }

    with {:ok, %Http.Response{body: body}} <- call(config, req) do
      body
      |> XmlToMap.naive_map()
      |> case do
        %{"LocationConstraint" => ret} -> {:ok, ret}
        _ -> {:error, Exception.new("invalid response", body)}
      end
    end
  end

  @spec get_bucket_stat(module(), Typespecs.bucket()) :: {:ok, Typespecs.dict()} | err_t()
  def get_bucket_stat(name, bucket) do
    config = get(name)

    req = %Request{
      method: :get,
      bucket: bucket,
      resource: "/" <> bucket <> "/",
      sub_resources: [{"stat", nil}]
    }

    with {:ok, %Http.Response{body: body}} <- call(config, req) do
      body
      |> XmlToMap.naive_map()
      |> case do
        %{"BucketStat" => ret} -> {:ok, ret}
        _ -> {:error, Exception.new("invalid response", body)}
      end
    end
  end

  @spec put_bucket_acl(module(), Typespecs.bucket(), Typespecs.acl()) :: :ok | err_t()
  def put_bucket_acl(name, bucket, acl) do
    unless acl in ["private", "public-read", "public-read-write"] do
      raise ArgumentError, "invalid acl: #{acl}"
    end

    config = get(name)

    req = %Request{
      method: :put,
      bucket: bucket,
      resource: "/" <> bucket <> "/",
      sub_resources: [{"acl", nil}],
      headers: [{"x-oss-acl", acl}]
    }

    with {:ok, _} <- call(config, req), do: :ok
  end

  @spec get_bucket_acl(module(), Typespecs.bucket()) :: {:ok, Typespecs.dict()} | err_t()
  def get_bucket_acl(name, bucket) do
    config = get(name)

    req = %Request{
      method: :get,
      bucket: bucket,
      resource: "/" <> bucket <> "/",
      sub_resources: [{"acl", nil}]
    }

    with {:ok, %Http.Response{body: body}} <- call(config, req) do
      body
      |> XmlToMap.naive_map()
      |> case do
        %{"AccessControlPolicy" => ret} -> {:ok, ret}
        _ -> {:error, Exception.new("invalid response", body)}
      end
    end
  end
end
