defmodule LibOss do
  @moduledoc """
  Documentation for `LibOss`.
  """
  alias LibOss.{Error}

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
  @type lib_oss_opts_t :: keyword(unquote(NimbleOptions.option_typespec(@lib_oss_opts_schema)))
  @type bucket :: bitstring()

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

  @spec request(t(), LibOss.Request.t()) :: {:ok, any()} | {:error, Error.t()}
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

    # to http request
    [
      scheme: "https",
      port: 443,
      host: host,
      method: req.method,
      path: Path.join(["/", req.object]),
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
          t(),
          String.t(),
          String.t(),
          non_neg_integer(),
          String.t()
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
  @spec put_object(t(), bucket(), String.t(), binary()) :: {:ok, any()} | {:error, Error.t()}
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
  GetObject接口用于获取某个文件（Object）。此操作需要对此Object具有读权限。

  Doc: https://help.aliyun.com/document_detail/31980.html

  req_headers的具体参数可参考文档中”请求头“部分说明

  ## Examples

      LibOss.get_object(cli, bucket, "/test/test.txt")
  """
  @spec get_object(t(), bucket(), String.t(), list()) :: {:ok, iodata()} | {:error, Error.t()}
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
  end

  @doc """
  调用DeleteObject删除某个文件（Object）。

  Doc: https://help.aliyun.com/document_detail/31982.html

  ## Examples

      {:ok, _} = LibOss.delete_object(cli, bucket, "/test/test.txt")
  """
  @spec delete_object(t(), bucket(), String.t()) :: {:ok, any()} | {:error, Error.t()}
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
end
