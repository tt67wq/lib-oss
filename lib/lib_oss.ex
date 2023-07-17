defmodule LibOss do
  @moduledoc """
  Documentation for `LibOss`.
  """
  alias LibOss.{Error, Typespecs}

  @lib_oss_opts_schema [
    name: [
      type: :atom,
      doc: "LibOss name",
      default: __MODULE__
    ],
    access_key_id: [
      type: :string,
      doc: "OSS access key id",
      required: true
    ],
    access_key_secret: [
      type: :string,
      doc: "OSS access key secret",
      required: true
    ],
    endpoint: [
      type: :string,
      doc: "OSS endpoint",
      required: true
    ],
    http_impl: [
      type: :any,
      doc: "HTTP client implementation of `LibOss.Http`",
      default: LibOss.Http.Default.new()
    ]
  ]

  @callback_body """
  filename=${object}&size=${size}&mimeType=${mimeType}&height=${imageInfo.height}&width=${imageInfo.width}
  """

  @type t :: %__MODULE__{
          name: atom(),
          access_key_id: String.t(),
          access_key_secret: String.t(),
          endpoint: String.t(),
          http_impl: LibOss.Http.t()
        }
  @type lib_oss_opts_t :: [unquote(NimbleOptions.option_typespec(@lib_oss_opts_schema))]

  defstruct [:name, :access_key_id, :access_key_secret, :endpoint, :http_impl]

  @doc """
  create a new oss client instance

  ## Params
  #{NimbleOptions.docs(@lib_oss_opts_schema)}


  ## Examples

      LibOss.new(
        endpoint: "oss-cn-hangzhou.aliyuncs.com",
        access_key_id: "access_key_id",
        access_key_secret: "access_key_secret"
      )
  """
  @spec new(lib_oss_opts_t()) :: t()
  def new(opts) do
    opts = opts |> NimbleOptions.validate!(@lib_oss_opts_schema)
    struct(__MODULE__, opts)
  end

  def child_spec(opts) do
    client = Keyword.fetch!(opts, :client)
    %{id: {__MODULE__, client.name}, start: {__MODULE__, :start_link, [opts]}}
  end

  def start_link(client: client) do
    LibOss.Http.start_link(client.http_impl)
  end

  @spec request(t(), LibOss.Request.t()) :: {:ok, LibOss.Http.Response.t()} | {:error, Error.t()}
  defp request(client, req) do
    req =
      req
      |> LibOss.Request.build_headers(client)
      |> LibOss.Request.auth(client)

    host =
      case req.bucket do
        "" -> client.endpoint
        _ -> "#{req.bucket}.#{client.endpoint}"
      end

    object =
      req.sub_resources
      |> Stream.map(fn
        {k, nil} -> k
        {k, v} -> "#{k}=#{v}"
      end)
      |> Enum.join("&")
      |> case do
        "" -> req.object
        query_string -> "#{req.object}?#{query_string}"
      end

    # to http request
    [
      scheme: "https",
      port: 443,
      host: host,
      method: req.method,
      path: Path.join(["/", object]),
      headers: req.headers,
      body: req.body,
      params: req.params
    ]
    |> LibOss.Http.Request.new()
    |> then(&LibOss.Http.do_request(client.http_impl, &1))
  end

  #### object operations: https://help.aliyun.com/document_detail/31977.html

  @doc """
  function description
  通过Web端直传文件（Object）到OSS的签名生成

  Doc: https://help.aliyun.com/document_detail/31926.html

  ## Example

      iex> LibOss.get_token(cli, bucket, "/test/test.txt")
      {:ok, "{\"accessid\":\"LTAI1k8kxWG8JpUF\",\"callback\":\"=\",\"dir\":\"/test/test.txt\",\".........ePNPyWQo=\"}"}
  """
  @spec get_token(
          cli :: t(),
          bucket :: Typespecs.bucket(),
          object :: Typespecs.object(),
          expire_sec :: non_neg_integer(),
          callback :: String.t()
        ) :: {:ok, String.t()}

  def get_token(cli, bucket, object, expire_sec \\ 3600, callback \\ "")

  def get_token(cli, bucket, object, expire_sec, callback) do
    expire =
      DateTime.now!("Etc/UTC")
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
      policy
      |> LibOss.Utils.do_sign(cli.access_key_secret)

    base64_callback_body =
      %{
        "callbackUrl" => callback,
        "callbackBody" => @callback_body,
        "callbackBodyType" => "application/x-www-form-urlencoded"
      }
      |> Jason.encode!()
      |> String.trim()
      |> Base.encode64()

    %{
      "accessid" => cli.access_key_id,
      "host" => "https://#{bucket}.#{cli.endpoint}",
      "policy" => policy,
      "signature" => signature,
      "expire" => DateTime.to_unix(expire),
      "dir" => object,
      "callback" => base64_callback_body
    }
    |> Jason.encode()
  end

  @doc """
  调用PutObject接口上传文件（Object）。

  Doc: https://help.aliyun.com/document_detail/31978.html

  ## Examples

      LibOss.put_object(cli, bucket, "/test/test.txt", "hello world")
  """
  @spec put_object(t(), Typespecs.bucket(), Typespecs.object(), iodata()) ::
          {:ok, any()} | {:error, Error.t()}
  def put_object(client, bucket, object, data) do
    req =
      LibOss.Request.new(
        method: :put,
        object: object,
        resource: Path.join(["/", bucket, object]),
        bucket: bucket,
        body: data
      )

    request(client, req)
  end

  @doc """
  调用CopyObject接口拷贝同一地域下相同或不同存储空间（Bucket）之间的文件（Object）。

  Doc: https://help.aliyun.com/document_detail/31979.html

  ## Examples

      LibOss.copy_object(cli, target_bucket, "object_copy.txt", source_bucket, "object.txt")
  """
  @spec copy_object(
          t(),
          Typespecs.bucket(),
          Typespecs.object(),
          Typespecs.bucket(),
          Typespecs.object()
        ) :: {:ok, any()} | {:error, Error.t()}
  def copy_object(client, bucket, object, source_bucket, source_object) do
    req =
      LibOss.Request.new(
        method: :put,
        object: object,
        resource: Path.join(["/", bucket, object]),
        bucket: bucket,
        headers: [{"x-oss-copy-source", Path.join(["/", source_bucket, source_object])}]
      )

    request(client, req)
  end

  @doc """
  GetObject接口用于获取某个文件（Object）。此操作需要对此Object具有读权限。

  Doc: https://help.aliyun.com/document_detail/31980.html

  req_headers的具体参数可参考文档中”请求头“部分说明

  ## Examples

      LibOss.get_object(cli, bucket, "/test/test.txt")
  """
  @spec get_object(t(), Typespecs.bucket(), String.t(), list()) ::
          {:ok, iodata()} | {:error, Error.t()}
  def get_object(client, bucket, object, req_headers \\ []) do
    req =
      LibOss.Request.new(
        method: :get,
        object: object,
        resource: Path.join(["/", bucket, object]),
        bucket: bucket,
        headers: req_headers
      )

    request(client, req)
    |> case do
      {:ok, %{body: body}} -> {:ok, body}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  调用DeleteObject删除某个文件（Object）。

  Doc: https://help.aliyun.com/document_detail/31982.html

  ## Examples

      {:ok, _} = LibOss.delete_object(cli, bucket, "/test/test.txt")
  """
  @spec delete_object(t(), Typespecs.bucket(), String.t()) :: {:ok, any()} | {:error, Error.t()}
  def delete_object(client, bucket, object) do
    req =
      LibOss.Request.new(
        method: :delete,
        object: object,
        resource: Path.join(["/", bucket, object]),
        bucket: bucket
      )

    request(client, req)
  end

  #### multipart operations: https://help.aliyun.com/document_detail/155825.html

  @doc """
  使用Multipart Upload模式传输数据前，您必须先调用InitiateMultipartUpload接口来通知OSS初始化一个Multipart Upload事件。

  Doc: https://help.aliyun.com/document_detail/31992.html

  ## Examples

      iex> init_multi_uploads(client, bucket, "test.txt")
      {:ok, "upload_id"}
  """
  @spec init_multi_upload(
          t(),
          Typespecs.bucket(),
          String.t(),
          list()
        ) :: {:ok, String.t()} | {:error, Error.t()}
  def init_multi_upload(client, bucket, object, req_headers \\ []) do
    req =
      LibOss.Request.new(
        method: :post,
        object: object,
        resource: Path.join(["/", bucket, object]),
        bucket: bucket,
        headers: req_headers,
        sub_resources: [{"uploads", nil}]
      )

    request(client, req)
    |> case do
      {:ok, %{body: body}} ->
        # %{
        #   "InitiateMultipartUploadResult" => %{
        #     "Bucket" => "...",
        #     "Key" => "test/test.txt",
        #     "UploadId" => "uploadid"
        #   }
        # }
        body
        |> XmlToMap.naive_map()
        |> case do
          %{"InitiateMultipartUploadResult" => %{"UploadId" => upload_id}} ->
            {:ok, upload_id}

          _ ->
            Error.new("invalid response body: #{inspect(body)}")
        end

      err ->
        err
    end
  end

  @doc """
  初始化一个MultipartUpload后，调用UploadPart接口根据指定的Object名和uploadId来分块（Part）上传数据。

  Doc: https://help.aliyun.com/document_detail/31993.html

  ## Examples

      iex> upload_part(client, bucket, "test.txt", "upload_id", 1, "hello world")
      {:ok, "etag"}
  """
  @spec upload_part(
          t(),
          Typespecs.bucket(),
          String.t(),
          String.t(),
          non_neg_integer(),
          binary()
        ) :: {:ok, bitstring()} | {:error, Error.t()}
  def upload_part(client, bucket, object, upload_id, partNumber, data) do
    req =
      LibOss.Request.new(
        method: :put,
        object: object,
        resource: Path.join(["/", bucket, object]),
        sub_resources: [{"partNumber", "#{partNumber}"}, {"uploadId", upload_id}],
        bucket: bucket,
        body: data
      )

    request(client, req)
    |> case do
      {:ok, %{headers: headers}} ->
        headers
        |> Enum.find(fn {k, _} -> k == "etag" end)
        |> (fn
              {_, v} -> {:ok, v}
              nil -> Error.new("etag not found")
            end).()
    end
  end

  @doc """
  所有数据Part都上传完成后，您必须调用CompleteMultipartUpload接口来完成整个文件的分片上传。

  ## Examples

      iex> {:ok, etag1} = upload_part(client, bucket, "test.txt", "upload_id", 1, part1)
      iex> {:ok, etag2} = upload_part(client, bucket, "test.txt", "upload_id", 2, part2)
      iex> {:ok, etag3} = upload_part(client, bucket, "test.txt", "upload_id", 3, part3)
      iex> complete_multipart_upload(client, bucket, "test.txt", "upload_id", [{1, etag1}, {2, etag2}, {3, etag3}])
      {:ok, _}
  """
  @spec complete_multipart_upload(
          t(),
          Typespecs.bucket(),
          String.t(),
          String.t(),
          [{non_neg_integer(), bitstring()}]
        ) :: {:ok, any()} | {:error, Error.t()}
  def complete_multipart_upload(client, bucket, object, upload_id, parts) do
    # format parts
    body =
      parts
      |> Enum.map(fn {partNumber, etag} ->
        "<Part><PartNumber>#{partNumber}</PartNumber><ETag>#{etag}</ETag></Part>"
      end)
      |> Enum.join("")

    req =
      LibOss.Request.new(
        method: :post,
        object: object,
        resource: Path.join(["/", bucket, object]),
        sub_resources: [{"uploadId", upload_id}],
        bucket: bucket,
        body: "<CompleteMultipartUpload>#{body}</CompleteMultipartUpload>"
      )

    request(client, req)
  end

  #### bucket operations: https://help.aliyun.com/document_detail/31959.html

  @doc """
  调用PutBucket接口创建存储空间（Bucket）。

  Doc: https://help.aliyun.com/document_detail/31959.html

  ## Examples

      {:ok, _} = LibOss.put_bucket(cli, your-new-bucket)
  """
  @spec put_bucket(t(), Typespecs.bucket(), bitstring(), bitstring()) ::
          {:ok, any()} | {:error, Error.t()}
  def put_bucket(client, bucket, storage_class \\ "Standard", data_redundancy_type \\ "LRS")

  def put_bucket(client, bucket, storage_class, data_redundancy_type) do
    body = """
    <?xml version="1.0" encoding="UTF-8"?>
    <CreateBucketConfiguration>
        <StorageClass>#{storage_class}</StorageClass>
        <DataRedundancyType>#{data_redundancy_type}</DataRedundancyType>
    </CreateBucketConfiguration>
    """

    LibOss.Request.new(
      method: :put,
      bucket: bucket,
      resource: "/" <> bucket <> "/",
      body: body
    )
    |> then(&request(client, &1))
  end

  @doc """
  调用DeleteBucket删除某个存储空间（Bucket）。

  Doc: https://help.aliyun.com/document_detail/31973.html

  ## Examples

      {:ok, _} = LibOss.delete_bucket(cli, to-delete-bucket)
  """
  @spec delete_bucket(t(), Typespecs.bucket()) :: {:ok, any()} | {:error, Error.t()}
  def delete_bucket(client, bucket) do
    LibOss.Request.new(
      method: :delete,
      bucket: bucket,
      resource: "/" <> bucket <> "/"
    )
    |> then(&request(client, &1))
  end

  @doc """
  GetBucket (ListObjects)接口用于列举存储空间（Bucket）中所有文件（Object）的信息。

  Doc: https://help.aliyun.com/document_detail/31965.html

  其中query_params具体细节参考上面链接中`请求参数`部分

  ## Examples

      iex> LibOss.get_bucket(cli, bucket, %{"prefix" => "test/test"})
      {:ok, [
        %{
         "ETag" => "\"A5D2B2E40EF7EBA1C788697D31C27A78-3\"",
         "Key" => "test/test.txt",
         "LastModified" => "2023-07-09T14:41:08.000Z",
         "Owner" => %{
           "DisplayName" => "1074124462684153",
           "ID" => "1074124462684153"
         },
         "Size" => "409608",
         "StorageClass" => "Standard",
         "Type" => "Multipart"
       },
       %{
         "ETag" => "\"5EB63BBBE01EEED093CB22BB8F5ACDC3\"",
         "Key" => "test/test_1.txt",
         "LastModified" => "2023-07-09T14:41:08.000Z",
         "Owner" => %{
           "DisplayName" => "1074124462684153",
           "ID" => "1074124462684153"
         },
         "Size" => "11",
         "StorageClass" => "Standard",
         "Type" => "Normal"
       }
      ]}
  """
  @spec get_bucket(t(), Typespecs.bucket(), %{String.t() => String.t()}) ::
          {:ok, [any()]} | {:error, Error.t()}
  def get_bucket(client, bucket, query_params) do
    LibOss.Request.new(
      method: :get,
      bucket: bucket,
      resource: "/" <> bucket <> "/",
      params: query_params
    )
    |> then(&request(client, &1))
    |> case do
      {:ok, %{body: body}} ->
        body
        |> XmlToMap.naive_map()
        |> case do
          %{"ListBucketResult" => %{"Contents" => ret}} -> {:ok, ret}
          _ -> Error.new("invalid response body: #{inspect(body)}")
        end

      err ->
        err
    end
  end
end
