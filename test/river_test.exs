defmodule RiverTest do
  use ExUnit.Case, async: true
  doctest River

  describe "http2.golang.org" do
    @tag external: true
    test "timeout" do
      assert {:error, :timeout} =
        River.Client.get("https://http2.golang.org/", timeout: 0)
    end

    @tag external: true
    test "a simple GET " do
      assert {:ok, %River.Response{code: 200} = resp} =
        River.Client.get("https://http2.golang.org/")
      assert byte_size(resp.body) > 0
    end

    @tag external: true
    test "a GET for JSON" do
      assert {:ok, %River.Response{code: 404} = resp} =
        River.Client.get("https://http2.golang.org/.well-known/h2interop/state")
      assert byte_size(resp.body) > 0
      assert <<"404", _::binary>> = resp.body
    end

    @tag external: true
    test "a GET for a PNG file" do
      assert {:ok, %River.Response{code: 200} = resp} =
        River.Client.get("https://http2.golang.org/file/gopher.png")
      assert byte_size(resp.body) > 0
    end

    @tag external: true, timeout: 120_000, slow: true
    test "a GET for a big file that requires flow window increments" do
      assert {:ok, %River.Response{code: 200} = resp} =
        River.Client.get("https://http2.golang.org/file/go.src.tar.gz", timeout: 1_000)
      assert resp.body
    end

    @tag external: true
    test "a GET with large headers" do
      cookie = :crypto.strong_rand_bytes(30_000) |> Base.url_encode64()
      headers = [{"cookie", cookie}]
      assert {:ok, %River.Response{code: 200} = resp} =
        River.Client.get("https://http2.golang.org/", headers: headers)
      assert byte_size(resp.body) > 0
    end

    @tag external: true
    test "a PUT to the golang server" do
      body = "hello"
      assert {:ok, %River.Response{code: 200}=resp} =
        River.Client.put("https://http2.golang.org/ECHO", body)
      assert resp.body == body |> String.upcase
    end

    @tag external: true
    test "a large PUT to the golang server" do
      body = (for n <- 1..100_000, do: Integer.to_charlist(n)) |> Enum.join
      assert {:ok, %River.Response{code: 200}} =
        River.Client.put("https://http2.golang.org/crc32", body)
    end
  end

  describe "nghttp2.org" do
    @tag external: true
    test "a simple get" do
      assert {:ok, %River.Response{code: 200}} =
        River.Client.get("https://nghttp2.org/")
    end
  end
end
