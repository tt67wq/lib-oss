defmodule LibOss.Http do
  @moduledoc """
  behavior os http transport
  """
  alias LibOss.{Error}

  @type t :: struct()
  @type opts :: keyword()
  @type method :: Finch.Request.method()
  @type path :: bitstring()
  @type headers :: [%{String.t() => String.t()}]
  @type body :: iodata() | nil
  @type params :: %{String.t() => any()} | nil

  @callback new(opts()) :: t()
  @callback start_link(http: t()) :: GenServer.on_start()
  @callback do_request(
              http :: t(),
              method :: method(),
              path :: bitstring(),
              headers :: headers(),
              body :: body(),
              params :: params(),
              opts :: opts()
            ) ::
              {:ok, iodata()} | {:error, Error.t()}

  defp delegate(%module{} = http, func, args),
    do: apply(module, func, [http | args])

  def do_request(http, method, path, headers, body, params, opts \\ []) do
    delegate(http, :do_request, [method, path, headers, body, params, opts])
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
  def new(opts) do
    opts = opts |> Keyword.put_new(:name, __MODULE__)
    struct(__MODULE__, opts)
  end

  @impl Http
  def do_request(http, method, path, headers, body, params, opts) do
    with opts <- Keyword.put_new(opts, :receive_timeout, 2000),
         req <-
           Finch.build(
             method,
             url(path, params),
             headers,
             body,
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

  defp url(path, nil), do: path
  defp url(path, params) when params == %{}, do: path
  defp url(path, params), do: path <> "?" <> URI.encode_query(params)

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
