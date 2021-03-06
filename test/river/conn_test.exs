defmodule River.ConnTest do
  use ExUnit.Case

  test "calling Connection.create multiple times only creates on conn" do
    {:ok, pid} = River.Conn.create("http2.golang.org")
    assert {:ok, ^pid} = River.Conn.create("http2.golang.org")
  end

  test "receiving a GOAWAY frame should cause the connection to close itself" do
    # {:ok, pid} = River.Connection.create("http2.golang.org")
  end
end
