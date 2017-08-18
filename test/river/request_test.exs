defmodule River.RequestTest do
  use ExUnit.Case, async: true
  alias River.{Request}

  setup do
    { :ok, %{request: %Request{uri: URI.parse("https://google.com")}} }
  end

  describe "Request.new/4" do
    test "given a valid uri, method, data and headers" do
      uri = URI.parse("https://localhost/")
      method = :get
      data = "data"
      headers = [{"test-header", "value"}]
      assert {:ok,
        %Request{uri: uri, method: method, data: data,
                 headers: [{"user-agent", "River/#{River.version}"}] ++ headers}} ==
        Request.new(uri, method, data, headers)
    end

    test "given a nil uri returns an :invalid_uri error" do
      assert {:error, :invalid_uri} == Request.new(nil, :get)
    end

    test "given a nil method returns an :invalid_method error" do
      uri = URI.parse("https://localhost/")
      assert {:error, :invalid_method} == Request.new(uri, nil)
    end

    test "given a nil scheme returns an :invalid_uri error" do
      uri = %URI{authority: "localhost", scheme: nil, path: "/"}
      assert {:error, :invalid_uri} == Request.new(uri, :get)
    end

    test "given a nil authority returns an :invalid_uri error" do
      uri = %URI{authority: nil, scheme: :https, path: "/"}
      assert {:error, :invalid_uri} == Request.new(uri, :get)
    end

    test "given a nil path and :options method sets path to *" do
      uri = %URI{authority: "localhost", scheme: :https, path: nil}
      assert {:ok, %Request{uri: %URI{path: "*"}}} = Request.new(uri, :options)
    end

    test "given a nil path and :get method sets path to /" do
      uri = %URI{authority: "localhost", scheme: :https, path: nil}
      assert {:ok, %Request{uri: %URI{path: "/"}}} = Request.new(uri, :get)
    end
  end

  test "the default headers include the River user-agent", %{request: request} do
    assert [{"user-agent", <<"River/", _::binary>>}] = request.headers
  end

  test "a single header can be added", %{request: request} do
    request = Request.add_header(request, {"test", "header"})
    assert [_, {"test", "header"}] = request.headers
  end

  test "headers can be added", %{request: request} do
    header = {"hello", "world"}
    request = Request.add_headers(request, [header])
    assert [{"user-agent", _}, ^header] = request.headers
  end

  test "headers don't overwrite headers that already exist on request", %{request: request} do
    headers = [{"x-custom", "custom value"}]
    request = %{request | headers: headers}
    request = Request.add_headers(request, [{"x-custom", "custom value 2"}])

    # we remove the user-agent header above when we update the struct
    assert [
      {"x-custom", "custom value"},
      {"x-custom", "custom value 2"}
    ] == request.headers
  end

  test "the user-agent header can be overwritten", %{request: request} do
    request = Request.add_headers(request, [{"user-agent", "custom"}])
    assert [{"user-agent", "custom"}] == request.headers
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
