defmodule River.Frame.SettingsTest do
  use ExUnit.Case, async: true
  use River.FrameTypes
  alias River.{Frame, Frame.Settings}

  # test "an empty payload decodes to an empty list" do
  #   assert %Frame{
  #     payload: %Settings{
  #       settings: []
  #     }
  #   } = Settings.decode(%Frame{}, <<>>)
  # end

  # test "a payload with a few settings decodes the values properly" do
  #   payload = <<0x6::16, 1048896::32, 0x3::16, 250::32, 0x5::16, 1048576::32>>
  #   assert %Frame{
  #     payload: %Settings{
  #       settings: [
  #         MAX_HEADER_LIST_SIZE: 1048896,
  #         MAX_CONCURRENT_STREAMS: 250,
  #         MAX_FRAME_SIZE: 1048576
  #       ]
  #     }
  #   } = Settings.decode(%Frame{}, payload)
  # end

  # test "encoding settings frame payload" do
  #   assert <<0x3::16, 100::32, 0x5::16, 4096::32>> =
  #     Settings.encode_payload([
  #       MAX_CONCURRENT_STREAMS: 100,
  #       MAX_FRAME_SIZE: 4096
  #     ])
  # end

  # test "encoding settings as a full frame" do
  #   assert <<12::24, 0x4::8, 0::8, 0::1, 1::31,
  #     0x3::16, 100::32, 0x5::16, 4096::32>> =
  #     River.Encoder.encode(%Frame{
  #           type: @settings,
  #           payload: %Settings{
  #             settings: [
  #               MAX_CONCURRENT_STREAMS: 100,
  #               MAX_FRAME_SIZE: 4096
  #             ]
  #           }})
  # end
end
