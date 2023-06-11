defmodule LibOss.Client do
  @moduledoc """
  behavior: LibOss.Client
  """
  alias LibOss.{Error}

  @type t :: struct()
  @type opts :: keyword()
  @type method :: Finch.Request.method()
  @type path :: bitstring()
  @type headers :: [%{String.t() => String.t()}]
  @type body :: %{String.t() => any()} | nil
  @type params :: %{String.t() => any()} | nil

  @callback new(opts()) :: t()
  @callback start_link(client: t()) :: GenServer.on_start()
  @callback do_request(
              client :: t(),
              method :: method(),
              path :: bitstring(),
              headers :: headers(),
              body :: body(),
              params :: params(),
              opts :: opts()
            ) ::
              {:ok, iodata()} | {:error, Error.t()}

  defp delegate(%module{} = client, func, args),
    do: apply(module, func, [client | args])

  def do_request(client, method, path, headers, body, params, opts \\ []) do
    delegate(client, :do_request, [method, path, headers, body, params, opts])
  end
end

defmodule LibOss.Client.Finch do
  @moduledoc """
  Implement LibOss.Client behavior with Finch
  """

  alias LibOss.{Client, Error}

  @behaviour Client

  # types
  @type t :: %__MODULE__{
          name: GenServer.name()
        }

  @enforce_keys ~w(name)a

  defstruct @enforce_keys

  @impl Client
  def new(opts) do
    opts = opts |> Keyword.put_new(:name, __MODULE__)
    struct(__MODULE__, opts)
  end

  def child_spec(opts) do
    client = Keyword.fetch!(opts, :client)
    %{id: {__MODULE__, client.name}, start: {__MODULE__, :start_link, [opts]}}
  end

  @impl Client
  def do_request(client, method, path, headers, body, params, opts) do
    with opts <- Keyword.put_new(opts, :receive_timeout, 2000),
         url <- path <> "?" <> URI.encode_query(params),
         req <-
           Finch.build(
             method,
             url,
             headers,
             body,
             opts
           ) do
      Finch.request(req, client.name)
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

  @impl Client
  def start_link(opts) do
    {client, _opts} = Keyword.pop!(opts, :client)
    Finch.start_link(name: client.name)
  end
end
