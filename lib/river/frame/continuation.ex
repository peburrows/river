defmodule River.Frame.Continuation do
  alias River.{Frame, Frame.Headers}

  defstruct [
    headers:   [],
  ]

  defmodule Flags do
    defstruct [:end_stream, :end_headers, :padded, :priority]
    def parse(flags) do
      %__MODULE__{
        end_headers: River.Flags.has_flag?(flags, 0x4),
      }
    end
  end

  def decode(frame, payload, ctx) do
    %{frame |
      payload: %__MODULE__{
        headers: HPack.decode(payload, ctx)
      }
    }
  end
end
