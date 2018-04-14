defmodule River.Frame.PushPromise do
  alias River.Frame

  defstruct padding: 0,
            headers: [],
            promised_stream_id: nil

  defmodule Flags do
    defstruct [:end_stream, :end_headers, :padded, :priority]

    def parse(flags) do
      %__MODULE__{
        end_stream: River.Flags.has_flag?(flags, 0x1),
        end_headers: River.Flags.has_flag?(flags, 0x4),
        padded: River.Flags.has_flag?(flags, 0x8),
        priority: River.Flags.has_flag?(flags, 0x20)
      }
    end
  end

  def decode(
        %Frame{length: len, flags: %{padded: true}} = frame,
        <<pl::8, _::1, prom_id::31, payload::binary>>,
        ctx
      ) do
    data_len = len - pl - 4 - 1

    case payload do
      <<data::binary-size(data_len), _pad::binary-size(pl)>> ->
        %{
          frame
          | payload: %__MODULE__{
              headers: HPack.decode(data, ctx),
              padding: pl,
              promised_stream_id: prom_id
            }
        }

      _ ->
        {:error, :invalid_frame}
    end
  end

  def decode(%Frame{length: len} = frame, <<_::1, prom_id::31, payload::binary>>, ctx) do
    data_len = len - 4

    case payload do
      <<hbf::binary-size(data_len)>> ->
        %{
          frame
          | payload: %__MODULE__{
              headers: HPack.decode(hbf, ctx),
              promised_stream_id: prom_id
            }
        }

      _ ->
        {:error, :invalid_frame}
    end
  end

  def decode(frame, payload, _ctx) do
    [frame, payload] |> IO.inspect()
  end
end
