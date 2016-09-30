defmodule Bench.MaxStreams do
  use Benchfella

  bench "connect and fire a bunch of requests" do
    Application.ensure_all_started(:river)
    1..250
    |> Enum.map(fn(i)->
      Task.async(fn()->
        case River.Client.get("https://http2.golang.org/", 10_000) do
          {:ok, %River.Response{code: 200}} -> nil # IO.puts(i)
          other -> IO.inspect([i, other])
        end
      end)
    end)
    |> Enum.map(&Task.await/1)
  end
end
