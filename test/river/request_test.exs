defmodule River.RequestTest do
  use ExUnit.Case, async: true
  alias River.{Request}

  setup do
    { :ok, %{request: %Request{uri: URI.parse("https://google.com")}} }
  end

  test "the default headers include the River user-agent", %{request: request} do
    assert [{"user-agent", <<"River/", _::binary>>}] = request.headers
  end

  test "headers can be added", %{request: request} do
    headers = [{"hello", "world"}]
    request = Request.add_headers(request, headers)
    assert [{"user-agent", _}, {"hello", "world"}] = request.headers
  end

  test "headers don't overwrite headers that already exist on request", %{request: request} do
    headers = [{"content-type", "x-custom"}]
    request = %{request | headers: headers}
    request = Request.add_headers(request, [{"content-type", "x-custom-2"}])

    # we remove the user-agent header above when we update the struct
    assert [
      {"content-type", "x-custom"},
      {"content-type", "x-custom-2"}
    ] == request.headers
  end

  test "we cannot add a :path header manually", %{request: request} do
    request = Request.add_headers(request, [{":path", "/abc"}])
    assert [{"user-agent", _}] = request.headers
  end

  test "we cannot add a :method header manually", %{request: request} do
    request = Request.add_headers(request, [{":method", "DELETE"}])
    assert [{"user-agent", _}] = request.headers
  end

  test "we cannot add a :scheme header manually", %{request: request} do
    request = Request.add_headers(request, [{":scheme", "http"}])
    assert [{"user-agent", _}] = request.headers
  end

  test "we cannot add a :authority header manually", %{request: request} do
    request = Request.add_headers(request, [{":authority", "example.com"}])
    assert [{"user-agent", _}] = request.headers
  end
end
