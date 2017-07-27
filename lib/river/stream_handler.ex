defmodule River.StreamHandler do
  alias River.{Response, Frame, Stream, Conn}
  # alias Experimental.DynamicSupervisor

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    }
  end

  def get_pid(%{host: host} = conn, id, parent \\ nil) do
    # DynamicSupervisor.start_child(River.StreamSupervisor, [
    Supervisor.start_child(River.StreamSupervisor, [
          [name: :"stream-#{host}-#{id}"],
          %Stream{conn: conn, id: id, listener: parent, recv_window: Conn.initial_window_size}
        ])
  end

  def start_link(opts, %Stream{}=stream) do
    case Agent.start_link(fn -> {stream, %Response{}} end, opts) do
      {:ok, pid} ->
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        {:ok, pid}
    end
  end

  def recv_frame(pid, %Frame{} = frame) do
    Agent.cast(pid, fn({%{listener: cpid} = stream, response}) ->
      stream = Stream.recv_frame(stream, frame)
      case Response.add_frame(response, frame) do
        %Response{closed: true, __status: :error} = r ->
          message_and_close(pid, cpid, {:error, r})
          {stream, r}
        %Response{closed: true} = r ->
          message_and_close(pid, cpid, {:ok, r})
          {stream, r}
        r ->
          message(pid, cpid, {:frame, frame})
          {stream, r}
      end
    end)
  end

  def send_frame(pid, %Frame{} = frame) do
    Agent.cast(pid, fn({%{listener: cpid} = stream, response}) ->
      # how should we handle this here...?
      # this is why we need to handle
      stream = Stream.send_frame(stream, frame)
      {stream, response}
    end)
  end

  def get_response(pid) do
    Agent.get(pid, fn({_, response}) ->
      response
    end)
  end

  def get_stream(pid) do
    Agent.get(pid, fn({stream, _}) ->
      stream
    end)
  end

  def stop(pid), do: Agent.stop(pid)

  defp message(_pid, cpid, what) do
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
