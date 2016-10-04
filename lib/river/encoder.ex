defmodule River.Encoder do
  require River.FrameTypes
  alias River.{Frame, FrameTypes}
  alias River.Frame.{Data, GoAway, Headers, Ping, Priority, PushPromise, RstStream, Settings, WindowUpdate}

  def encode(%Frame{} = frame, ctx \\ nil) do
    frame
    |> payload(ctx)
    |> header
    |> compile
  end

  defp compile(%Frame{__header: head, __payload: body}) do
    head <> body
  end

  defp payload(%{type: FrameTypes.continuation, payload: %{headers: headers}} = frame, ctx) do
    encoded = HPack.encode(headers, ctx)
    %{frame | __payload: encoded, length: byte_size(encoded)}
  end

  defp payload(%{type: FrameTypes.data, payload: %{data: data}} = frame, _ctx) do
    %{frame | __payload: data}
    |> padded_payload
    |> put_length
  end

  defp payload(%{type: FrameTypes.goaway, payload: %{error: err, last_stream_id: last_sid, debug: debug}} = frame, _ctx) do
    err = River.Errors.error_to_code(err)
    body = case debug do
      nil -> <<1::1, last_sid::31, err::32>>
      _   -> <<1::1, last_sid::31, err::32, debug::binary>>
    end
    %{frame | __payload: body, length: byte_size(body)}
  end

  defp payload(%{type: FrameTypes.headers, payload: %{headers: headers}} = frame, ctx) do
    %{frame | __payload: HPack.encode(headers, ctx)}
    |> weighted_payload
    |> padded_payload
    |> put_length
  end

  defp payload(%{type: FrameTypes.ping, flags: flags} = frame, _ctx) do
    %{frame | __payload: :binary.copy(<<0>>, 8), length: 8}
  end

  defp payload(%{type: FrameTypes.push_promise, payload: %{headers: headers, promised_stream_id: prom_id}} = frame, ctx) do
    %{frame | __payload: <<1::1, prom_id::31>> <> HPack.encode(headers, ctx)}
    |> padded_payload
    |> put_length
  end

  defp payload(%{type: FrameTypes.priority, payload: %{stream_dependency: dep, weight: w, exclusive: ex}} = frame, _ctx) do
    ex = if ex, do: 1, else: 0
    w  = w - 1

    %{frame | __payload: <<ex::1, dep::31, w::8>>, length: 5}
  end

  defp payload(%{type: FrameTypes.rst_stream, payload: %{error: err}} = frame, _ctx) do
    %{frame | __payload: <<River.Errors.error_to_code(err)::32>>, length: 4}
  end

  defp payload(%{type: FrameTypes.settings, payload: %{settings: settings}} = frame, _ctx) do
    data = Enum.map_join(settings, fn({k,v}) -> <<Settings.setting(k)::16, v::32>> end)
    %{frame | __payload: data, length: byte_size(data), stream_id: 0}
  end

  defp payload(%{type: FrameTypes.window_update, stream_id: stream, payload: %{increment: inc}} = frame, _ctx) do
    %{frame | __payload: <<1::1, inc::31>>, length: 4, stream_id: stream}
  end

  defp header(%{type: type, stream_id: stream_id, flags: flags, length: len} = frame) do
    %{frame | __header: <<len::24, type::8, River.Flags.encode(flags)::8, 1::1, stream_id::31>>}
  end

  defp weighted_payload(%{payload: %{weight: nil}} = frame), do: frame
  defp weighted_payload(%{__payload: payload, payload: %{weight: w, stream_dependency: dep, exclusive: ex}} = frame) do
    ex = if ex, do: 1, else: 0
    w  = w - 1
    %{frame | __payload: <<ex::1, dep::31, w::8>> <> payload}
  end

  defp padded_payload(%{payload: %{padding: 0}} = frame), do: frame
  defp padded_payload(%{__payload: payload, payload: %{padding: pl}} = frame) do
    %{frame | __payload: <<pl::8>> <> payload <> :crypto.strong_rand_bytes(pl)}
  end

  defp put_length(%{__payload: payload} = frame) do
    %{frame | length: byte_size(payload)}
  end
end
