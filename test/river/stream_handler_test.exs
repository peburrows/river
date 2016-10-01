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

    StreamHandler.add_frame(pid, %Frame{type: @data, payload: %Frame.Data{}})
    assert %Response{
      frames: [%Frame{}]
    } = StreamHandler.get_response(pid)
  end

  test "getting a frame with an :END_STREAM flag causes the handler to send a message" do
    {:ok, pid} = StreamHandler.start_link([], nil, self)
    StreamHandler.add_frame(pid, %Frame{type: @data, flags: %{end_stream: true}, payload: %Frame.Data{}})
    assert_receive {:ok, %Response{closed: true}}
  end

  test "getting a frame with an :END_STREAM flag causes the stream handler to stop itself" do
    {:ok, pid} = StreamHandler.start_link([], nil, self)
    StreamHandler.add_frame(pid, %Frame{type: @data, flags: %{end_stream: true}, payload: %Frame.Data{}})
    :timer.sleep(10)
    refute Process.alive?(pid)
  end

  test "getting a RST_STREAM frame causes the handler to send the error pack and stop itself" do
    {:ok, pid} = StreamHandler.start_link([], nil, self)
    StreamHandler.add_frame(pid, %Frame{type: @rst_stream, payload: %Frame.RstStream{error: 401}})
    assert_receive {:error, %Response{closed: true, code: 401}}
    :timer.sleep(10)
    refute Process.alive?(pid)
  end
end
