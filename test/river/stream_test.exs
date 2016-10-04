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
        |> Stream.add_frame(%Frame{type: FrameTypes.headers})
      assert :open == stream.state
    end

    test "from :idle to :reserved on push promise" do
      stream =
        %Stream{}
        |> Stream.add_frame(%Frame{type: FrameTypes.push_promise})
      assert :reserved == stream.state
    end

    test "from :reserved to :half_closed on headers" do
      stream =
        %Stream{state: :reserved}
        |> Stream.add_frame(%Frame{type: FrameTypes.headers})
      assert :half_closed == stream.state
    end

    test "from :open to :half_closed on end stream flag" do
      stream =
        %Stream{state: :open}
        |> Stream.add_frame(%Frame{type: FrameTypes.headers, flags: %{end_stream: true}})
      assert :half_closed == stream.state
    end

    test "from :open to :closed on @rst_stream" do
      stream =
        %Stream{state: :open}
        |> Stream.add_frame(%Frame{type: FrameTypes.rst_stream})
      assert :closed == stream.state
    end

    test "from :reserved to :closed on @rst_stream" do
      stream =
        %Stream{state: :reserved}
        |> Stream.add_frame(%Frame{type: FrameTypes.rst_stream})
      assert :closed == stream.state
    end

    test "from :half_closed to :closed on @rst_stream" do
      stream =
        %Stream{state: :half_closed}
        |> Stream.add_frame(%Frame{type: FrameTypes.rst_stream})
      assert :closed == stream.state
    end
  end

end
