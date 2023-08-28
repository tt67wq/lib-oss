defmodule LibOss.Http do
  @moduledoc """
  behavior os http transport
  """
  alias LibOss.{Error, Typespecs}

  @type t :: struct()

  @callback new(Typespecs.opts()) :: t()
  @callback start_link(http: t()) :: Typespecs.on_start()
  @callback do_request(
              http :: t(),
              req :: LibOss.Http.Request.t()
            ) ::
              {:ok, LibOss.Http.Response.t()} | {:error, Error.t()}

  defp delegate(%module{} = http, func, args),
    do: apply(module, func, [http | args])

  @spec do_request(t(), LibOss.Http.Request.t()) ::
          {:ok, LibOss.Http.Response.t()} | {:error, Error.t()}
  def do_request(http, req), do: delegate(http, :do_request, [req])

  def start_link(%module{} = http) do
    apply(module, :start_link, [[http: http]])
  end
end
