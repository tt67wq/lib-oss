defmodule LibOss.Error do
  @moduledoc """
  error of lib_oss
  """
  defexception [:message]

  @type t :: %__MODULE__{
          message: String.t()
        }

  @spec new(String.t()) :: %__MODULE__{}
  def new(message) do
    %__MODULE__{message: message}
  end
end
