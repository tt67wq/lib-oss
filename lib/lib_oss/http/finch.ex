defmodule LibOss.Http.Finch do
  @moduledoc """
  Finch HTTP 客户端实现。

  此模块实现了 LibOss.Http 协议，使用 Finch 作为底层 HTTP 客户端。
  Finch 是一个高性能的 HTTP 客户端，适合用于高并发场景。
  """

  @typedoc """
  Finch HTTP 客户端配置。

  ## 字段
    * `finch_name` - Finch 实例的名称
  """
  @type t :: %__MODULE__{
          finch_name: atom()
        }
  defstruct [:finch_name]
end

defimpl LibOss.Http, for: LibOss.Http.Finch do
  @moduledoc """
  Finch HTTP 客户端的 LibOss.Http 协议实现。

  此实现使用 Finch 作为底层 HTTP 客户端，处理 LibOss 的 HTTP 请求。
  """

  alias LibOss.Exception
  alias LibOss.Model.Http

  @default_receive_timeout 5_000

  @doc """
  执行 HTTP 请求。

  ## 参数
    * `finch` - Finch 实例
    * `req` - HTTP 请求

  ## 返回值
    * `{:ok, %Http.Response{}}` - 请求成功
    * `{:error, error}` - 请求失败
  """
  @spec do_request(LibOss.Http.Finch.t(), Http.Request.t()) ::
          {:ok, Http.Response.t()} | {:error, LibOss.Exception.t()}
  def do_request(%LibOss.Http.Finch{finch_name: finch_name}, req) do
    req_opts = Keyword.take(req.opts || [], [:pool_timeout, :request_timeout, :pool_strategy])
    req_opts = Keyword.put_new(req_opts, :receive_timeout, @default_receive_timeout)

    finch_req =
      Finch.build(
        req.method,
        Http.Request.url(req),
        req.headers,
        req.body
      )

    finch_req
    |> Finch.request(finch_name, req_opts)
    |> case do
      {:ok, %Finch.Response{status: status, body: body, headers: headers}}
      when status in 200..299 ->
        {:ok, %Http.Response{status_code: status, body: body, headers: headers}}

      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error, Exception.new("bad response", %{status: status, body: body})}

      {:error, exception} ->
        {:error, Exception.new("bad response", exception)}
    end
  end
end
