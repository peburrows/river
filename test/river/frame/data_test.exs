defmodule River.Frame.DataTest do
  use ExUnit.Case, async: true
  # alias River.Frame.Data, as: DataFrame

  # test "we can extract a data frame properly" do
  #   payload = "world"
  #   frame = <<byte_size(payload)::24, 0x0::8, 0x1::8, 0::1, 1::31>> <> payload

  #   assert {:ok, %DataFrame{
  #              __padding: "",
  #              flags:     [:END_STREAM],
  #              stream_id: 1,
  #              payload:   ^payload
  #           }} = DataFrame.decode(frame)
  # end
end
