defmodule LibOss.Request do
  @moduledoc """
  request struct
  """

  @request_schema [
    method: [
      type: {:in, [:get, :put, :post, :delete, :head, :options, :patch]},
      doc: "HTTP method",
      required: true
    ],
    object: [
      type: :string,
      doc: "OSS object",
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

  @verbs %{
    post: "POST",
    get: "GET",
    put: "PUT",
    delete: "DELETE",
    head: "HEAD",
    options: "OPTIONS",
    patch: "PATCH"
  }

  # types
  @type request_schema_t :: keyword(unquote(NimbleOptions.option_typespec(@request_schema)))
  @type t :: %__MODULE__{
          method: atom(),
          object: String.t(),
          resource: String.t(),
          sub_resources: [{String.t(), String.t()}],
          bucket: String.t(),
          params: %{String.t() => String.t()},
          body: iodata(),
          headers: [{String.t(), String.t()}],
          expires: non_neg_integer()
        }

  defstruct [
    :method,
    :object,
    :resource,
    :sub_resources,
    :bucket,
    :params,
    :body,
    :headers,
    :expires
  ]

  @doc """
  create a new request struct

  ## Options
  #{NimbleOptions.docs(@request_schema)}
  """
  @spec new(request_schema_t()) :: t()
  def new(opts) do
    opts =
      opts
      |> NimbleOptions.validate!(@request_schema)

    __MODULE__
    |> struct(opts)
  end

  @spec build_headers(t(), LibOss.t()) :: t()
  def build_headers(request, client) do
    headers = [
      {"Host", client.endpoint},
      {"Content-Type", content_type(request)},
      {"Content-MD5", content_md5(request)},
      {"Content-Length", byte_size(request.body)},
      {"Date", gmt_now()} | request.headers
    ]

    %{request | headers: headers}
  end

  @spec auth(t(), LibOss.t()) :: t()
  def auth(request, client) do
    headers = [
      {"Authorization", "OSS#{client.access_key_id}:#{signature(request, client)}}"}
      | request.headers
    ]

    %{request | headers: headers}
  end

  @spec signature(t(), LibOss.t()) :: binary()
  defp signature(request, client) do
    request
    |> string_to_sign()
    |> do_sign(client.access_key_secret)
  end

  @spec do_sign(binary(), iodata()) :: binary()
  defp do_sign(string_to_sign, key) do
    :hmac
    |> :crypto.mac(:sha, key, string_to_sign)
    |> Base.encode64()
  end

  @spec string_to_sign(t()) :: binary()
  defp string_to_sign(%{scheme: "rtmp"} = request) do
    [
      expire_time(request),
      canonicalize_query_params(request) <> canonicalize_resource(request)
    ]
    |> Enum.join("\n")
  end

  defp string_to_sign(request) do
    [
      "#{@verbs[request.method]}",
      get_header(request, "Content-MD5"),
      get_header(request, "Content-Type"),
      expires_time(request),
      canonicalize_oss_headers(request) <> canonicalize_resource(request)
    ]
    |> Enum.join("\n")
  end

  defp get_header(request, header_key),
    do: Enum.find_value(request.headers, fn {^header_key, v} -> v end)

  @spec expires_time(t()) :: binary()
  defp expires_time(%{expires: 0} = request) do
    request
    |> get_header("Date")
    |> to_string()
  end

  defp expire_time(%{expires: expires}), do: expires |> to_string()

  defp canonicalize_oss_headers(%{headers: headers}) do
    headers
    |> Stream.filter(&is_oss_header?/1)
    |> Stream.map(&encode_header/1)
    |> Enum.join("\n")
    |> case do
      "" -> ""
      str -> str <> "\n"
    end
  end

  defp canonicalize_resource(%{resource: resource, sub_resources: nil}), do: resource

  defp canonicalize_resource(%{resource: resource, sub_resources: sub_resources}) do
    sub_resources
    |> Stream.map(fn
      {k, nil} -> k
      {k, v} -> "#{k}=#{v}"
    end)
    |> Enum.join("&")
    |> case do
      "" -> resource
      query_string -> resource <> "?" <> query_string
    end
  end

  defp canonicalize_query_params(%{params: params}) do
    params
    |> Stream.map(fn {k, v} -> "#{k}:#{v}\n" end)
    |> Enum.join()
  end

  defp is_oss_header?({h, _}) do
    Regex.match?(~r/^x-oss-/i, to_string(h))
  end

  defp encode_header({h, v}) do
    (h |> to_string() |> String.downcase()) <> ":" <> to_string(v)
  end

  defp content_type(%{resource: resource}) do
    case Path.extname(resource) do
      "." <> name -> MIME.type(name)
      _ -> "application/octet-stream"
    end
  end

  defp content_md5(%{body: ""}), do: ""

  defp content_md5(%{body: body}) do
    :md5
    |> :crypto.hash(body)
    |> Base.encode64()
  end

  defp gmt_now() do
    {:ok, dt} = DateTime.now("Etc/UTC")
    Calendar.strftime(dt, "%a, %d %b %Y %H:%M:%S GMT")
  end
end
