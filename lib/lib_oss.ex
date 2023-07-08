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
  def request(client, req) do
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

  # object

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
end
