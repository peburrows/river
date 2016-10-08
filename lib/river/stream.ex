defmodule River.Stream do
  require River.FrameTypes
  alias River.{Frame, Encoder, FrameTypes}

  @flow_control_increment 2_147_483_647 # the MAX!

  defstruct [
    id:       0,
    send_window: 0,
    recv_window: 0,
    conn:     %River.Conn{},
    listener: nil,
    state:    :idle,
    send_buffer: <<>>,
  ]

  def recv_frame(stream, frame) do
    stream
    |> transition_state(frame)
    |> handle_flow_control(frame)
  end

  def send_data(%{send_window: 0} = stream, data) when is_binary(data) do
    %{stream | send_buffer: stream.send_buffer <> data}
  end

  def send_data(%{send_window: window} = stream, data)
  when is_binary(data) and byte_size(data) <= window do
    %{stream | send_window: stream.send_window - byte_size(data)}
  end

  def send_data(%{send_window: window} = stream, data) when is_binary(data) do
    # need to handle the to_send data...
    <<to_send::binary-size(window), rest::bitstring>> = data
    %{stream | send_window: 0}
    # |> do_send_data()
    |> send_data(rest)
  end

  # this is mostly here just for testing
  # defp do_send_data(%{conn: nil} = stream), do: stream
  # # need to make sure the connection has space on the window, too
  # defp do_send_data(%{conn: conn}, data)


  defp handle_flow_control(%{recv_window: window} = stream, %{type: FrameTypes.data, length: l} = frame),
    do: increment_flow_control(%{stream | recv_window: window - l}, frame)
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
