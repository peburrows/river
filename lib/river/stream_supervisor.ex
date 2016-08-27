defmodule River.StreamSupervisor do
  alias Experimental.DynamicSupervisor
  use DynamicSupervisor

  def start_link() do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    children = [
      worker(River.StreamHandler, [], restart: :transient)
    ]
    {:ok, children, strategy: :one_for_one}
  end
end
