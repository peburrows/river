defmodule River.Frame.GoAway do
  defstruct [:last_stream_id, :error, :debug]

  def decode(<<_::1, sid::31, err::32, debug::binary>>) do
    [sid, err, debug] |> IO.inspect
    {:ok, %__MODULE__{
      last_stream_id: sid,
      error: River.Errors.code_to_error(err),
      debug: debug
    }}
  end

  def decode(_), do: {:error, :incomplete_frame}
end
