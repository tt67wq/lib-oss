defmodule LibOss.Http.Request do
  @moduledoc """
  http request
  """
  require Logger

  alias LibOss.Typespecs

  @http_request_schema [
    scheme: [
      type: :string,
      doc: "http scheme",
      default: "https"
    ],
    host: [
      type: :string,
      doc: "http host",
      required: true
    ],
    port: [
      type: :integer,
      doc: "http port",
      default: 443
    ],
    method: [
      type: :any,
      doc: "http method",
      default: :get
    ],
    path: [
      type: :string,
      doc: "http path",
      default: "/"
    ],
    headers: [
      type: {:list, :any},
      doc: "http headers",
      default: []
    ],
    body: [
      type: :any,
      doc: "http body",
      default: nil
    ],
    params: [
      type: {:map, :string, :string},
      doc: "http query params",
      default: %{}
    ],
    opts: [
      type: :keyword_list,
      doc: "http opts",
      default: []
    ]
  ]

  @type http_request_schema_t :: [unquote(NimbleOptions.option_typespec(@http_request_schema))]

  @type t :: %__MODULE__{
          scheme: String.t(),
          host: String.t(),
          port: non_neg_integer(),
          method: Typespecs.method(),
          path: bitstring(),
          headers: Typespecs.headers(),
          body: Typespecs.body(),
          params: Typespecs.params(),
          opts: Typespecs.opts()
        }

  defstruct [
    :scheme,
    :host,
    :port,
    :method,
    :path,
    :headers,
    :body,
    :params,
    :opts
  ]

  @doc """
  create new http request instance

  ## Params
  #{NimbleOptions.docs(@http_request_schema)}
  """
  @spec new(http_request_schema_t()) :: t()
  def new(opts) do
    opts = opts |> NimbleOptions.validate!(@http_request_schema)
    struct(__MODULE__, opts)
  end

  @spec url(t()) :: URI.t()
  def url(req) do
    query =
      if req.params in [nil, %{}] do
        nil
      else
        req.params |> URI.encode_query()
      end

    %URI{
      scheme: req.scheme,
      host: req.host,
      path: req.path,
      query: query,
      port: req.port
    }
  end
end
