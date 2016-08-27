defmodule River.Frame do
  require Bitwise
  use River.FrameTypes

  defstruct [:payload, :stream_id, :type, :flags, :length]

  defimpl Inspect, for: River.Frame do
    def inspect(frame, opts) do
      Enum.join [
        "%River.Frame{",
        "stream_id: #{inspect frame.stream_id}",
        "type: #{inspect frame.type}",
        "flags: #{inspect frame.flags}",
        "length: #{frame.length}",
        "payload: #{inspect frame.payload}",
        "}"
      ], "\n\t"
    end
  end

  def http2_header, do: "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"

  def encode(value, stream_id, type, flags \\ 0) do
    <<
      byte_size(value)::size(24),
      type::size(8),
      flags::size(8),
      0::size(1), # emtpy bit
      stream_id::size(31),
      value::binary
    >>
  end

  def decode_frames(data, ctx, frames \\ [])
  def decode_frames(<<>>, ctx, frames) do
    {:ok, Enum.reverse(frames), ctx}
  end

  # I wonder if decode should work something more like this:
  def decode_frames(<<length::24, type::8, flags::8, _::1, stream_id::31, rest::binary>>, ctx, frames) do
    case rest do
      <<payload::binary-size(length), tail::binary>> ->
        frame = %River.Frame{length:    length,
                             type:      type,
                             flags:     River.Flags.flags(type, flags),
                             stream_id: stream_id,
                             payload:   decode_payload(type, payload, ctx)
                            }
        # IO.puts "the frame: #{inspect frame}"
        decode_frames(tail, ctx, [frame|frames])
      tail ->
        # be sure we include the frames we were able to extract, though
        {:error, :incomplete_frame, frames, tail, ctx}
    end
  end

  def decode_payload(@headers, payload, ctx),
    do: HPACK.decode(payload, ctx)

  # we have encountered an issue with a certain PUSH_PROMISE packet
  # coming from nghttp2.org
  def decode_payload(@push_promise, payload, ctx),
    # do: HPACK.decode(payload, ctx)
    do: {payload, ctx}

  def decode_payload(@data, payload, ctx), do: {payload, ctx}
  def decode_payload(@rst_stream, payload, ctx), do: {payload, ctx}

  def decode_payload(@goaway, <<_::size(1), sid::size(31), error::size(32), _rest::binary>>, ctx) do
    IO.puts "goaway because of stream: #{sid} -- #{error}"
    {error, ctx}
  end

  # settings frame
  def decode_payload(@settings, payload, ctx) do
    River.Frame.Settings.decode(payload, ctx)
  end

  defp frame_type(@settings),     do: :SETTINGS
  defp frame_type(@headers),      do: :HEADERS
  defp frame_type(@data),         do: :DATA
  defp frame_type(@rst_stream),   do: :RST_STREAM
  defp frame_type(@push_promise), do: :PUSH_PROMISE
  defp frame_type(@goaway),       do: :GOAWAY
end
