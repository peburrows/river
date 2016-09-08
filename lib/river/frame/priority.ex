defmodule River.Frame.Priority do
  alias River.Frame
  defstruct [:exclusive, :stream_dependency, :weight]

  def decode(%Frame{}=frame, <<ex::1, dep::31, weight::8>>) do
    %{frame |
      payload: %__MODULE__{
        exclusive: (ex==1),
        stream_dependency: dep,
        weight: weight + 1
      }
    }
  end

  def decode(_, _), do: {:error, :invalid_frame}
end
