defmodule River.Frame.PingTest do
  use ExUnit.Case, async: true
  alias River.{Frame, Frame.Ping}

  test "we can decode a single ping frame" do
    payload = <<1337::64>>
    assert %Frame{
            payload: %Ping{payload: ^payload}
    } = Ping.decode(%Frame{length: 8}, payload)
  end
end
