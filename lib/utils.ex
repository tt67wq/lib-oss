defmodule LibOss.Utils do
  @moduledoc """
  utils
  """

  def debug(msg), do: tap(msg, &IO.inspect(&1))

  @spec do_sign(bitstring(), bitstring()) :: binary()
  def do_sign(string_to_sign, key) do
    :hmac
    |> :crypto.mac(:sha, key, string_to_sign)
    |> Base.encode64()
  end
end
