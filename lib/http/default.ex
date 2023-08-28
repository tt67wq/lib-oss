defmodule LibOss.Http.Default do
  @moduledoc """
  Implement LibOss.Http behavior with Finch
  """

  require Logger
  alias LibOss.{Http, Error}

  @behaviour Http

  # types
  @type t :: %__MODULE__{
          name: atom()
        }

  defstruct name: __MODULE__

  @impl Http
  def new(opts \\ []) do
    opts = opts |> Keyword.put_new(:name, __MODULE__)
    struct(__MODULE__, opts)
  end

  @impl Http
  def do_request(http, req) do
    with opts <- opts(req.opts),
         {debug?, opts} <- Keyword.pop(opts, :debug),
         finch_req <-
           Finch.build(
             req.method,
             Http.Request.url(req),
             req.headers,
             req.body,
             opts
           ) do
      if debug? do
        Logger.debug(%{
          "method" => req.method,
          "url" => Http.Request.url(req) |> URI.to_string(),
          "params" => req.params,
          "headers" => req.headers,
          "body" => req.body,
          "opts" => opts,
          "req" => finch_req
        })
      end

      finch_req
      |> Finch.request(http.name)
      |> case do
        {:ok, %Finch.Response{status: status, body: body, headers: headers}}
        when status in 200..299 ->
          {:ok, Http.Response.new(status_code: status, body: body, headers: headers)}

        {:ok, %Finch.Response{status: status, body: body}} ->
          {:error, Error.new("status: #{status}, body: #{body}")}

        {:error, exception} ->
          Logger.error(%{"request" => req, "exception" => exception})
          {:error, Error.new(inspect(exception))}
      end
    end
  end

  defp opts(nil), do: [receive_timeout: 5000]
  defp opts(options), do: Keyword.put_new(options, :receive_timeout, 5000)

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
