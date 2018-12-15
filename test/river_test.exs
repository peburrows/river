defmodule RiverTest do
  use ExUnit.Case, async: true
  doctest River

  describe "http2.golang.org" do
    @tag external: true
    test "timeout" do
      assert {:error, :timeout} = River.Client.get("https://http2.golang.org/", timeout: 0)
    end

    @tag external: true, timeout: 20_000
    test "multiple requests on the same connection return the right thing!" do
      c = 100
      # make sure it's all on the same conn
      {:ok, _conn} = River.Conn.create("http2.golang.org", 443)

      all =
        1..c
        |> Enum.map(fn _ ->
          Task.async(fn ->
            s = :crypto.strong_rand_bytes(20) |> Base.url_encode64() |> binary_part(0, 20)
            up = String.upcase(s)
            assert {:ok, %{body: ^up}} = River.Client.put("https://http2.golang.org/ECHO", s)
          end)
        end)
        |> Enum.map(&Task.await/1)

      assert c == Enum.count(all)
    end

    @tag external: true, timeout: 10_000
    test "request after a timeout does not return previous response" do
      River.Client.get("https://http2.golang.org/", timeout: 0)
      Process.sleep(2_000)
      assert {:ok, %{body: "HELLO"}} = River.Client.put("https://http2.golang.org/ECHO", "hello")
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
               River.Client.get("https://http2.golang.org/file/go.src.tar.gz", timeout: 5_000)

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

      assert {:ok, %River.Response{code: 200} = resp} =
               River.Client.put("https://http2.golang.org/ECHO", body)

      assert resp.body == body |> String.upcase()
    end

    @tag external: true
    test "a large PUT to the golang server" do
      body = for(n <- 1..100_000, do: Integer.to_charlist(n)) |> Enum.join()

      assert {:ok, %River.Response{code: 200}} =
               River.Client.put("https://http2.golang.org/crc32", body) |> IO.inspect()
    end
  end

  describe "nghttp2.org" do
    @tag external: true
    test "a simple get" do
      assert {:ok, %River.Response{code: 200}} = River.Client.get("https://nghttp2.org/")
    end
  end
end
