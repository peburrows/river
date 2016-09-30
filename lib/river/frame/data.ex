defmodule River.Frame.Data do
  alias River.Frame

  defstruct [
    padding:   0,
    data:   <<>>,
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

  def decode(%Frame{length: len, flags: %{padded: true}} = frame, <<pad_len::8, data::binary>>) do
    data_len = len - pad_len - 1

    case data do
      <<payload::binary-size(data_len), _pad::binary-size(pad_len)>> ->
        %{frame | payload: %__MODULE__{
             padding: pad_len,
             data:    payload
          }}
      _ ->
        {:error, :invalid_frame}
    end
  end

  def decode(%Frame{length: len} = frame, data) do
    case data do
      <<payload::binary-size(len)>> ->
        %{frame | payload: %__MODULE__{data: payload}}
      _ ->
        {:error, :invalid_frame}
    end
  end

end
