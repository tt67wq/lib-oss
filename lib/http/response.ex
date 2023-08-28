defmodule LibOss.Http.Response do
  @moduledoc """
  http response
  """

  alias LibOss.Typespecs

  @http_response_schema [
    status_code: [
      type: :integer,
      doc: "http status code",
      default: 200
    ],
    headers: [
      type: {:list, :any},
      doc: "http headers",
      default: []
    ],
    body: [
      type: :string,
      doc: "http body",
      default: ""
    ]
  ]

  @type t :: %__MODULE__{
          status_code: Typespecs.http_status(),
          headers: Typespecs.headers(),
          body: Typespecs.body()
        }

  @type http_response_schema_t :: [unquote(NimbleOptions.option_typespec(@http_response_schema))]

  defstruct [:status_code, :headers, :body]

  @spec new(http_response_schema_t()) :: t()
  def new(opts) do
    opts = opts |> NimbleOptions.validate!(@http_response_schema)
    struct(__MODULE__, opts)
  end
end
