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
      SETTINGS_MAX_HEADER_LIST_SIZE: 1048896,
      SETTINGS_MAX_CONCURRENT_STREAMS: 250,
      SETTINGS_MAX_FRAME_SIZE: 1048576
    ], nil}
  end
end
