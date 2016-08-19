defmodule River.Frame do
  require Bitwise

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

  def decode(<<>>, _ctx, _socket), do: nil
  def decode(<< length::size(24), type::size(8), flags::size(8), _::size(1), stream_id::size(31), rest::binary>>, ctx, socket) do
    IO.puts "Decoding a frame (#{length} -- #{byte_size(rest)}):"
    IO.puts "\tframe type: #{inspect frame_type(type)}"
    IO.puts "\tflags: #{inspect flags(type, flags)}"
    IO.puts "\tstream ID: #{inspect stream_id}"
    next = case rest do
             <<payload::binary-size(length), n::binary>> ->
               IO.puts "\tpayload size: #{inspect length} (#{byte_size(payload)})"
               IO.puts "\tpayload: #{inspect payload}"
               decode_payload(type, payload, ctx)
               n
             payload ->
               # this means the rest of the payload is coming in the next packet...
               IO.puts "\tpayload size: #{inspect length} (#{byte_size(payload)})"
               IO.puts "\tpayload: #{inspect payload}"
               decode_payload(type, payload, ctx)
               ""
           end
    # <<payload::binary-size(length), next::binary>> = rest
    # if type == @data do
    #   IO.puts "\n\n" <> decode_payload(type, payload, ctx)
    # else
    #   IO.puts "\tthe payload: #{inspect decode_payload(type, payload, ctx)}"
    # end
    decode(next, ctx, socket)
  end



  def decode_payload(@headers, payload, ctx),
    do: HPack.decode(payload, ctx)

  def decode_payload(@push_promise, payload, ctx),
    do: HPack.decode(payload, ctx)

  def decode_payload(@data, payload, _ctx), do: payload
  def decode_payload(@rst_stream, payload, _ctx), do: payload

  # settings frame
  def decode_payload(@settings, payload, _ctx) do
    decode_settings(payload, [])
  end
  defp decode_settings(<<>>, acc), do: acc
  defp decode_settings(<<id::size(16), value::(32), rest::binary>>, acc) do
    decode_settings(rest, [{setting_name(id), value} | acc])
  end

  defp frame_type(@settings),   do: :SETTINGS
  defp frame_type(@headers),    do: :HEADERS
  defp frame_type(@data),       do: :DATA
  defp frame_type(@rst_stream), do: :RST_STREAM
  defp frame_type(@push_promise), do: :PUSH_PROMISE

  defp setting_name(0x1), do: :SETTINGS_HEADER_TABLE_SIZE
  defp setting_name(0x2), do: :SETTINGS_ENABLE_PUSH
  defp setting_name(0x3), do: :SETTINGS_MAX_CONCURRENT_STREAMS
  defp setting_name(0x4), do: :SETTINGS_INITIAL_WINDOW_SIZE
  defp setting_name(0x5), do: :SETTINGS_MAX_FRAME_SIZE
  defp setting_name(0x6), do: :SETTINGS_MAX_HEADER_LIST_SIZE

  defp flags(@settings, f) do
    get_flags([], f, {0x1, :ACK})
  end

  defp flags(@data, f) do
    get_flags([], f, {0x1, :END_STREAM})
  end

  defp flags(@push_promise, f) do
    []
    |> get_flags(f, {0x4, :END_HEADERS})
    |> get_flags(f, {0x8, :PADDED})
  end

  defp flags(@headers, f) do
    []
    |> get_flags(f, {0x4, :END_HEADERS})
    |> get_flags(f, {0x1, :END_STREAM})
    |> get_flags(f, {0x8, :PADDED})
    |> get_flags(f, {0x20, :PRIORITY})
  end

  defp flags(@rst_stream, _f), do: []

  defp get_flags(acc, f, {flag, name}) do
    case Bitwise.&&&(f, flag) do
      ^flag -> [name|acc]
      _     -> acc
    end
  end
end
