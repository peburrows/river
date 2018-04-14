defmodule River.Frame.HeadersTest do
  use ExUnit.Case, async: true
  alias River.{Frame, Frame.Headers}

  setup do
    {:ok, ctx} = HPack.Table.start_link(4096)
    headers = [{":method", "GET"}]
    {:ok, %{ctx: ctx, headers: headers, payload: HPack.encode(headers, ctx)}}
  end

  test "we can decode a frame from a non-padded payload", %{
    headers: headers,
    ctx: ctx,
    payload: payload
  } do
    assert %Frame{
             payload: %Headers{
               headers: ^headers
             }
           } = Headers.decode(%Frame{length: byte_size(payload)}, payload, ctx)
  end

  test "we can decode a frame from a padded payload", %{
    headers: headers,
    ctx: ctx,
    payload: payload
  } do
    assert %Frame{
             flags: %{padded: true},
             payload: %Headers{
               headers: ^headers,
               padding: 3
             }
           } =
             Headers.decode(
               %Frame{length: 4 + byte_size(payload), flags: %{padded: true}},
               <<3::8, payload::binary, "pad">>,
               ctx
             )
  end

  test "stream dependency is propery extracted", %{headers: headers, ctx: ctx, payload: payload} do
    payload = <<1::1, 5::31, 99::8, payload::binary>>

    assert %Frame{
             flags: %{priority: true},
             payload: %Headers{
               headers: ^headers,
               stream_dependency: 5,
               weight: 100,
               exclusive: true
             }
           } =
             Headers.decode(
               %Frame{length: byte_size(payload), flags: %{priority: true}},
               payload,
               ctx
             )
  end

  test "a payload with a priority and padding is properly decoded", %{
    headers: headers,
    ctx: ctx,
    payload: payload
  } do
    payload = <<3::8, 0::1, 5::31, 99::8, payload::binary>> <> "pad"

    assert %Frame{
             payload: %Headers{
               headers: ^headers,
               stream_dependency: 5,
               weight: 100,
               exclusive: false,
               padding: 3
             }
           } =
             Headers.decode(
               %Frame{length: byte_size(payload), flags: %{padded: true, priority: true}},
               payload,
               ctx
             )
  end
end
