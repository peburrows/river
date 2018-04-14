defmodule River.Frame.Headers do
  alias River.Frame

  defstruct padding: 0,
            headers: [],
            header_block_fragment: <<>>,
            exclusive: false,
            stream_dependency: nil,
            weight: nil

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
        %Frame{length: len, flags: %{padded: true, priority: true}} = frame,
        <<pl::8, ex::1, dep::31, weight::8, payload::binary>>,
        ctx
      ) do
    data_len = len - pl - 6

    case payload do
      <<data::binary-size(data_len), _pad::binary-size(pl)>> ->
        %{
          frame
          | payload: %__MODULE__{
              headers: HPack.decode(data, ctx),
              padding: pl,
              exclusive: ex == 1,
              weight: weight + 1,
              stream_dependency: dep
            }
        }

      _ ->
        {:error, :invalid_frame}
    end
  end

  def decode(%Frame{length: len, flags: %{padded: true}} = frame, <<pl::8, payload::binary>>, ctx) do
    data_len = len - pl - 1

    case payload do
      <<data::binary-size(data_len), _pad::binary-size(pl)>> ->
        %{
          frame
          | payload: %__MODULE__{
              headers: HPack.decode(data, ctx),
              padding: pl
            }
        }

      _ ->
        {:error, :invalid_frame}
    end
  end

  def decode(
        %Frame{length: len, flags: %{priority: true}} = frame,
        <<ex::1, dep::31, weight::8, payload::binary>>,
        ctx
      ) do
    data_len = len - 5

    case payload do
      <<data::binary-size(data_len)>> ->
        %{
          frame
          | payload: %__MODULE__{
              headers: HPack.decode(data, ctx),
              stream_dependency: dep,
              weight: weight + 1,
              exclusive: ex == 1
            }
        }

      _ ->
        {:error, :invalid_frame}
    end
  end

  def decode(%Frame{length: len} = frame, payload, ctx) do
    case payload do
      <<data::binary-size(len)>> ->
        %{
          frame
          | payload: %__MODULE__{
              headers: HPack.decode(data, ctx)
            }
        }

      _ ->
        {:error, :invalid_frame}
    end
  end
end
