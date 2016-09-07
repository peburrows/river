defmodule River.Frame.PingTest do
  use ExUnit.Case, async: true
  alias River.Frame.{Ping}

  test "we can decode a single ping frame" do
    payload = <<1337::64>>
    assert {:ok,
            %Ping{payload: ^payload}
    } = Ping.decode(payload)
  end
end
