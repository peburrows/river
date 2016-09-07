defmodule River.Frame.Data do
  defstruct [
    padding:   0,
    stream_id: nil,
    length:    0,
    payload:   "",
    flags:     %{},
  ]

  defmodule Flags do
    defstruct [:end_stream, :padded]
    def parse(flags) do
      %__MODULE__{
        end_stream: River.Flags.has_flag?(flags, 0x1),
        padded:     River.Flags.has_flag?(flags, 0x8)
      }
    end
  end

  def decode(%__MODULE__{}=frame, flags, payload) do
    frame
    |> parse_flags(flags)
    |> decode(payload)
  end

  def decode(%__MODULE__{}=frame, payload) do
    {frame, payload}
    |> extract_padding
    |> decode_payload
  end

  defp parse_flags(frame, flags) do
    %{frame | flags: Flags.parse(flags)}
  end

  defp extract_padding({%{length: len, flags: %{padded: true}}=frame, <<pad_len::8, payload::binary>>}) do
    { %{frame | padding: pad_len, length: len-1}, payload }
  end
  defp extract_padding({f, p}), do: {f, p}

  defp decode_payload({%{length: len, padding: pad_len, flags: %{padded: true}}=frame, payload}) do
    data_len = len - pad_len
    case payload do
      <<data::binary-size(data_len), _pad::binary-size(pad_len), _rest::binary>> ->
        {:ok, %{frame | payload: data}}
      _ ->
        {:error, :incomplete_frame}
    end
  end

  defp decode_payload({%{length: len}=frame, payload}) do
    case payload do
      <<data::binary-size(len), _rest::binary>> ->
        {:ok, %{frame | payload: data}}
      _ ->
        {:error, :incomplete_frame}
    end
  end

end
