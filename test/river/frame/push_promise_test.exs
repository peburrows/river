defmodule River.Frame.PushPromiseTest do
  use ExUnit.Case, async: true
  alias River.{Frame, Frame.PushPromise}

  setup do
    {:ok, ctx} = HPack.Table.start_link(4096)
    headers = [{":method", "GET"}]
    payload = <<1::1, 11::31>> <> HPack.encode(headers, ctx)
    {:ok, %{ctx: ctx, headers: headers, payload: payload}}
  end

  test "we can decode a frame from a non-padded payload", %{
    headers: headers,
    ctx: ctx,
    payload: payload
  } do
    assert %Frame{
             payload: %PushPromise{
               headers: ^headers,
               promised_stream_id: 11
             }
           } = PushPromise.decode(%Frame{length: byte_size(payload)}, payload, ctx)
  end

  test "we can decode a frame from a padded payload", %{
    headers: headers,
    ctx: ctx,
    payload: payload
  } do
    assert %Frame{
             flags: %{padded: true},
             payload: %PushPromise{
               headers: ^headers,
               promised_stream_id: 11,
               padding: 3
             }
           } =
             PushPromise.decode(
               %Frame{length: 4 + byte_size(payload), flags: %{padded: true}},
               <<3::8, payload::binary, "pad">>,
               ctx
             )
  end

  test "promised stream ID is propery extracted", %{headers: headers, ctx: ctx, payload: payload} do
    assert %Frame{
             payload: %PushPromise{
               headers: ^headers,
               promised_stream_id: 11
             }
           } = PushPromise.decode(%Frame{length: byte_size(payload)}, payload, ctx)
  end
end
