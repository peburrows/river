defmodule River.Stream do
  require River.FrameTypes
  alias River.{Frame, Encoder, FrameTypes, Conn}

  @flow_control_increment 2_147_483_647 # the MAX!

  defstruct [
    id:       0,
    send_window: Conn.initial_window_size,
    recv_window: 0,
    conn:     %River.Conn{},
    listener: nil,
    state:    :idle,
    send_buffer: <<>>,
    frame_buffer: [],
  ]

  def recv_frame(stream, frame) do
    stream
    |> transition_state(frame)
    |> handle_flow_control(frame)
  end

  # send_frame seems cleaner than send_data, but we might need to do send_data
  # instead so that we can send as much data as the stream window allows (i.e a
  # partial payload) also, we need a better way to track the connection AND
  # stream flow windows and make sure we're keeping them in sync
  # maybe we do that by not passing data to a stream to send until the conn
  # has space to send? That seems hackish, although it would allow the conn to
  # manage stream priorities better: it could pass data to stream handlers
  # according to priority...
  def send_frame(%{send_window: window} = stream,
    %{type: FrameTypes.data, payload: %{data: data}} = frame) when byte_size(data) > window do

    %{stream | frame_buffer: stream.frame_buffer ++ [frame]}
  end
  def send_frame(%{send_window: window, conn: %{socket: socket}} = stream,
    %{type: FrameTypes.data, payload: %{data: data}} = frame) do

    do_send_frame(socket, frame)
    %{stream | send_window: window - byte_size(data)}
  end
  def send_frame(%{conn: %{socket: socket}} = stream, frame) do
    do_send_frame(socket, frame)
    # nothing changed
    stream
  end

  defp do_send_frame(nil, _), do: nil
  defp do_send_frame(socket, frame),
    do: :ssl.send(socket, Encoder.encode(frame))

  defp handle_flow_control(%{recv_window: window} = stream, %{type: FrameTypes.data, length: l} = frame),
    do: increment_flow_control(%{stream | recv_window: window - l}, frame)
  defp handle_flow_control(%{send_window: window} = stream, %{type: FrameTypes.window_update, payload: %{increment: inc}}),
    do: %{stream | send_window: window + inc}
  defp handle_flow_control(stream, _frame),
    do: stream

  defp increment_flow_control(%{recv_window: 0, id: id, conn: %{socket: socket}} = stream, _frame) do
    encoded = %Frame{
      type: FrameTypes.window_update,
      stream_id: id,
      payload: %Frame.WindowUpdate{
        increment: @flow_control_increment
      }
    } |> Encoder.encode

    case socket do
      nil ->
        stream
      _ ->
        :ssl.send(socket, encoded)
        stream
    end
  end

  defp increment_flow_control(stream, _frame),
    do: stream

  defp transition_state(%{state: :idle} = stream, %{type: FrameTypes.headers}),
    do: %{stream | state: :open}
  defp transition_state(%{state: :idle} = stream, %{type: FrameTypes.push_promise}),
    do: %{stream | state: :reserved}
  defp transition_state(%{state: :reserved} = stream, %{type: FrameTypes.headers}),
    do: %{stream | state: :half_closed}
  defp transition_state(%{state: :open} = stream, %{flags: %{end_stream: true}}),
    do: %{stream | state: :half_closed}
  defp transition_state(stream, %{type: FrameTypes.rst_stream}),
    do: %{stream | state: :closed}
  defp transition_state(stream, _),
    do: stream
end
