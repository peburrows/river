defmodule River.FlagsTest do
  use ExUnit.Case, async: true
  use River.FrameTypes
  require Bitwise

  alias River.Flags

  test "extracting the ACK flag from a settings frame" do
    assert [:ACK] == Flags.flags(@settings, 0x1)
  end

  test "extracting the :END_STREAM flag from a data frame" do
    assert [:END_STREAM] == Flags.flags(@data, 0x1)

    # data frames only have on valid flag, so ignore others
    assert [:END_STREAM] == Flags.flags(@data, Bitwise.|||(0x1, 0x4) )
  end

  test "extracting flags from a headers frame" do
    assert [:END_STREAM] == Flags.flags(@headers, 0x1)
    assert [:END_HEADERS, :END_STREAM] == Flags.flags(@headers, Bitwise.|||(0x1, 0x4))
    assert [:PRIORITY, :PADDED] == Flags.flags(@headers, Bitwise.|||(0x8, 0x20))
  end
end
