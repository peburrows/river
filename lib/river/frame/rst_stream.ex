defmodule River.Frame.RstStream do
  alias River.Frame

  defstruct [:error]

  def decode(%Frame{}=frame, <<e::32>>),
    do: %{frame | payload: %__MODULE__{error: River.Errors.code_to_error(e)}}

  def decode(_, _),
    do: {:error, :invalid_frame}
end
