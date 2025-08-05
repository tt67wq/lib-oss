defmodule LibOss.Utils do
  @moduledoc """
  utils
  """

  @spec do_sign(binary(), binary()) :: binary()
  def do_sign(string_to_sign, key) do
    :hmac
    |> :crypto.mac(:sha, key, string_to_sign)
    |> Base.encode64()
  end
end
