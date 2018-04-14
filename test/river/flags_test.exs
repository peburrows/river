defmodule River.FlagsTest do
  use ExUnit.Case, async: true
  require River.FrameTypes
  alias River.FrameTypes
  require Bitwise

  alias River.{Flags, Frame}

  test "extracting the ACK flag from a settings frame" do
    assert %{ack: true} == Flags.flags(FrameTypes.settings(), 0x1)
  end

  test "extracting the :END_STREAM flag from a data frame" do
    assert %{end_stream: true} == Flags.flags(FrameTypes.data(), 0x1)

    # data frames only have one valid flag, so make sure we ignore others
    assert %{end_stream: true} == Flags.flags(FrameTypes.data(), Bitwise.|||(0x1, 0x4))
  end

  test "extracting flags from a headers frame" do
    assert %{end_stream: true} == Flags.flags(FrameTypes.headers(), 0x1)

    assert %{end_stream: true, end_headers: true} ==
             Flags.flags(FrameTypes.headers(), Bitwise.|||(0x1, 0x4))

    assert %{priority: true, padded: true} ==
             Flags.flags(FrameTypes.headers(), Bitwise.|||(0x8, 0x20))
  end

  test "extracting flags from rst_stream frame" do
    assert %{} == Flags.flags(FrameTypes.rst_stream(), 0x1)
  end

  test "extracting flags from goaway frame" do
    assert %{} == Flags.flags(FrameTypes.goaway(), 0x1)
  end

  describe "encoding" do
    test "we can encode a single flag successfully" do
      assert 0x1 == Flags.encode(%{end_stream: true})
    end

    test "we can encode multiple flags" do
      assert 0x5 == Flags.encode(%{end_stream: true, end_headers: true})
    end

    test "encoding flags does not include flags set to false" do
      assert 0x1 == Flags.encode(%{end_stream: true, padded: false})
    end
  end

  describe "Flags.has_flag?" do
    test "returns the correct value when checking raw flag" do
      assert true == Flags.has_flag?(0x5, 0x1)
      assert true == Flags.has_flag?(0x5, 0x4)
      assert false == Flags.has_flag?(0x1, 0x4)
    end

    test "returns the correct value when checking a list of parsed flags" do
      assert true == Flags.has_flag?(%{end_stream: true}, :end_stream)
      assert true == Flags.has_flag?(%{end_headers: true}, :end_headers)
      assert false == Flags.has_flag?(%{end_stream: true}, :nope)
    end

    test "returns the correct value when checking a frame for flags" do
      assert true == Flags.has_flag?(%Frame{flags: %{end_stream: true}}, :end_stream)
      assert true == Flags.has_flag?(%Frame{flags: 0x1}, :end_stream)
      assert true == Flags.has_flag?(%Frame{flags: 0x5}, 0x1)
    end
  end
end
