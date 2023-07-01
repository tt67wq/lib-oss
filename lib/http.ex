defmodule LibOss.Http do
  @moduledoc """
  behavior os http transport
  """
  alias LibOss.{Error}

  @type t :: struct()
  @type opts :: keyword()

  @callback new(opts()) :: t()
  @callback start_link(http: t()) :: GenServer.on_start()
  @callback do_request(
              http :: t(),
              req :: LibOss.Http.Request.t()
            ) ::
              {:ok, iodata()} | {:error, Error.t()}

  defp delegate(%module{} = http, func, args),
    do: apply(module, func, [http | args])

  def do_request(http, req), do: delegate(http, :do_request, [req])
end

defmodule LibOss.Http.Request do
  @moduledoc """
  http request
  """
  @type opts :: keyword()
  @type method :: Finch.Request.method()
  @type headers :: [{String.t(), String.t()}]
  @type body :: iodata() | nil
  @type params :: %{String.t() => bitstring()} | nil

  @type t :: %__MODULE__{
          scheme: String.t(),
          host: String.t(),
          method: method(),
          path: bitstring(),
          headers: headers(),
          body: body(),
          params: params(),
          opts: opts()
        }

  defstruct [
    :scheme,
    :host,
    :method,
    :path,
    :headers,
    :body,
    :params,
    :opts
  ]

  @spec url(t()) :: String.t()
  def url(req) do
    query =
      if is_nil(req.params) do
        ""
      else
        req.params |> URI.encode_query()
      end

    %URI{
      scheme: req.scheme,
      host: req.host,
      path: req.path,
      query: query
    }
    |> URI.to_string()
  end
end

defmodule LibOss.Http.Default do
  @moduledoc """
  Implement LibOss.Http behavior with Finch
  """

  alias LibOss.{Http, Error}

  @behaviour Http

  # types
  @type t :: %__MODULE__{
          name: GenServer.name()
        }

  defstruct name: __MODULE__

  @impl Http
  def new(opts \\ []) do
    opts = opts |> Keyword.put_new(:name, __MODULE__)
    struct(__MODULE__, opts)
  end

  @impl Http
  def do_request(http, req) do
    with opts <- Keyword.put_new(req.opts, :receive_timeout, 5000),
         req <-
           Finch.build(
             req.method,
             Http.Request.url(req),
             req.headers,
             req.body,
             opts
           ) do
      Finch.request(req, http.name)
      |> case do
        {:ok, %Finch.Response{status: status, body: body}} when status in 200..299 ->
          {:ok, body}

        {:ok, %Finch.Response{status: status, body: body}} ->
          {:error, Error.new("status: #{status}, body: #{body}")}

        {:error, exception} ->
          {:error, Error.new(inspect(exception))}
      end
    end
  end

  def child_spec(opts) do
    http = Keyword.fetch!(opts, :http)
    %{id: {__MODULE__, http.name}, start: {__MODULE__, :start_link, [opts]}}
  end

  @impl Http
  def start_link(opts) do
    {http, _opts} = Keyword.pop!(opts, :http)
    Finch.start_link(name: http.name)
  end
end
