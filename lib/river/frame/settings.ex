defmodule River.Frame.Settings do
  alias River.Frame

  defmodule Flags do
    defstruct [ack: false]
    def parse(flags) do
      %__MODULE__{
        ack: River.Flags.has_flag?(flags, 0x1)
      }
    end
  end

  defstruct [
    settings: []
  ]

  def decode(%Frame{payload: %__MODULE__{settings: settings}} = frame, <<>>) do
    %{frame |
      payload: %{frame.payload | settings: Enum.reverse(settings)}
    }
  end

  def decode(%Frame{payload: <<>>} = frame, data),
    do: decode(%{frame | payload: %__MODULE__{}}, data)

  def decode(%Frame{payload: payload} = frame, <<id::16, value::32, rest::binary>>) do
    decode(%{frame |
             payload: %{payload | settings: [{name(id), value} | payload.settings]}
            }, rest)
  end

  def name(0x1), do: :HEADER_TABLE_SIZE
  def name(0x2), do: :ENABLE_PUSH
  def name(0x3), do: :MAX_CONCURRENT_STREAMS
  def name(0x4), do: :INITIAL_WINDOW_SIZE
  def name(0x5), do: :MAX_FRAME_SIZE
  def name(0x6), do: :MAX_HEADER_LIST_SIZE

  def setting(:HEADER_TABLE_SIZE), do: 0x1
  def setting(:ENABLE_PUSH), do: 0x2
  def setting(:MAX_CONCURRENT_STREAMS), do: 0x3
  def setting(:INITIAL_WINDOW_SIZE), do: 0x4
  def setting(:MAX_FRAME_SIZE), do: 0x5
  def setting(:MAX_HEADER_LIST_SIZE), do: 0x6
end
