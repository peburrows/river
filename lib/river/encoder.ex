defmodule River.Encoder do
  use River.FrameTypes
  alias River.Frame
  alias River.Frame.{Data, GoAway, Headers, Ping, Priority, PushPromise, RstStream, Settings, WindowUpdate}

  def encode(%Frame{}=frame, ctx \\ nil) do
    frame
    |> payload(ctx)
    |> header
    |> compile
  end

  defp compile(%Frame{__header: head, __payload: body}) do
    head <> body
  end

  defp payload(%{type: @data, payload: %{data: data}}=frame, _ctx) do
    %{frame | __payload: data}
    |> padded_payload
    |> put_length
  end

  defp payload(%{type: @goaway, payload: %{error: err, last_stream_id: last_sid, debug: debug}}=frame, _ctx) do
    err = River.Errors.error_to_code(err)
    body = case debug do
             nil -> <<1::1, last_sid::31, err::32>>
             _   -> <<1::1, last_sid::31, err::32, debug::binary>>
    end
    %{frame | __payload: body, length: byte_size(body)}
  end

  defp payload(%{type: @headers, payload: %{headers: headers}}=frame, ctx) do
    %{frame | __payload: HPack.encode(headers, ctx)}
    |> weighted_payload
    |> padded_payload
    |> put_length
  end

  defp payload(%{type: @ping, flags: flags}=frame, _ctx) do
    %{frame | __payload: :binary.copy(<<0>>, 8), length: 8}
  end

  defp header(%{type: type, stream_id: stream_id, flags: flags, length: len}=frame) do
    %{frame | __header: <<len::24, type::8, River.Flags.encode(flags)::8, 1::1, stream_id::31>>}
  end

  defp weighted_payload(%{payload: %{weight: nil}}=frame), do: frame
  defp weighted_payload(%{__payload: payload, payload: %{weight: w, stream_dependency: dep, exclusive: ex}}=frame) do
    ex = if ex, do: 1, else: 0
    w  = w-1
    %{frame | __payload: <<ex::1, dep::31, w::8>> <> payload}
  end

  defp padded_payload(%{payload: %{padding: 0}}=frame), do: frame
  defp padded_payload(%{__payload: payload, payload: %{padding: pl}}=frame) do
    %{frame | __payload: <<pl::8>> <> payload <> :crypto.strong_rand_bytes(pl) }
  end

  defp put_length(%{__payload: payload}=frame) do
    %{frame | length: byte_size(payload)}
  end

end
