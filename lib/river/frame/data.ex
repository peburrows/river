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

  def decode(%__MODULE__{flags: nil}=frame, flags, payload) do
    %{frame | flags: Flags.parse(flags)}
    |> decode(payload)
  end

  def decode(%__MODULE__{length: len, flags: %{padded: false}}=frame, payload) do
    case payload do
      <<data::binary-size(len), rest::binary>> ->
        {:ok, %{frame | payload: data}}
      _ ->
        {:error, :incomplete_frame}
    end
  end

  # padded payload
  def decode(%__MODULE__{length: len}=frame, <<pad_len::8, payload::binary>>) do
    data_len = len - pad_len - 1

    case payload do
      <<data::binary-size(data_len), _padding::binary-size(pad_len), rest::binary>> ->
        {:ok, %{frame | payload: data, padding: pad_len}}
      _ ->
        {:error, :incomplete_frame}
    end
  end

  # if it hasn't matched anything, it's incomplete
  def decode(%__MODULE__{}, payload) do
    {:error, :incomplete_frame}
  end
end
