defmodule River.Frame.RstStreamTest do
  use ExUnit.Case, async: true
  alias River.Frame.{RstStream}

  test "we can decode a single frame" do
    assert {:ok,
            %RstStream{error: :PROTOCOL_ERROR}
    } = RstStream.decode(<<0x1::32>>)
  end

  test "an incomplete frame reports as such" do
    assert {:error, :incomplete_frame} = RstStream.decode(<<>>)
  end
end
