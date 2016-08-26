defmodule River.ConnectionTest do
  use ExUnit.Case

  test "calling Connection.create multiple times only creates on conn" do
    {:ok, pid} = River.Connection.create("http2.golang.org")
    assert {:ok, ^pid} = River.Connection.create("http2.golang.org")
  end
end
