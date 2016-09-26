defmodule RiverTest do
  use ExUnit.Case
  doctest River

  test "doing things via the GenServer" do
    alias Experimental.DynamicSupervisor

    # IO.puts "getting golang"
    # assert {:ok, %River.Response{code: 200} = g_resp}  = River.Client.get("https://http2.golang.org/")
    # IO.puts "getting nghttp2"
    # assert {:ok, %River.Response{code: 200} = ng_resp} = River.Client.get("https://nghttp2.org/")
    # IO.puts "getting golang"
    # assert {:ok, %River.Response{code: 200} = g2_resp} = River.Client.get("https://http2.golang.org/.well-known/h2interop/state")
    # IO.puts "getting golang"
    # assert {:ok, %River.Response{code: 200} = g3_resp} = River.Client.get("https://http2.golang.org/.well-known/h2interop/state")
    # IO.puts "getting golang"
    # assert {:ok, %River.Response{code: 200} = g4_resp} = River.Client.get("https://http2.golang.org/file/gopher.png")

    IO.puts "BIG file"
    assert {:ok, %River.Response{code: 200} = _g5_resp} = River.Client.get("https://http2.golang.org/file/go.src.tar.gz", 1_000)

    # IO.puts "\nthe response: #{g_resp.code}, #{g_resp.content_type} ::  #{inspect g_resp.body}"
    # IO.puts "\nthe response: #{ng_resp.code}, #{ng_resp.content_type} ::  #{inspect ng_resp.body}"
    # IO.puts "\nthe response: #{g2_resp.code}, #{g2_resp.content_type} ::  #{inspect g2_resp.body}"
    # IO.puts "\nthe response: #{g3_resp.code}, #{g3_resp.content_type} ::  #{inspect g3_resp.body}"
    # IO.puts "\nthe response: #{g4_resp.code}, #{g4_resp.content_type} ::  #{inspect g4_resp.body} (#{byte_size(g4_resp.body)}bytes) "
    # IO.puts "\nthe response: #{g5_resp.code}, #{g5_resp.content_type} ::  #{inspect g5_resp.body} (#{byte_size(g5_resp.body)}bytes) "

    assert {:error, :timeout} = River.Client.get("https://http2.golang.org/", 0)
  end

  # test "doing a PUT" do
  #   assert {:ok, %River.Response{code: 200}=put} = River.Client.put("https://http2.golang.org/ECHO", "hello, world")
  # end
end
