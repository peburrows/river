defmodule River.Stream do
  require River.FrameTypes
  alias River.{Frame, Encoder, FrameTypes}

  @flow_control_increment 2_147_483_647 # the MAX!

  defstruct [
    id:       0,
    window:   0,
    conn:     %River.Conn{},
    listener: nil,
    state:    :idle,
  ]

  def add_frame(stream, frame) do
    stream
    |> transition_state(frame)
    |> handle_flow_control(frame)
  end

  defp handle_flow_control(%{window: window} = stream, %{type: FrameTypes.data, length: l} = frame),
    do: increment_flow_control(%{stream | window: window - l}, frame)
  defp handle_flow_control(stream, _frame),
    do: stream

  defp increment_flow_control(%{window: 0, id: id, conn: %{socket: socket}} = stream, _frame) do
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

  defp increment_flow_control(stream, _frame), do: stream

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
