defmodule LibOss.Model.Http do
  @moduledoc false
  defmodule Request do
    @moduledoc """
    http request
    """
    alias LibOss.Typespecs

    require Logger

    @type t :: %__MODULE__{
            scheme: String.t(),
            host: String.t(),
            port: char(),
            method: Typespecs.method(),
            path: binary(),
            headers: Typespecs.headers(),
            body: Typespecs.body(),
            params: Typespecs.params(),
            opts: Typespecs.opts()
          }

    defstruct scheme: "https", host: "", port: 443, method: :get, path: "", headers: [], body: nil, params: %{}, opts: []

    @spec url(t()) :: URI.t()
    def url(%__MODULE__{scheme: scheme, host: host, port: port, path: path, params: params}) do
      query =
        if params in [nil, %{}] do
          nil
        else
          URI.encode_query(params)
        end

      # Build complete URI string then parse it
      port_part =
        if port != 443 and port != 80 do
          ":#{port}"
        else
          ""
        end

      uri_string = "#{scheme}://#{host}#{port_part}#{path}#{if(query, do: "?#{query}", else: "")}"
      URI.parse(uri_string)
    end
  end

  defmodule Response do
    @moduledoc """
    http response
    """

    alias LibOss.Typespecs

    @type t :: %__MODULE__{
            status_code: non_neg_integer(),
            headers: Typespecs.headers(),
            body: Typespecs.body()
          }

    defstruct status_code: 200, headers: [], body: nil
  end
end
