defmodule River.Frame.GoAwayTest do
  use ExUnit.Case, async: true
  alias River.Frame.{GoAway}

  test "we can decode a go away payload" do
    assert {:ok,
            %GoAway{
              last_stream_id: 15,
              error: :PROTOCOL_ERROR
            }
    } = GoAway.decode(<<1::1, 15::31, 0x1::32>>)
  end

  test "we can extract debug data from a goaway payload if it exists" do
    assert {:ok,
            %GoAway{
              last_stream_id: 13,
              error: :FRAME_SIZE_ERROR,
              debug: "hello world"
            }
    } = GoAway.decode(<<1::1, 13::31, 0x6::32>> <> "hello world")
  end
end
