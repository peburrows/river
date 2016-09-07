defmodule River.Frame.Settings do
  use River.FrameTypes

  defmodule Flags do
    defstruct [ack: false]
    def parse(flags) do
      %__MODULE__{
        ack: River.Flags.has_flag?(flags, 0x1)
      }
    end
  end

  defstruct [
    settings: [],
    ack:      false
  ]

  def encode(settings, stream_id, flags \\ 0) when is_list(settings) do
    settings
    |> encode_payload
    |> River.Frame.encode(stream_id, @settings, flags)
  end

  def encode_payload(settings),
    do: encode_payload(settings, <<>>)
  defp encode_payload([], acc), do: acc
  defp encode_payload([{name, value}|tail], acc) do
    encode_payload(tail, (acc <> <<setting(name)::16, value::32>>))
  end

  def decode(payload),    do: decode(payload, %__MODULE__{})
  defp decode(<<>>, acc), do: acc
  defp decode(<<id::16, value::32, rest::binary>>, %{settings: settings}=acc) do
    # decode(rest, [{name(id), value} | acc])
    decode(rest, %{acc | settings: [{name(id), value} | settings]})
  end

  defp name(0x1), do: :HEADER_TABLE_SIZE
  defp name(0x2), do: :ENABLE_PUSH
  defp name(0x3), do: :MAX_CONCURRENT_STREAMS
  defp name(0x4), do: :INITIAL_WINDOW_SIZE
  defp name(0x5), do: :MAX_FRAME_SIZE
  defp name(0x6), do: :MAX_HEADER_LIST_SIZE

  defp setting(:HEADER_TABLE_SIZE), do: 0x1
  defp setting(:ENABLE_PUSH), do: 0x2
  defp setting(:MAX_CONCURRENT_STREAMS), do: 0x3
  defp setting(:INITIAL_WINDOW_SIZE), do: 0x4
  defp setting(:MAX_FRAME_SIZE), do: 0x5
  defp setting(:MAX_HEADER_LIST_SIZE), do: 0x6
end
