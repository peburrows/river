defmodule River.Request do
  require Bitwise
  # def get(url) do
  #   # :ssl.start

  #   host = String.to_charlist(url)

  #   IO.puts "sending GET http/2 request to: #{url}"

  #   verify_fun = {(&:ssl_verify_hostname.verify_fun/3), [{:check_hostname, host}]}
  #   certs = :certifi.cacerts()
  #   opts = [
  #     :binary,
  #     {:packet, 0},
  #     {:active, false},
  #     {:verify, :verify_peer},
  #     {:depth, 99},
  #     {:cacerts, certs},
  #     # {:partial_chain, &:hackney_connect.partial_chain/1},
  #     {:alpn_advertised_protocols, ["h2", "http/1.1"]},
  #     {:verify_fun, verify_fun}
  #   ]

  #   {:ok, socket} = :ssl.connect(host, 443, opts)
  #   proto = :ssl.negotiated_protocol(socket)
  #   IO.puts "protocol: #{inspect proto}"

  #   :ssl.send(socket, "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n")
  #   IO.puts "sending the settings frame"

  #   {:ok, ctx} = HPack.Table.start_link(1000)

  #   frame = River.Frame.encode(<<0x3::size(16), 100::size(32), 0x4::size(16), 65535::size(32)>>, 0, 0x4)

  #   :ssl.send(socket, frame)
  #   :ssl.setopts(socket, [active: true])

  #   spawn(fn()->
  #     IO.puts "#{IO.ANSI.red}sending the headers frame#{IO.ANSI.reset}"
  #     # headers = <<0::size(8), 130>>
  #     headers = HPack.encode([
  #       {":method", "GET"},
  #       {":scheme", "https"},
  #       {":path", "/"},
  #       {":authority", url},
  #       {"accept", "*/*"},
  #       {"user-agent", "River/0.0.1"}
  #     ], ctx)

  #     f = River.Frame.encode(headers, 25, 0x1, Bitwise.|||(0x4, 0x1))

  #     :ssl.send(socket, f)
  #   end)

  #   listen(ctx, socket)

  #   :ssl.close(socket)
  # end

  # def listen(ctx, socket) do
  #   receive do
  #     anything ->
  #       {:ssl, _, payload} = anything
  #       River.Frame.decode(payload, ctx, socket)
  #       listen(ctx, socket)
  #   after 2_000 ->
  #       IO.puts "nothing else, leaving!"
  #   end
  # end
end


defmodule RiverTest do
  use ExUnit.Case
  doctest River

  test "doing things via the genserver" do
    alias Experimental.DynamicSupervisor
    {:ok, golang} = River.Connection.create("http2.golang.org")
    {:ok, nghttp} = River.Connection.create("nghttp2.org")

    assert {:ok, %River.Response{code: 200}=g_resp}  = River.Connection.get(golang, "/")
    assert {:ok, %River.Response{code: 200}=ng_resp} = River.Connection.get(nghttp, "/")
    assert {:ok, %River.Response{code: 200}=g2_resp} = River.Connection.get(golang, "/.well-known/h2interop/state")

    # IO.puts "\nthe response: #{g_resp.code}, #{g_resp.content_type} ::  #{inspect g_resp.body}"
    # IO.puts "\nthe response: #{ng_resp.code}, #{ng_resp.content_type} ::  #{inspect ng_resp.body}"
    # IO.puts "\nthe response: #{g2_resp.code}, #{g2_resp.content_type} ::  #{inspect g2_resp.body}"


    assert {:error, :timeout} = River.Connection.get(golang, "/", 0)

    # :observer.start

    # :timer.sleep(:infinity)
  end
end
