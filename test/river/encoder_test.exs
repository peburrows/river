defmodule River.EncoderTest do
  use ExUnit.Case, async: true
  use River.FrameTypes
  alias River.{Frame, Encoder}
  alias River.Frame.{Data, GoAway, Headers, Ping, Priority, PushPromise, RstStream, Settings, WindowUpdate}

  test "we can encode a data frame w/o padding" do
    assert <<11::24, @data::8, 1::8, 1::1, 3::31, "hello world">> =
      Encoder.encode(%Frame{
            stream_id: 3,
            type: @data,
            flags: %{end_stream: true},
            payload: %Data{data: "hello world"}}
      )
  end

  test "we can encode a data frame w/padding" do
    assert <<11::24, @data::8, 0x8::8, 1::1, 5::31, 5::8, "hello", _::binary-size(5)>> =
      Encoder.encode(%Frame{
            stream_id: 5,
            type: @data,
            flags: %{padded: true},
            payload: %Data{
              data: "hello",
              padding: 5
            }}
      )
  end

  describe "GOAWAY frame" do
    # +-+-------------------------------------------------------------+
    # |R|                  Last-Stream-ID (31)                        |
    # +-+-------------------------------------------------------------+
    # |                      Error Code (32)                          |
    # +---------------------------------------------------------------+
    # |                  Additional Debug Data (*)                    |
    # +---------------------------------------------------------------+
    setup do
      {:ok, %{
          common: <<@goaway::8, 0::8, 1::1, 0::31, 1::1, 101::31, 0x1::32>>,
          frame: %Frame{
            stream_id: 0,
            type: @goaway,
            payload: %GoAway{
              error: :PROTOCOL_ERROR,
              last_stream_id: 101
            }
          }
       }
      }
    end

    test "we can encode w/o debug info", %{common: common, frame: frame} do
      assert <<8::24>> <> ^common = River.Encoder.encode(frame)
    end

    test "we can encode w/debug info", %{common: common, frame: frame} do
      m = common <> "test"
      assert <<12::24>> <> ^m = River.Encoder.encode(
        %{frame | payload: %{frame.payload | debug: "test"}}
      )
    end
  end

  describe "HEADERS frame" do
    setup do
      {:ok, enc_ctx} = HPack.Table.start_link(4096)
      {:ok, ctx} = HPack.Table.start_link(4096)
      headers = [{":authority", "google.com"}, {":method", "GET"}]
      encoded = HPack.encode(headers, enc_ctx)
      {:ok,
       %{
         ctx:     ctx,
         headers: headers,
         encoded: encoded,
         frame:   %Frame{
           stream_id: 9,
           type: @headers,
           payload: %Headers{
             headers: headers
           }
         }
       }
      }
    end

    test "we can encode w/o padding or weight", context do
      encoded = context.encoded
      len = byte_size(encoded)
      assert <<^len::24, @headers::8, 0::8, 1::1, 9::31, ^encoded::binary>> =
        Encoder.encode(context.frame, context.ctx)
    end

    test "we can encode w/padding", context do
      encoded = context.encoded
      enc_len = byte_size(encoded)
      pl = 10
      len = byte_size(context.encoded) + 10 + 1

      assert <<^len::24, @headers::8, 0x8::8, 1::1, 9::31, pl::8, ^encoded::binary-size(enc_len), _pad::binary-size(pl)>> =
        Encoder.encode(%{context.frame | flags: %{padded: true}, payload: %{context.frame.payload | padding: pl}}, context.ctx)
    end
  end
end
