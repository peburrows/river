defmodule River.Frame.PushPromiseTest do
  use ExUnit.Case, async: true
  alias River.Frame.{PushPromise}

  setup do
    {:ok, ctx} = HPack.Table.start_link(4096)
    headers = [{":method", "GET"}]
    {:ok, %{ctx: ctx, headers: headers, payload: HPack.encode(headers, ctx)}}
  end

  test "we can decode a frame from a non-padded payload", %{headers: headers, ctx: ctx, payload: payload} do
    assert {:ok,
            %PushPromise{headers: ^headers}
    } = PushPromise.decode(%PushPromise{length: byte_size(payload)}, payload, ctx)
  end

  test "we can decode a frame from a padded payload", %{headers: headers, ctx: ctx, payload: payload} do
    assert {:ok,
            %PushPromise{
              headers: ^headers,
              flags:   %{padded: true}
            }
    } = PushPromise.decode(%PushPromise{length: (4+byte_size(payload))}, 0x8, <<3::8, payload::binary, "pad">>, ctx)
  end

  test "stream dependency is propery extracted", %{headers: headers, ctx: ctx, payload: payload} do
    payload = <<1::1, 5::31, payload::binary>>
    assert {:ok,
            %PushPromise{
              headers: ^headers,
              flags: %{priority: true},
              stream_dependency: 5,
              exclusive: true
            }
    } = PushPromise.decode(%PushPromise{length: byte_size(payload)}, 0x20, payload, ctx)
  end
end
