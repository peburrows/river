defmodule River.Frame.GoAwayTest do
  use ExUnit.Case, async: true
  alias River.{Frame, Frame.GoAway}

  test "we can decode a go away payload" do
    assert %Frame{
             payload: %GoAway{
               last_stream_id: 15,
               error: :PROTOCOL_ERROR
             }
           } = GoAway.decode(%Frame{length: 8}, <<1::1, 15::31, 0x1::32>>)
  end

  test "we can extract debug data from a goaway payload if it exists" do
    assert %Frame{
             length: 19,
             payload: %GoAway{
               last_stream_id: 13,
               error: :FRAME_SIZE_ERROR,
               debug: "hello world"
             }
           } = GoAway.decode(%Frame{length: 19}, <<1::1, 13::31, 0x6::32>> <> "hello world")
  end
end
