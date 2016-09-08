defmodule River.Frame.WindowUpdate do
  defstruct [:increment]

  def decode(<<_::1, inc::31>>) do
    {:ok, %__MODULE__{increment: inc}}
  end
end
