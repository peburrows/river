defmodule River.Frame.RstStreamTest do
  use ExUnit.Case, async: true
  alias River.{Frame, Frame.RstStream}

  test "we can decode a single frame" do
    assert %Frame{
      payload: %RstStream{error: :PROTOCOL_ERROR}
    } = RstStream.decode(%Frame{}, <<0x1::32>>)
  end

  test "an incomplete frame reports as such" do
    assert {:error, :invalid_frame} = RstStream.decode(%Frame{}, <<>>)
  end
end
