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
        %Response{closed: true}=r ->
          case cpid do
            nil -> nil
            c   -> send(c, {:ok, r})
          end
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
  def close(pid) do
    Agent.stop(pid)
  end
end
