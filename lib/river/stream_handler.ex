defmodule River.StreamHandler do
  use River.FrameTypes
  alias River.{Response, Frame, Frame.WindowUpdate, Encoder, Stream}

  @flow_control_increment     2_147_483_647 # the MAX!

  def start_link(opts, %Stream{}=stream) do
    case Agent.start_link(fn -> {stream, %Response{}} end, opts) do
      {:ok, pid} ->
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        {:ok, pid}
    end
  end

  def add_frame(pid, %Frame{} = frame) do
    Agent.cast(pid, fn({%{listener: cpid, window: window, conn: %{socket: socket}}=stream, response}) ->
      stream = handle_flow_control(stream, frame)
      # {window, socket} = handle_flow_control(window, frame, socket)
      case Response.add_frame(response, frame) do
        %Response{closed: true, __status: :error} = r ->
          message_and_close(pid, cpid, {:error, r})
          {stream, r}
        %Response{closed: true} = r ->
          message_and_close(pid, cpid, {:ok, r})
          {stream, r}
        r ->
          message(pid, cpid, {:data})
          {stream, r}
      end
    end)
  end

  def get_response(pid) do
    Agent.get(pid, fn({_, response}) ->
      response
    end)
  end

  # kind of useless, but it prevents us from spreading
  # implementation logic outside of this module
  def stop(pid),
    do: Agent.stop(pid)

  defp handle_flow_control(%{window: window} = stream, %{type: @data, length: l} = frame) do
    increment_flow_control(%{stream | window: window - l}, frame)
  end

  defp handle_flow_control(stream, _frame),
    do: stream

  defp increment_flow_control(%{window: 0, id: id, conn: %{socket: socket}} = stream, %{type: @data}) do
    encoded = %Frame{
      type: @window_update,
      stream_id: id,
      payload: %WindowUpdate{
        increment: @flow_control_increment
      }
    } |> Encoder.encode

    case socket do
      nil ->
        stream
      _   ->
        :ssl.send(socket, encoded)
        stream
    end
  end

  defp increment_flow_control(stream, _),
    do: stream

  defp message(pid, cpid, what) do
    case cpid do
      nil -> nil
      c   -> send(c, what)
    end
  end

  defp message_and_close(pid, cpid, what) do
    message(pid, cpid, what)
    # I don't really know the best way to clean up after ourselves here
    # I need to send a response to the concerned pid, and then stop myself
    # maybe these should be handled with cast calls...?
    spawn(fn() ->
      River.StreamHandler.stop(pid)
    end)
  end
end
