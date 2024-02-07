defmodule LibOss.Http do
  @moduledoc """
  behavior os http transport
  """
  alias LibOss.Exception
  alias LibOss.Typespecs

  @type t :: atom()

  @callback do_request(req :: LibOss.Http.Request.t()) ::
              {:ok, LibOss.Http.Response.t()} | {:error, Exception.t()}

  @callback start_link(opts :: keyword()) :: {:ok, pid()} | {:error, Exception.t()}

  defp delegate(impl, func, args), do: apply(impl, func, args)

  @spec do_request(t(), LibOss.Http.Request.t()) ::
          {:ok, LibOss.Http.Response.t()} | {:error, Exception.t()}
  def do_request(http, req), do: delegate(http, :do_request, [req])

  @spec start_link(t(), keyword()) :: {:ok, pid()} | {:error, Exception.t()}
  def start_link(http, opts), do: delegate(http, :start_link, [opts])

  defmacro __using__(_) do
    quote do
      @behaviour LibOss.Http

      def do_request(http, req), do: raise("Not implemented")

      def start_link(opts), do: raise("Not implemented")

      defoverridable(do_request: 2, start_link: 1)
    end
  end
end

defmodule LibOss.Http.Request do
  @moduledoc """
  http request
  """
  alias LibOss.Typespecs

  require Logger

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
    opts = NimbleOptions.validate!(opts, @http_request_schema)
    struct(__MODULE__, opts)
  end

  @spec url(t()) :: URI.t()
  def url(req) do
    query =
      if req.params in [nil, %{}] do
        nil
      else
        URI.encode_query(req.params)
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

defmodule LibOss.Http.Response do
  @moduledoc """
  http response
  """

  alias LibOss.Typespecs

  @http_response_schema [
    status_code: [
      type: :integer,
      doc: "http status code",
      default: 200
    ],
    headers: [
      type: {:list, :any},
      doc: "http headers",
      default: []
    ],
    body: [
      type: :string,
      doc: "http body",
      default: ""
    ]
  ]

  @type t :: %__MODULE__{
          status_code: Typespecs.http_status(),
          headers: Typespecs.headers(),
          body: Typespecs.body()
        }

  @type http_response_schema_t :: [unquote(NimbleOptions.option_typespec(@http_response_schema))]

  defstruct [:status_code, :headers, :body]

  @spec new(http_response_schema_t()) :: t()
  def new(opts) do
    opts = NimbleOptions.validate!(opts, @http_response_schema)
    struct(__MODULE__, opts)
  end
end

defmodule LibOss.Http.Default do
  @moduledoc """
  Implement LibOss.Http behavior with Finch
  """

  use LibOss.Http

  alias LibOss.Exception
  alias LibOss.Http

  require Logger

  @impl Http
  def do_request(req) do
    opts = opts(req.opts)

    with {debug?, opts} <- Keyword.pop(opts, :debug) do
      finch_req =
        Finch.build(
          req.method,
          Http.Request.url(req),
          req.headers,
          req.body,
          opts
        )

      if debug? do
        Logger.debug(%{
          "method" => req.method,
          "url" => req |> Http.Request.url() |> URI.to_string(),
          "params" => req.params,
          "headers" => req.headers,
          "body" => req.body,
          "opts" => opts,
          "req" => finch_req
        })
      end

      finch_req
      |> Finch.request(__MODULE__)
      |> case do
        {:ok, %Finch.Response{status: status, body: body, headers: headers}}
        when status in 200..299 ->
          {:ok, Http.Response.new(status_code: status, body: body, headers: headers)}

        {:ok, %Finch.Response{status: status, body: body}} ->
          {:error, Exception.new(body, %{status: status})}

        {:error, exception} ->
          Logger.error(%{"request" => req, "exception" => exception})
          {:error, Exception.new("request failed", exception)}
      end
    end
  end

  defp opts(nil), do: [receive_timeout: 5000]
  defp opts(options), do: Keyword.put_new(options, :receive_timeout, 5000)

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    }
  end

  @impl Http
  def start_link(_opts) do
    Finch.start_link(name: __MODULE__)
  end

  def start_link, do: start_link([])
end
