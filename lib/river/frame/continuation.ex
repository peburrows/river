defmodule River.Frame.Continuation do
  alias River.{Frame, Frame.Headers}

  defstruct [
    padding:   0,
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

  def decode(frame, payload, ctx) do
    case Headers.decode(frame, payload, ctx) do
      %Frame{payload: p}=frame ->
        %{frame |
          # super hacky, but convert the payload to a PushPromise
          payload: %__MODULE__{
            padding: p.padding,
            headers: p.headers,
            exclusive: p.exclusive,
            stream_dependency: p.stream_dependency,
            weight: p.weight
          }
         }
      e ->
        e
    end
  end
end
