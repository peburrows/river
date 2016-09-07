defmodule River.Frame.Ping do
  defstruct [:payload, :ack]

  def decode(<<payload::64, _rest::binary>>),
    do: {:ok, %__MODULE__{payload: <<payload::64>>}}
end
