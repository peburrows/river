defmodule River.Frame.Headers do
  defstruct [
    padding:   0,
    stream_id: nil,
    flags:     %{},
    length:    0,
    headers:   [],
    exclusive: false,
    stream_dependency: 0,
    weight:    0
  ]

  defmodule Flags do
    defstruct [:end_stream, :end_headers, :padded, :priority]
    def parse(flags) do
      %__MODULE__{
        end_stream:  River.Flags.has_flag?(flags, 0x1),
        end_headers: River.Flags.has_flag?(flags, 0x4),
        padded:      River.Flags.has_flag?(flags, 0x8),
        priority:    River.Flags.has_flag?(flags, 0x20)
      }
    end
  end

  def decode(%__MODULE__{}=frame, flags, payload, ctx) do
    frame
    |> parse_flags(flags)
    |> decode(payload, ctx)
  end

  def decode(%__MODULE__{}=frame, payload, ctx) do
    {frame, rest} =
      {frame, payload}
      |> extract_padding
      |> extract_priority
      |> decode_payload(ctx)
  end

  defp decode_payload({%__MODULE__{length: len, padding: pad_len, flags: %{padded: true}}=frame, payload}, ctx) do
    data_len = len - pad_len
    case payload do
      <<data::binary-size(data_len), _pad::binary-size(pad_len)>> ->
        {:ok, %{frame | headers: HPack.decode(data, ctx)}}
      _ ->
        {:error, :incomplete_frame}
    end
  end

  defp decode_payload({%__MODULE__{length: len}=frame, payload}, ctx) do
    case payload do
      <<data::binary-size(len)>> ->
        {:ok, %{frame | headers: HPack.decode(data, ctx)}}
      _ ->
        {:error, :incomplete_frame}
    end
  end

  defp parse_flags(frame, flags) do
    %{frame | flags: Flags.parse(flags)}
  end

  defp extract_padding({%{length: len, flags: %{padded: true}}=frame, <<pad_len::8, payload::binary>>}) do
    { %{frame | padding: pad_len, length: len-1}, payload }
  end
  defp extract_padding({f, p}), do: {f, p}

  defp extract_priority({%{length: len, flags: %{priority: true}}=frame, <<ex::1, dep::31, payload::binary>>}) do
    { %{frame | exclusive: (ex==1), stream_dependency: dep, length: len-4}, payload }
  end
  defp extract_priority({f, p}), do: {f, p}
end
