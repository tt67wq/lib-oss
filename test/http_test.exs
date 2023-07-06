defmodule LibOss.HttpTest do
  use ExUnit.Case

  setup_all do
    http_impl = LibOss.Http.Default.new()
    start_link_supervised!({LibOss.Http.Default, [http: http_impl]})
    [http_impl: http_impl]
  end

  test "get", %{http_impl: http_impl} do
    req = %LibOss.Http.Request{
      scheme: "https",
      host: "www.baidu.com",
      method: :get,
      path: "/",
      headers: [],
      body: nil,
      params: nil,
      opts: []
    }

    assert {:ok, _} = LibOss.Http.do_request(http_impl, req)
  end
end
