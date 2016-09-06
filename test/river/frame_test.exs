defmodule River.FrameTest do
  use ExUnit.Case, async: true
  alias River.Frame

  test "the http2 header is correct" do
    assert Frame.http2_header() ==
           <<0x505249202a20485454502f322e300d0a0d0a534d0d0a0d0a::192>>
  end

  test "encoding a simple frame" do
    stream_id = 123
    assert <<5::size(24),
      0x4::size(8),
      _flags::size(8),
      0::size(1), ^stream_id::size(31),
      "hello">> = River.Frame.encode("hello", stream_id, 0x4)
  end

  test "decoding an empty frame returns {:ok, []}" do
    assert {:ok, []} = Frame.decode_frames(<<>>, :ctx)
  end

  test "decoding a single frame returns a single frame" do
    data = <<0::24, 4::8, 1::8, 0::1, 15::31>>
    assert {:ok,
            [%Frame{
                length: 0,
                type:   0x4,
                flags: [:ACK],
                stream_id: 15,
                payload: []
             }]
           } = Frame.decode_frames(data, :ctx)
  end

  # test "decoding a frame respects padding" do
  #   payload = "hello"
  #   padding = "world"
  #   data = <<byte_size(payload <> padding)::24, 0::8, 0x8::8, payload::binary, padding::binary>>

  #   assert {:ok, [%Frame{
  #     payload: ^payload,
  #     flags:   [:PADDED]
  #   }]} = Frame.decode_frames(data, nil)
  # end
end
