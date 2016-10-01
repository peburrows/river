defmodule River.StreamHandler do
  use River.FrameTypes
  alias River.{Response, Frame, Frame.WindowUpdate, Encoder}

  @intial_flow_control_window 65_535
  @flow_control_increment     100_000

  def start_link(opts, socket \\ nil, cpid \\ nil) do
    case Agent.start_link(fn ->  {cpid, socket, 65_353, %Response{}} end, opts) do
      {:ok, pid} ->
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        {:ok, pid}
    end
  end

  def add_frame(pid, %Frame{} = frame) do
    Agent.cast(pid, fn({cpid, socket, window, response}) ->
      {window, socket} = handle_flow_control(window, frame, socket)
      case Response.add_frame(response, frame) do
        %Response{closed: true, __status: :error} = r ->
          message_and_close(pid, cpid, {:error, r})
          {cpid, socket, window, r}
        %Response{closed: true} = r ->
          message_and_close(pid, cpid, {:ok, r})
          {cpid, socket, window, r}
        r ->
          message(pid, cpid, {:data})
          {cpid, socket, window, r}
      end
    end)
  end

  def get_response(pid) do
    Agent.get(pid, fn({_cpid, _socket, _window, response}) ->
      response
    end)
  end

  # kind of useless, but it prevents us from spreading
  # implementation logic outside of this module
  def stop(pid) do
    Agent.stop(pid)
  end

  defp handle_flow_control(window, %{type: @data}=frame, nil) do
    window = window - frame.length
    window = if window <= 0 do
      window + @flow_control_increment
    else
      window
    end
    {window, nil}
  end

  defp handle_flow_control(window, %{type: @data}=frame, socket) do
    ["the window", window, frame.length] |> IO.inspect
    new_window = window - frame.length
    window = if new_window <= 0 do
      IO.puts "we are out of room"
      encoded_frame = %River.Frame{
        type: @window_update,
        stream_id: frame.stream_id,
        payload: %WindowUpdate{
          increment: @flow_control_increment,
        }
      } |> Encoder.encode
      :ssl.send(socket, encoded_frame)
      window = new_window + @flow_control_increment
    else
      new_window
    end

    {window, socket}
  end

  defp handle_flow_control(window, _, socket), do: {window, socket}

  defp message(pid, cpid, what) do
    IO.inspect ["the concerned pid:", cpid]
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
