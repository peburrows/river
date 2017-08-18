defmodule River.FrameTest do
  use ExUnit.Case, async: true
  require River.FrameTypes
  alias River.{Frame, FrameTypes}
  alias River.Frame.{Data, GoAway, Headers, Ping, Priority, PushPromise, RstStream, Settings, WindowUpdate}

  test "the http2 header is correct" do
    assert Frame.http2_header() ==
           <<0x505249202a20485454502f322e300d0a0d0a534d0d0a0d0a::192>>
  end

  test "decoding a single frame with excess data" do
    data = <<0::24, 4::8, 1::8, 0::1, 15::31>> <> "extra"
    assert {:ok,
            %Frame{
              length:    0,
              type:      0x4,
              stream_id: 15,
              flags:     %{ack: true},
              payload:   %Frame.Settings{settings: []}
            }, "extra"} = Frame.decode(data, :ctx)
  end

  test "decoding a DATA frame respects padding" do
    payload = "hello"
    padding = "world"
    length = byte_size(payload <> padding) + 1
    data = <<length::24, 0::8, 0x8::8, 1::1, 13::31, byte_size(padding)::8, payload::binary, padding::binary>>

    assert {:ok, %Frame{
               flags:   %{padded: true},
               stream_id: 13,
               payload: %Data{
                 padding: 5,
                 data:    "hello"
               }
            }, ""} = Frame.decode(data, :ctx)
  end

  test "decoding a GOAWAY frame" do
    payload = <<1::1, 13::31, 0x6::32>>
    frame = <<byte_size(payload)::24, FrameTypes.goaway::8, 0::8, 1::1, 0::31, payload::binary>>

    assert {:ok, %Frame{
               stream_id: 0,
               payload: %GoAway{
                 error: :FRAME_SIZE_ERROR,
                 last_stream_id: 13
               }
            }, ""} = Frame.decode(frame, :ctx)
  end

  test "decoding a HEADERS frame" do
    {:ok, ctx} = HPack.Table.start_link(4096)
    headers    = [{":method", "GET"}]
    payload    = HPack.encode(headers, ctx)
    length     = byte_size(payload)
    frame      = <<length::24, FrameTypes.headers::8, 0x1::8, 1::1, 21::31, payload::binary>>

    assert {:ok, %Frame{
               stream_id: 21,
               length: _length,
               flags: %{end_stream: true},
               payload: %Headers{
                 headers: ^headers
               }
            }, ""} = Frame.decode(frame, ctx)
  end

  test "decoding a PING frame" do
    frame = <<8::24, FrameTypes.ping::8, 0::8, 1::1, 0::31, 100::64>>
    assert {:ok, %Frame{
               length: 8,
               stream_id: 0,
               flags: %{ack: false},
               payload: %Ping{
                 payload: <<100::64>>
               }
            }, ""} = Frame.decode(frame, :ctx)
  end

  test "decoding a PRIORITY frame" do
    frame = <<5::24, FrameTypes.priority::8, 0::8, 1::1, 15::31, 1::1, 21::31, 100::8>>
    assert {:ok, %Frame{
               length: 5,
               stream_id: 15,
               payload: %Priority{
                 stream_dependency: 21,
                 weight: 101,
                 exclusive: true
               }
            }, ""} = Frame.decode(frame, :ctx)
  end

  test "decoding a PUSH_PROMISE frame" do
    {:ok, ctx} = HPack.Table.start_link(4096)
    headers    = [{":method", "GET"}]
    payload    = HPack.encode(headers, ctx)
    length     = byte_size(payload) + 4
    frame      = <<length::24, FrameTypes.push_promise::8, 0x1::8, 1::1, 21::31, 1::1, 25::31, payload::binary>>

    assert {:ok, %Frame{
               length:   ^length,
               stream_id: 21,
               flags: %{end_stream: true},
               payload: %PushPromise{
                 promised_stream_id: 25,
                 headers: ^headers,
               }
            }, ""} = Frame.decode(frame, ctx)
  end

  test "decoding an RST_STREAM frame" do
    frame = <<4::24, FrameTypes.rst_stream::8, 0::8, 0::1, 101::31, 0x1::32>>

    assert {:ok, %Frame{
               length: 4,
               stream_id: 101,
               payload: %RstStream{
                 error: :PROTOCOL_ERROR
               }
            }, ""} = Frame.decode(frame, :ctx)
  end

  test "decoding an empty SETTINGS frame returns {:ok, [], <<>>}" do
    assert {:ok, [], <<>>} = Frame.decode(<<>>, :ctx)
  end

  test "decoding a SETTINGS frame" do
    frame = <<6::24, FrameTypes.settings::8, 1::8, 0::1, 15::31, 0x1::16, 4096::32>>
    assert {:ok,
            %Frame{
              length:    6,
              type:      0x4,
              stream_id: 15,
              flags:     %{ack: true},
              payload:   %Settings{
                settings: [
                  HEADER_TABLE_SIZE: 4096
                ]
              }
            }, ""} = Frame.decode(frame, :ctx)
  end

  test "decoding a WINDOW_UPDATE frame" do
    frame = <<4::24, FrameTypes.window_update::8, 0::8, 1::1, 0::31, 1::1, 10_000::31>>
    assert {:ok, %Frame{
               length: 4,
               type:   FrameTypes.window_update,
               stream_id: 0,
               payload: %WindowUpdate{
                 increment: 10_000
               }
            }, ""} = Frame.decode(frame, :ctx)
  end

end
