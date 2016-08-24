defmodule River.Stream do
  use River.FrameTypes
  alias River.Response

  def start_link(opts \\ []) do
    case Agent.start_link(fn -> %Response{} end, opts) do
      {:ok, pid} ->
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        {:ok, pid}
    end
  end

  def add_frame(pid, %{type: @data, payload: payload}=frame) do
    Agent.cast(pid, fn(response) ->
      %{response | body:   response.body <> payload,
                   frames: [frame|response.frames]}
    end)
  end

  def add_frame(pid, %{type: @headers, payload: payload}=frame) do
    Agent.cast(pid, fn(response) ->
      %{response | headers: [payload|response.headers],
                   frames:  [frame|response.frames]}
    end)
  end

  def add_frame(pid, frame) do
    Agent.cast(pid, fn(response) ->
      %{response | frames: [frame|response.frames]}
    end)
  end

  def get_response(pid) do
    Agent.get(pid, fn(response) ->
      %{response | frames:  Enum.reverse(response.frames),
                   headers: Enum.reverse(response.headers)}
    end)
  end
end
