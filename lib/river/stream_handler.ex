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
      {cpid, Response.add_frame(response, frame)}
    end)
  end

  def get_response(pid) do
    Agent.get(pid, fn({_cpid, response}) ->
      response
    end)
  end

  # check to see if this is the end of the stream
  # if it is, we need to notify the cpid and close this
  # stream handler
  defp end_stream?(frame) do
    Enum.any?(frame.flags, :END_STREAM)
  end

  # kind of useless, but it prevents us from spreading
  # implementation logic outside of this module
  def close(pid) do
    Agent.stop(pid)
  end
end
