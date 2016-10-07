defmodule River.StreamHandler do
  alias River.{Response, Frame, Stream}

  def start_link(opts, %Stream{}=stream) do
    case Agent.start_link(fn -> {stream, %Response{}} end, opts) do
      {:ok, pid} ->
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        {:ok, pid}
    end
  end

  def add_frame(pid, %Frame{} = frame) do
    Agent.cast(pid, fn({%{listener: cpid} = stream, response}) ->
      stream = Stream.add_frame(stream, frame)
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

  # kind of useless, but it prevents us from spreading
  # implementation logic outside of this module
  def stop(pid),
    do: Agent.stop(pid)

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
