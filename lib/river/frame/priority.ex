defmodule River.Frame.Priority do
  defstruct [:exclusive, :stream_dependency, :weight]

  def decode(<<ex::1, dep::31, weight::8, _rest::binary>>) do
    {:ok,
     %__MODULE__{
       exclusive: (ex==1),
       stream_dependency: dep,
       weight: weight + 1
     }
    }
  end

  def decode(_), do: {:error, :incomplete_frame}
end
