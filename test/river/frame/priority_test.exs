defmodule River.Frame.PriorityTest do
  use ExUnit.Case, async: true
  alias River.{Frame, Frame.Priority}

  test "we can extract a frame from a payload" do
    assert %Frame{
      payload: %Priority{
        exclusive: true,
        stream_dependency: 15,
        weight: 10
      }
    } = Priority.decode(%Frame{length: 5}, <<1::1, 15::31, 9::8>>) # add one to the weight value to get a value 1-256
  end

  test "an incomplete frame reports as such" do
    assert {:error, :invalid_frame} = Priority.decode(%Frame{}, <<>>)
  end
end
