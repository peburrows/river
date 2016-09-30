defmodule River.Frame.GoAway do
  alias River.Frame
  defstruct [:last_stream_id, :error, :debug]

  def decode(%Frame{length: len} = frame, <<_::1, sid::31, err::32, rest::binary>>) do
    debug_len = len - 8
    case rest do
      <<debug::binary-size(debug_len)>> ->
        %{frame |
          payload: %__MODULE__{
            last_stream_id: sid,
            error: River.Errors.code_to_error(err),
            debug: debug,
          }
         }
      _ ->
        {:error, :invalid_frame}
    end
  end

  def decode(_), do: {:error, :invalid_frame}
end
