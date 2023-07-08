defmodule LibOss.Utils do
  @moduledoc """
  utils
  """

  def debug(msg), do: tap(msg, &IO.inspect(&1))
end
