defmodule LibOss.HttpTest do
  use ExUnit.Case

  setup_all do
    http_impl = LibOss.Http.Default.new()
    start_link_supervised!({LibOss.Http.Default, [http: http_impl]})
    [http_impl: http_impl]
  end

  test "get", %{http_impl: http_impl} do
    req =
      [
        scheme: "https",
        port: 443,
        host: "www.baidu.com",
        method: :get,
        path: "/"
      ]
      |> LibOss.Http.Request.new()

    assert {:ok, _} = LibOss.Http.do_request(http_impl, req)
  end
end
