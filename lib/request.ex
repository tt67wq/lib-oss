defmodule LibOss.Request do
  @moduledoc """
  request struct
  """

  @request_schema [
    method: [
      type: :atom,
      doc: "HTTP method",
      required: true
    ],
    endpoint: [
      type: :string,
      doc: "OSS endpoint",
      required: true
    ],
    resource: [
      type: :string,
      doc: "OSS resource",
      default: "/"
    ],
    sub_resources: [
      type: {:list, :any},
      doc: "OSS sub resources",
      default: []
    ],
    bucket: [
      type: :string,
      doc: "OSS bucket",
      required: true
    ],
    params: [
      type: :map,
      doc: "OSS query params",
      default: %{}
    ],
    body: [
      type: :string,
      doc: "HTTP body",
      default: ""
    ],
    headers: [
      type: {:list, :any},
      doc: "HTTP headers",
      default: []
    ],
    expires: [
      type: :integer,
      doc: "oss expires",
      default: 0
    ]
  ]

  @type request_schema_t :: keyword(unquote(NimbleOptions.option_typespec(@request_schema)))

  @type t :: %__MODULE__{
          method: atom(),
          endpoint: String.t(),
          resource: String.t(),
          sub_resources: [{String.t(), String.t()}],
          bucket: String.t(),
          params: %{String.t() => String.t()},
          body: binary(),
          headers: [{String.t(), String.t()}],
          expires: non_neg_integer()
        }

  @enforce_keys ~w(method endpoint resource sub_resources bucket params body headers expires)a

  defstruct @enforce_keys

  @doc """
  create a new request struct

  ## Options
  #{NimbleOptions.docs(@request_schema)}

  ## Examples

      {:ok, return_value} = function_name()
  """
  @spec new(request_schema_t()) :: t()
  def new(opts) do
    opts =
      opts
      |> NimbleOptions.validate!(@request_schema)

    struct(__MODULE__, opts)
  end
end
