defmodule River.EncoderTest do
  use ExUnit.Case, async: true
  require River.FrameTypes
  alias River.{Frame, Encoder, FrameTypes}
  alias River.Frame.{Data, Continuation, GoAway, Headers, Priority, PushPromise, RstStream, Settings, WindowUpdate}

  test "we can encode a data frame w/o padding" do
    assert <<11::24, FrameTypes.data::8, 1::8, 1::1, 3::31, "hello world">> =
      Encoder.encode(%Frame{
            stream_id: 3,
            type: FrameTypes.data,
            flags: %{end_stream: true},
            payload: %Data{data: "hello world"}}
      )
  end

  test "we can encode a data frame w/padding" do
    assert <<11::24, FrameTypes.data::8, 0x8::8, 1::1, 5::31, 5::8, "hello", _::binary-size(5)>> =
      Encoder.encode(%Frame{
            stream_id: 5,
            type: FrameTypes.data,
            flags: %{padded: true},
            payload: %Data{
              data: "hello",
              padding: 5
            }}
      )
  end

  describe "CONTINUATION frame" do
    # +---------------------------------------------------------------+
    # |                   Header Block Fragment (*)                 ...
    # +---------------------------------------------------------------+

    test "can be encoded" do
      {:ok, enc_context} = HPack.Table.start_link(1000)
      {:ok, ctx} = HPack.Table.start_link(4096)
      headers = [{"x-hello", "world"}]
      encoded = HPack.encode(headers, enc_context)
      len     = byte_size(encoded)
      assert <<len::24, FrameTypes.continuation::8, 0x4::8, 1::1, 15::31, encoded::binary>> ==
        Encoder.encode(%Frame{
              type: FrameTypes.continuation,
              stream_id: 15,
              flags: %{end_headers: true},
              payload: %Continuation{
                header_block_fragment: encoded,
              }}, ctx)
    end
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
          common: <<FrameTypes.goaway::8, 0::8, 1::1, 0::31, 1::1, 101::31, 0x1::32>>,
          frame: %Frame{
            stream_id: 0,
            type: FrameTypes.goaway,
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
    # +---------------+
    # |Pad Length? (8)|
    # +-+-------------+-----------------------------------------------+
    # |E|                 Stream Dependency? (31)                     |
    # +-+-------------+-----------------------------------------------+
    # |  Weight? (8)  |
    # +-+-------------+-----------------------------------------------+
    # |                   Header Block Fragment (*)                 ...
    # +---------------------------------------------------------------+
    # |                           Padding (*)                       ...
    # +---------------------------------------------------------------+
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
           type: FrameTypes.headers,
           payload: %Headers{
             header_block_fragment: encoded,
           }
         }
       }
      }
    end

    test "we can encode w/o padding or weight", context do
      encoded = context.encoded
      len = byte_size(encoded)
      assert <<^len::24, FrameTypes.headers::8, 0::8, 1::1, 9::31, ^encoded::binary>> =
        Encoder.encode(context.frame, context.ctx)
    end

    test "we can encode w/padding", context do
      encoded = context.encoded
      enc_len = byte_size(encoded)
      pl = 10
      len = byte_size(context.encoded) + 10 + 1

      assert <<^len::24, FrameTypes.headers::8, 0x8::8, 1::1, 9::31, _pl::8, ^encoded::binary-size(enc_len), _pad::binary-size(pl)>> =
        Encoder.encode(%{context.frame | flags: %{padded: true}, payload: %{context.frame.payload | padding: pl}}, context.ctx)
    end

    test "we can encode w/weight", context do
      encoded = context.encoded
      enc_len = byte_size(encoded)
      len     = enc_len + 5

      frame = %{context.frame |
                flags: %{priority: true},
                payload: %{context.frame.payload |
                           stream_dependency: 15,
                           weight: 100
                }
               }

      expected = <<len::24, FrameTypes.headers::8, 0x20::8, 1::1, frame.stream_id::31, 0::1, 15::31, 99::8, encoded::binary-size(enc_len)>>
      assert ^expected =
        Encoder.encode(frame, context.ctx)
    end

    test "we can encode w/weight & w/padding", context do
      encoded = context.encoded
      enc_len = byte_size(encoded)
      pl      = 15
      len     = enc_len + pl + 5 + 1

      frame   = %{context.frame |
                  flags: %{priority: true, padded: true},
                  payload: %{context.frame.payload |
                             stream_dependency: 15,
                             weight: 100,
                             exclusive: true,
                             padding: pl
                  }
                 }

      expected = <<len::24, FrameTypes.headers::8, 0x28::8, 1::1,
        frame.stream_id::31, pl::8, 1::1,
        frame.payload.stream_dependency::31,
        (frame.payload.weight-1)::8, encoded::binary-size(enc_len)>>

      result = Encoder.encode(frame, context.ctx)
      assert ^expected = binary_part(result, 0, byte_size(expected))
      assert len + 9 == byte_size(result)
    end
  end

  describe "PING frame" do
    # +---------------------------------------------------------------+
    # |                      Opaque Data (64)                         |
    # +---------------------------------------------------------------+

    test "we can encode" do
      frame = %Frame{type: FrameTypes.ping, flags: %{ack: true}}
      assert <<8::24, FrameTypes.ping::8, 0x1::8, 1::1, 0::31, _::binary-size(8)>> =
        Encoder.encode(frame)
    end
  end

  describe "PUSH_PROMISE frame" do
    # +---------------+
    # |Pad Length? (8)|
    # +-+-------------+-----------------------------------------------+
    # |R|                  Promised Stream ID (31)                    |
    # +-+-----------------------------+-------------------------------+
    # |                   Header Block Fragment (*)                 ...
    # +---------------------------------------------------------------+
    # |                           Padding (*)                       ...
    # +---------------------------------------------------------------+
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
           type: FrameTypes.push_promise,
           payload: %PushPromise{
             headers: headers,
             promised_stream_id: 15
           }
         }
       }
      }
    end

    test "we can encode w/o padding", context do
      encoded = context.encoded
      len = byte_size(encoded) + 4

      assert <<^len::24, FrameTypes.push_promise::8, 0::8, 1::1, 9::31,
        1::1, _prom_id::31, ^encoded::binary>> =
        Encoder.encode(context.frame, context.ctx)
    end

    test "we can encode w/padding", context do
      encoded = context.encoded
      enc_len = byte_size(encoded)
      pl      = 15
      len     = enc_len + pl + 4 + 1

      frame   = %{context.frame |
                  flags: %{padded: true},
                  payload: %{context.frame.payload |
                             padding: pl
                  }
                 }

      expected = <<len::24, FrameTypes.push_promise::8, 0x08::8, 1::1,
        frame.stream_id::31, pl::8,
        1::1, frame.payload.promised_stream_id::31,
        encoded::binary-size(enc_len)>>

      result = Encoder.encode(frame, context.ctx)
      assert ^expected = binary_part(result, 0, byte_size(expected))
      assert len + 9 == byte_size(result)
    end
  end

  describe "PRIORITY frame" do
    test "can be encoded" do
      assert <<5::24, FrameTypes.priority::8, 0::8, 1::1, 101::31, 1::1, 113::31, 99::8>> ==
        Encoder.encode(%Frame{
              type: FrameTypes.priority,
              stream_id: 101,
              payload: %Priority{
                stream_dependency: 113,
                weight: 100,
                exclusive: true
              }})
    end
  end

  describe "RST_STREAM frame" do
    test "can be encoded" do
      assert <<4::24, FrameTypes.rst_stream::8, 0::8, 1::1, 19::31, 0x1::32>> ==
        Encoder.encode(%Frame{
              type: FrameTypes.rst_stream,
              stream_id: 19,
              payload: %RstStream{
                error: :PROTOCOL_ERROR
              }})
    end
  end

  describe "SETTINGS frame" do
    # +-------------------------------+
    # |       Identifier (16)         |
    # +-------------------------------+-------------------------------+
    # |                        Value (32)                             |
    # +---------------------------------------------------------------+
    test "can be encoded" do
      assert <<6::24, FrameTypes.settings::8, 0::8, 1::1, 0::31, 0x1::16, 4096::32>> ==
        Encoder.encode(%Frame{
              type: FrameTypes.settings,
              payload: %Settings{
                settings: [HEADER_TABLE_SIZE: 4096]
              }})
    end

    test "can be encoded with multiple settings and an ACK flag" do
      assert <<18::24, FrameTypes.settings::8, 0x1::8, 1::1, 0::31,
        0x1::16, 4096::32, 0x2::16, 0::32, 0x3::16, 250::32>> ==
        Encoder.encode(%Frame{
              type: FrameTypes.settings,
              flags: %{ack: true},
              payload: %Settings{
                settings: [
                  HEADER_TABLE_SIZE: 4096,
                  ENABLE_PUSH: 0,
                  MAX_CONCURRENT_STREAMS: 250
                ]
              }})
    end
  end

  describe "WINDOW_UPDATE frame" do
    # +-+-------------------------------------------------------------+
    # |R|              Window Size Increment (31)                     |
    # +-+-------------------------------------------------------------+
    test "can be encoded" do
      assert <<4::24, FrameTypes.window_update::8, 0::8, 1::1, 0::31, 1::1, 10_000::31>> ==
        Encoder.encode(%Frame{
              type: FrameTypes.window_update,
              payload: %WindowUpdate{
                increment: 10_000
              }})
    end
  end
end
