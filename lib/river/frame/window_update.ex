defmodule River.Frame.WindowUpdate do
  alias River.Frame

  defstruct [:increment]

  def decode(%Frame{}=frame, <<_::1, inc::31>>) do
    %{frame | payload: %__MODULE__{increment: inc}}
  end

  def decode(_, _), do: {:error, :invalid_frame}
end
