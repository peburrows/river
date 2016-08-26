defmodule River.FrameTest do
  use ExUnit.Case, async: true
  alias River.Frame

  test "the http2 header is correct" do
    assert Frame.http2_header() ==
           <<0x505249202a20485454502f322e300d0a0d0a534d0d0a0d0a::192>>
  end

  test "decoding an empty frame returns the context and no frames" do
    assert {:ok, [], :ctx} = Frame.decode_frames(<<>>, :ctx)
  end

  test "decoding a single frame returns a single frame" do
    data = <<0::24, 4::8, 1::8, 0::1, 15::31>>
    assert {:ok,
            [%Frame{
                length: 0,
                type:   0x4,
                flags: [:ACK],
                stream_id: 15,
                payload: ""
             }],
            _} = Frame.decode_frames(data, :ctx)
  end
end
