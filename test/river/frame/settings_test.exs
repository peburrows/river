defmodule River.Frame.SettingsTest do
  use ExUnit.Case, async: true
  alias River.Frame.Settings

  test "an empty payload decodes to an empty list" do
    # no real need for the context here, so just pass it as nil
    assert {[], nil} = Settings.decode(<<>>, nil)
  end

  test "a payload with a few settings decodes the values properly" do
    payload = <<0, 5, 0, 16, 0, 0, 0, 3, 0, 0, 0, 250, 0, 6, 0, 16, 1, 64>>
    assert Settings.decode(payload, nil) == {[
      MAX_HEADER_LIST_SIZE: 1048896,
      MAX_CONCURRENT_STREAMS: 250,
      MAX_FRAME_SIZE: 1048576
    ], nil}
  end

  test "encoding settings frame payload" do
    assert <<0x3::16, 100::32, 0x5::16, 4096::32>> =
      Settings.encode_payload([
        MAX_CONCURRENT_STREAMS: 100,
        MAX_FRAME_SIZE: 4096
      ])
  end

  test "encoding settings as a full frame" do
    assert <<12::24, 0x4::8, 0::8, 0::1, 1::31,
      0x3::16, 100::32, 0x5::16, 4096::32>> =
      Settings.encode([
        MAX_CONCURRENT_STREAMS: 100,
        MAX_FRAME_SIZE: 4096
      ], 1)
  end
end
