defmodule River.StreamHandlerTest do
  use ExUnit.Case, async: true
  use River.FrameTypes
  alias River.{StreamHandler, Response, Frame}

  test "we only start up one stream per unique name" do
    {:ok, pid} = StreamHandler.start_link(name: TesterStream)
    assert {:ok, ^pid} = StreamHandler.start_link(name: TesterStream)
  end

  test "adding a frame adds to the response's frame list" do
    {:ok, pid} = StreamHandler.start_link([])
    assert %Response{frames: []} = StreamHandler.get_response(pid)

    StreamHandler.add_frame(pid, %Frame{type: @data})
    assert %Response{
      frames: [%Frame{}]
    } = StreamHandler.get_response(pid)
  end

  test "getting a frame with an :END_STREAM flag causes the handler to send a message" do
    {:ok, pid} = StreamHandler.start_link([], self)
    StreamHandler.add_frame(pid, %Frame{type: @data, flags: 0x1})

    assert_receive {:ok, %Response{}}
  end
end
