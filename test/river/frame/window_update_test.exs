defmodule River.Frame.WindowUpdateTest do
  use ExUnit.Case, async: true
  alias River.Frame.{WindowUpdate}

  test "we can decode a window update payload" do
    assert {:ok,
            %WindowUpdate{
              increment: 100
            }
    } = WindowUpdate.decode(<<1::1, 100::31>>)
  end
end
