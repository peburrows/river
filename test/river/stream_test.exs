defmodule River.StreamTest do
  use ExUnit.Case, async: true

  test "we only start up one stream per unique name" do
    {:ok, pid} = River.Stream.start_link(name: TesterStream)
    assert {:ok, ^pid} = River.Stream.start_link(name: TesterStream)
  end
end
