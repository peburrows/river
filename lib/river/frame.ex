defmodule River.Frame do
  use River.FrameTypes
  alias River.Frame.{Data, GoAway, Headers, Ping, Priority, PushPromise, RstStream, Settings, WindowUpdate}

  defstruct [
    payload: <<>>,
    stream_id: 0,
    type: nil,
    flags: %{},
    length: nil,
    __header: <<>>,
    __payload: <<>>
  ]

  defimpl Inspect, for: River.Frame do
    def inspect(frame, opts) do
      Enum.join [
        "%River.Frame{",
        "stream_id: #{inspect frame.stream_id}",
        "type: #{inspect frame.type}",
        "flags: #{inspect frame.flags}",
        "length: #{frame.length}",
        "payload: #{inspect frame.payload}",
        "__payload: #{inspect frame.__payload}",
        "__header: #{inspect frame.__header}",
        "}"
      ], "\n\t"
    end
  end

  def http2_header, do: "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"

  def decode(<<>>, _ctx), do: {:ok, [], <<>>}
  def decode(<<length::24, type::8, flags::8, _::1, stream::31, payload::binary>>=packet, ctx) do
    ["length, type, flags, stream", length, type, flags, stream, byte_size(packet)] |> IO.inspect
    case payload do
      <<data::binary-size(length), tail::binary>> ->
        frame = %__MODULE__{length: length,
                            type:   type,
                            flags:  parse_flags(type, flags),
                            stream_id: stream
                           } |> decode_payload(data, ctx)
        {:ok, frame, tail}
      _ ->
        {:error, :invalid_frame, packet}
    end
  end


  defp decode_payload(%{type: @data}=frame, payload, _ctx) do
    Data.decode(frame, payload)
  end

  defp decode_payload(%{type: @goaway}=frame, payload, _ctx) do
    GoAway.decode(frame, payload)
  end

  defp decode_payload(%{type: @headers}=frame, payload, ctx) do
    Headers.decode(frame, payload, ctx)
  end

  defp decode_payload(%{type: @ping}=frame, payload, _ctx) do
    Ping.decode(frame, payload)
  end

  defp decode_payload(%{type: @push_promise}=frame, payload, ctx) do
    PushPromise.decode(frame, payload, ctx)
  end

  defp decode_payload(%{type: @priority}=frame, payload, _ctx) do
    Priority.decode(frame, payload)
  end

  defp decode_payload(%{type: @rst_stream}=frame, payload, _ctx) do
    RstStream.decode(frame, payload)
  end

  defp decode_payload(%{type: @settings}=frame, payload, _ctx) do
    Settings.decode(frame, payload)
  end

  defp decode_payload(%{type: @window_update}=frame, payload, _ctx) do
    WindowUpdate.decode(frame, payload)
  end

  defp parse_flags(@data, flags),
    do: Data.Flags.parse(flags)

  defp parse_flags(@goaway, _flags),
    do: %{}

  defp parse_flags(@headers, flags),
    do: Headers.Flags.parse(flags)

  defp parse_flags(@ping, flags),
    do: Ping.Flags.parse(flags)

  defp parse_flags(@priority, _flags),
    do: %{}

  defp parse_flags(@push_promise, flags),
    do: PushPromise.Flags.parse(flags)

  defp parse_flags(@rst_stream, _flags),
    do: %{}

  defp parse_flags(@settings, flags),
    do: Settings.Flags.parse(flags)

  defp parse_flags(@window_update, _flags),
    do: %{}

  defp frame_type(@settings),     do: :SETTINGS
  defp frame_type(@headers),      do: :HEADERS
  defp frame_type(@data),         do: :DATA
  defp frame_type(@rst_stream),   do: :RST_STREAM
  defp frame_type(@push_promise), do: :PUSH_PROMISE
  defp frame_type(@goaway),       do: :GOAWAY
end
