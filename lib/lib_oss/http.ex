defprotocol LibOss.Http do
  @doc """
  Perform an HTTP request.
  """
  @spec do_request(
          http :: LibOss.Http.t(),
          req :: LibOss.Model.Http.Request.t()
        ) ::
          {:ok, LibOss.Model.Http.Response.t()} | {:error, LibOss.Exception.t()}
  def do_request(http, req)
end
