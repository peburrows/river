defmodule River.StreamTest do
  use ExUnit.Case, async: true
  require River.FrameTypes
  alias River.{Stream, Frame, FrameTypes}

  # not sure exactly what we ought to test here...
  test "a stream's initial state is :idle" do
    assert :idle == %Stream{}.state
  end

  describe "stream transitions" do
    test "from :idle to :open when it recieves headers" do
      stream =
        %Stream{}
        |> Stream.recv_frame(%Frame{type: FrameTypes.headers})
      assert :open == stream.state
    end

    test "from :idle to :reserved on push promise" do
      stream =
        %Stream{}
        |> Stream.recv_frame(%Frame{type: FrameTypes.push_promise})
      assert :reserved == stream.state
    end

    test "from :reserved to :half_closed on headers" do
      stream =
        %Stream{state: :reserved}
        |> Stream.recv_frame(%Frame{type: FrameTypes.headers})
      assert :half_closed == stream.state
    end

    test "from :open to :half_closed on end stream flag" do
      stream =
        %Stream{state: :open}
        |> Stream.recv_frame(%Frame{type: FrameTypes.headers, flags: %{end_stream: true}})
      assert :half_closed == stream.state
    end

    test "from :open to :closed on @rst_stream" do
      stream =
        %Stream{state: :open}
        |> Stream.recv_frame(%Frame{type: FrameTypes.rst_stream})
      assert :closed == stream.state
    end

    test "from :reserved to :closed on @rst_stream" do
      stream =
        %Stream{state: :reserved}
        |> Stream.recv_frame(%Frame{type: FrameTypes.rst_stream})
      assert :closed == stream.state
    end

    test "from :half_closed to :closed on @rst_stream" do
      stream =
        %Stream{state: :half_closed}
        |> Stream.recv_frame(%Frame{type: FrameTypes.rst_stream})
      assert :closed == stream.state
    end
  end

  describe "sending data" do
    test "attempting to send with a send window of 0 appends to the send_buffer" do
      stream = %Stream{send_window: 0, send_buffer: "xx"}
      data   = "hello world"
      stream = Stream.send_data(stream, data)
      assert "xx" <> data == stream.send_buffer
    end

    test "sending with room on the send window decrements the window" do
      stream = %Stream{send_window: 100}
      data = "hello world"
      stream = Stream.send_data(stream, data)
      assert <<>> == stream.send_buffer
      assert 89 == stream.send_window
    end

    test "sending more data than there is room in the send window moves the window to zero and puts the rest on the buffer" do
      stream = %Stream{send_window: 5}
      assert %Stream{
        send_buffer: ", Phil",
        send_window: 0
      } = Stream.send_data(stream, "howdy, Phil")
    end

    test "recieving a WINDOW_UPDATE frame increments the send window" do
      stream = %Stream{send_window: 5}
      assert %Stream{
        send_window: 15
      } = Stream.recv_frame(stream, %Frame{type: FrameTypes.window_update,
                                           payload: %Frame.WindowUpdate{
                                             increment: 10
                                           }})
    end
  end
end
