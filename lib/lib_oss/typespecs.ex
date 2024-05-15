defmodule LibOss.Typespecs do
  @moduledoc """
  some typespecs
  """

  @type name :: atom() | {:global, term()} | {:via, module(), term()}
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

  @type dict :: %{binary() => any()}
  @type bucket :: binary()
  @type object :: binary()
  @type acl :: binary()
  @type access_point_name :: binary()
  @type upload_id :: binary()
  @type part_num :: non_neg_integer()
  @type etag :: binary()
end
