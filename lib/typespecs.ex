defmodule LibOss.Typespecs do
  @moduledoc """
  some typespecs
  """

  @type opts :: keyword()
  @type host :: String.t()
  @type method :: :get | :post | :head | :patch | :delete | :options | :put
  @type headers :: [{String.t(), String.t()}]
  @type body :: iodata() | nil
  @type params :: %{String.t() => binary()}
  @type http_status :: non_neg_integer()
  @type on_start ::
          {:ok, pid()}
          | :ignore
          | {:error, {:already_started, pid()} | term()}

  @type string_dict :: %{bitstring() => any()}
  @type bucket :: bitstring()
  @type object :: bitstring()
  @type acl :: bitstring()
  @type access_point_name :: bitstring()
end
