defmodule Bench.MaxStreams do
  use Benchfella

  bench "connect and fire a bunch of requests" do
    Application.ensure_all_started(:river)
    {:ok, conn} = River.Conn.create("http2.golang.org")
    # {:ok, conn} = River.Conn.create("nghttp2.org")
    1..250
    |> Enum.map(fn(i)->
      Task.async(fn()->
        case River.Conn.get(conn, "/", 10_000) do
          {:ok, resp} -> IO.inspect([i, resp.code])
          other -> IO.inspect([i, other])
        end
        # {:ok, resp} = River.Conn.get(conn, "/", 1000)
        # [i, resp.code] |> IO.inspect
      end)
    end)
    |> Enum.map(&Task.await/1)
  end
end
