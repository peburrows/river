defmodule River.Frame.WindowUpdateTest do
  use ExUnit.Case, async: true
  alias River.{Frame, Frame.WindowUpdate}

  test "we can decode a window update payload" do
    assert %Frame{
             payload: %WindowUpdate{
               increment: 100
             }
           } = WindowUpdate.decode(%Frame{}, <<1::1, 100::31>>)
  end

  test "an invalid payload reports as such" do
    assert {:error, :invalid_frame} = WindowUpdate.decode(%Frame{}, <<>>)
  end
end
