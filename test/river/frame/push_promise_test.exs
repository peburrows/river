defmodule River.Frame.PushPromiseTest do
  use ExUnit.Case, async: true
  alias River.{Frame, Frame.PushPromise}

  setup do
    {:ok, ctx} = HPack.Table.start_link(4096)
    headers = [{":method", "GET"}]
    {:ok, %{ctx: ctx, headers: headers, payload: HPack.encode(headers, ctx)}}
  end

  test "we can decode a frame from a non-padded payload", %{headers: headers, ctx: ctx, payload: payload} do
    assert %Frame{
      payload: %PushPromise{
        headers: ^headers
      }
    } = PushPromise.decode(%Frame{length: byte_size(payload)}, payload, ctx)
  end

  test "we can decode a frame from a padded payload", %{headers: headers, ctx: ctx, payload: payload} do
    assert %Frame{
      flags:   %{padded: true},
      payload: %PushPromise{
        headers: ^headers,
      }
    } = PushPromise.decode(%Frame{length: (4+byte_size(payload)), flags: %{padded: true}}, <<3::8, payload::binary, "pad">>, ctx)
  end

  test "stream dependency is propery extracted", %{headers: headers, ctx: ctx, payload: payload} do
    payload = <<1::1, 5::31, 99::8, payload::binary>>
    assert %Frame{
      flags: %{priority: true},
      payload: %PushPromise{
        headers: ^headers,
        stream_dependency: 5,
        weight: 100,
        exclusive: true
      }
    } = PushPromise.decode(%Frame{length: byte_size(payload), flags: %{priority: true}}, payload, ctx)
  end
end
