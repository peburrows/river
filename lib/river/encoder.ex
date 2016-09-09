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

  defp payload(%{type: @data, payload: %{data: data, padding: pl}, flags: %{padded: true}}=frame, _ctx) do
    %{frame | length: byte_size(data) + pl + 1, __payload: <<pl::8, data::binary, :crypto.strong_rand_bytes(pl)::binary-size(pl)>>}
  end

  defp payload(%{type: @data, payload: %{data: data}}=frame, _ctx) do
    %{frame | length: byte_size(data), __payload: <<data::binary>>}
  end

  defp payload(%{type: @goaway, payload: %{error: err, last_stream_id: last_sid, debug: debug}}=frame, _ctx) do
    err = River.Errors.error_to_code(err)
    body = case debug do
             nil -> <<1::1, last_sid::31, err::32>>
             _   -> <<1::1, last_sid::31, err::32, debug::binary>>
    end
    %{frame | __payload: body, length: byte_size(body)}
  end

  defp payload(%{type: @headers, payload: %{headers: headers, padding: pl}, flags: %{padded: true}}=frame, ctx) do
    encoded = HPack.encode(headers, ctx)
    %{frame | length: byte_size(encoded) + pl + 1, __payload: <<pl::8, encoded::binary, :crypto.strong_rand_bytes(pl)::binary-size(pl)>>}
  end

  defp payload(%{type: @headers, payload: %{headers: headers}}=frame, ctx) do
    encoded = HPack.encode(headers, ctx)
    %{frame | __payload: encoded, length: byte_size(encoded)}
  end

  defp header(%{type: type, stream_id: stream_id, flags: flags, length: len}=frame) do
    %{frame | __header: <<len::24, type::8, River.Flags.encode(flags)::8, 1::1, stream_id::31>>}
  end

end
