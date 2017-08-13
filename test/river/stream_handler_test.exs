defmodule River.StreamHandlerTest do
  use ExUnit.Case, async: true
  require River.FrameTypes
  alias River.{StreamHandler, Response, Frame, Stream, FrameTypes}

  test "we only start up one stream per unique name" do
    # {:ok, pid} = StreamHandler.start_link(name: TesterStream)
    assert {:ok, pid} = StreamHandler.start_link([name: TesterStream], %Stream{})
    assert {:ok, ^pid} = StreamHandler.start_link([name: TesterStream], %Stream{})
  end

  describe "adding a frame" do
    setup do
      {:ok, handler} = StreamHandler.start_link([], %Stream{})
      {:ok, %{handler: handler}}
    end

    test "adds it to the response's frame list", %{handler: pid} do
      assert %Response{frames: []} = StreamHandler.get_response(pid)

      StreamHandler.recv_frame(pid, %Frame{type: FrameTypes.data, payload: %Frame.Data{}})
      assert %Response{
        frames: [%Frame{}]
      } = StreamHandler.get_response(pid)
    end

    test "transitions the state of the stream", %{handler: handler} do
      StreamHandler.recv_frame(handler, %Frame{type: FrameTypes.headers, payload: %Frame.Headers{}})
      assert %Stream{state: :open} = StreamHandler.get_stream(handler)
    end
  end

  test "getting a frame with an :END_STREAM flag causes the handler to send a message" do
    {:ok, pid} = StreamHandler.start_link([], %Stream{listener: self()})
    StreamHandler.recv_frame(pid, %Frame{type: FrameTypes.data, flags: %{end_stream: true}, payload: %Frame.Data{}})
    assert_receive {:ok, %Response{closed: true}}
  end

  test "getting a frame with an :END_STREAM flag causes the stream handler to stop itself" do
    {:ok, pid} = StreamHandler.start_link([], %Stream{listener: self()})
    StreamHandler.recv_frame(pid, %Frame{type: FrameTypes.data, flags: %{end_stream: true}, payload: %Frame.Data{}})
    :timer.sleep(10)
    refute Process.alive?(pid)
  end

  test "getting a RST_STREAM frame causes the handler to send the error pack and stop itself" do
    {:ok, pid} = StreamHandler.start_link([], %Stream{listener: self()})
    StreamHandler.recv_frame(pid, %Frame{type: FrameTypes.rst_stream, payload: %Frame.RstStream{error: 401}})
    assert_receive {:error, %Response{closed: true, code: 401}}
    :timer.sleep(10)
    refute Process.alive?(pid)
  end
end
