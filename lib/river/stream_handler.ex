defmodule River.StreamHandler do
  use River.FrameTypes
  alias River.{Response, Frame}

  def start_link(opts, cpid \\ nil) do
    case Agent.start_link(fn ->  {cpid, %Response{}} end, opts) do
      {:ok, pid} ->
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        {:ok, pid}
    end
  end

  def add_frame(pid, %Frame{}=frame) do
    Agent.cast(pid, fn({cpid, response}) ->
      case Response.add_frame(response, frame) do
        %Response{closed: true, __status: :error}=r ->
          message_and_close(pid, cpid, {:error, r})
          {cpid, r}
        %Response{closed: true}=r ->
          message_and_close(pid, cpid, {:ok, r})
          {cpid, r}
        r ->
          {cpid, r}
      end

      # {cpid, Response.add_frame(response, frame)}
    end)
  end

  def get_response(pid) do
    Agent.get(pid, fn({_cpid, response}) ->
      response
    end)
  end

  # kind of useless, but it prevents us from spreading
  # implementation logic outside of this module
  def stop(pid) do
    Agent.stop(pid)
  end

  defp message_and_close(pid, cpid, what) do
    case cpid do
      nil -> nil
      c   -> send(c, what)
    end

    # I don't really know the best way to clean up after ourselves here
    # I need to send a response to the concerned pid, and then stop myself
    # maybe these should be handled with cast calls...?
    spawn(fn()->
      River.StreamHandler.stop(pid)
    end)
  end
end
