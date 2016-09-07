defmodule River.Frame.PriorityTest do
  use ExUnit.Case, async: true
  alias River.Frame.{Priority}

  test "we can extract a frame from a payload" do
    assert {:ok,
            %Priority{exclusive: true, stream_dependency: 15, weight: 10}
    } = Priority.decode(<<1::1, 15::31, 9::8>>) # add one to the weight value to get a value 1-256
  end

  test "an incomplete frame reports as such" do
    assert {:error, :incomplete_frame} = Priority.decode(<<>>)
  end
end
