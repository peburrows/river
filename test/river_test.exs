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
  test "encoding a simple frame" do
    sid = 123
    assert <<5::size(24),
      0x4::size(8),
      _flags::size(8),
      0::size(1), ^sid::size(31),
      "hello">> = River.Frame.encode("hello", sid, 0x4)
  end

  # test "connecting via SSL to something like vitalsource.com" do
  #   River.Request.get("http2.golang.org")
  #   # River.Request.get("nghttp2.org")
  # end

  test "doing things via the genserver" do
    alias Experimental.DynamicSupervisor
    DynamicSupervisor.start_child(River.Supervisor, ["http2.golang.org", [name: GoogleConn]])
    River.BaseConnection.get(GoogleConn, "/")
    IO.puts "we asked for a get!"
    River.BaseConnection.get(GoogleConn, "/.well-known/h2interop/state")
    :timer.sleep(1000)
    River.BaseConnection.get(GoogleConn, "/")

    :timer.sleep(3_000)
  end
end
