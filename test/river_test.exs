defmodule River.Request do
  def get(url) do
    :ssl.start

    host = String.to_charlist(url)

    IO.puts "sending GET http/2 request to: #{url}"

    verify_fun = {(&:ssl_verify_hostname.verify_fun/3), [{:check_hostname, host}]}
    certs = :certifi.cacerts()
    opts = [
      :binary,
      {:packet, 0},
      {:active, false},
      {:verify, :verify_peer},
      {:depth, 99},
      {:cacerts, certs},
      {:partial_chain, &:hackney_connect.partial_chain/1},
      {:alpn_advertised_protocols, ["h2", "http/1.1"]},
      {:verify_fun, verify_fun}
    ]

    {:ok, socket} = :ssl.connect(host, 443, opts)
    proto = :ssl.negotiated_protocol(socket)
    IO.puts "protocol: #{inspect proto}"

    :ssl.send(socket, "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n")
    IO.puts "sending the settings frame"
    # :ssl.send(socket, <<0x3::size(16), 200::size(32)>>)
    frame = River.Frame.encode(<<0x3::size(16), 100::size(32)>>, 0, 0x4)
    River.Frame.decode(frame)
    :ssl.send(socket, frame)
    :ssl.setopts(socket, [active: true])

    listen()
    # spawn(fn()-> do
    #     :ssl.send(socket, River::Frame.encode())
    # end)
    # receive do
    #   anything ->
    #     IO.puts "received packet"
    #     {:ssl, _, payload} = anything
    #     River.Frame.decode(payload)
    # after 3_000 ->
    #     IO.puts "timeout"
    # end

    # :timer.sleep(2_000)
    # :erlang.process_info(self, :messages) |> IO.inspect
    :ssl.close(socket)
  end

  defp listen do
    receive do
      anything ->
        IO.puts "received packet: "
        {:ssl, _, payload} = anything
        River.Frame.decode(payload)
        listen()
    after 2_000 ->
        IO.puts "nothing else, leaving!"
    end
  end
end

defmodule River.Frame do
  defstruct [:payload, :stream_id, :type, :flags, :length]

  def encode(value, stream_id, type, flags \\ 0) do
    <<
      byte_size(value)::size(24),
      type::size(8),
      flags::size(8),
      0::size(1), # emtpy bit
      stream_id::size(31),
      value::bitstring
    >>
  end

  def decode(<< length::size(24), type::size(8), flags::size(8), _::size(1), stream_id::size(31), payload::binary-size(length)>>) do
    IO.puts "\tframe type: #{inspect frame_type(type)}"
    IO.puts "\tpayload size: #{inspect length}"
    IO.puts "\tflags: #{inspect flags}"
    IO.puts "\tstream ID: #{inspect stream_id}"
    IO.puts "\tthe payload: #{inspect decode_payload(type, payload)}"
  end

  @data          0x0
  @headers       0x1
  @priority      0x2
  @rst_stream    0x3
  @settings      0x4
  @push_promise  0x5
  @ping          0x6
  @goaway        0x7
  @window_update 0x8
  @continuation  0x9

  # settings frame
  def decode_payload(@settings, payload) do
    decode_settings(payload, [])
  end
  defp decode_settings(<<>>, acc), do: acc
  defp decode_settings(<<id::size(16), value::(32), rest::binary>>, acc) do
    decode_settings(rest, [{setting_name(id), value} | acc])
  end

  defp frame_type(@settings), do: :SETTINGS

  defp setting_name(0x1), do: :SETTINGS_HEADER_TABLE_SIZE
  defp setting_name(0x2), do: :SETTINGS_ENABLE_PUSH
  defp setting_name(0x3), do: :SETTINGS_MAX_CONCURRENT_STREAMS
  defp setting_name(0x4), do: :SETTINGS_INITIAL_WINDOW_SIZE
  defp setting_name(0x5), do: :SETTINGS_MAX_FRAME_SIZE
  defp setting_name(0x6), do: :SETTINGS_MAX_HEADER_LIST_SIZE
end

defmodule River.FrameHeader do
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

  test "connecting via SSL to something like vitalsource.com" do
    River.Request.get("http2.golang.org")
  end
end
