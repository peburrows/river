defmodule River.FlagsTest do
  use ExUnit.Case, async: true
  use River.FrameTypes
  require Bitwise

  alias River.{Flags, Frame}

  test "extracting the ACK flag from a settings frame" do
    assert [:ACK] == Flags.flags(@settings, 0x1)
  end

  test "extracting the :END_STREAM flag from a data frame" do
    assert [:END_STREAM] == Flags.flags(@data, 0x1)

    # data frames only have one valid flag, so make sure we ignore others
    assert [:END_STREAM] == Flags.flags(@data, Bitwise.|||(0x1, 0x4) )
  end

  test "extracting flags from a headers frame" do
    assert [:END_STREAM] == Flags.flags(@headers, 0x1)
    assert [:END_HEADERS, :END_STREAM] == Flags.flags(@headers, Bitwise.|||(0x1, 0x4))
    assert [:PRIORITY, :PADDED] == Flags.flags(@headers, Bitwise.|||(0x8, 0x20))
  end

  test "extracting flags from rst_stream frame" do
    assert [] == Flags.flags(@rst_stream, 0x1)
  end

  test "extracting flags from goaway frame" do
    assert [] == Flags.flags(@goaway, 0x1)
  end

  describe "Flags.has_flag?" do
    test "returns the correct value when checking raw flag" do
      assert true  == Flags.has_flag?(0x5, 0x1)
      assert true  == Flags.has_flag?(0x5, 0x4)
      assert false == Flags.has_flag?(0x1, 0x4)
    end

    test "returns the correct value when checking a list of parsed flags" do
      assert true  == Flags.has_flag?([:END_STREAM], :END_STREAM)
      assert true  == Flags.has_flag?([:END_HEADERS], :END_HEADERS)
      assert false == Flags.has_flag?([:END_STREAM], :NOPE)
    end

    test "returns the correct value when checking a frame for flags" do
      assert true  == Flags.has_flag?(%Frame{flags: [:END_STREAM]}, :END_STREAM)
      assert true  == Flags.has_flag?(%Frame{flags: 0x5}, 0x1)
    end
  end
end
