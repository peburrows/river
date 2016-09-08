defmodule River.Frame.Ping do
  alias River.Frame

  defstruct [:payload, :ack]

  # until we change the flags default to be a map
  def decode(%Frame{flags: []}=frame, payload) do
    decode(%{frame | flags: %{}}, payload)
  end

  def decode(%Frame{length: len, flags: flags}=frame, payload) do
    case payload do
      <<data::binary-size(len)>> ->
        %{frame |
          payload: %__MODULE__{
            payload: data,
            ack:     Map.get(flags, :ack, false)
          }
         }
      _ ->
        {:error, :invalid_frame}
    end
  end
end
