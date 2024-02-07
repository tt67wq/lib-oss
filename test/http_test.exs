defmodule LibOss.HttpTest do
  @moduledoc false
  use ExUnit.Case

  setup_all do
    start_link_supervised!({LibOss.Http.Default, []})
    []
  end

  test "get" do
    req =
      LibOss.Http.Request.new(scheme: "https", port: 443, host: "www.baidu.com", method: :get, path: "/")

    assert {:ok, _} = LibOss.Http.do_request(LibOss.Http.Default, req)
  end
end
