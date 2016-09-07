defmodule River.Frame.RstStream do
  defstruct [:error]

  def decode(<<e::32, _rest::binary>>),
    do: {:ok, %__MODULE__{error: River.Errors.code_to_error(e)}}

  def decode(_),
    do: {:error, :incomplete_frame}
end
