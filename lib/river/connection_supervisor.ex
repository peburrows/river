defmodule River.ConnectionSupervisor do
  alias Experimental.DynamicSupervisor
  use DynamicSupervisor

  def start_link do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    children = [
      worker(River.Connection, [], restart: :transient)
    ]
    {:ok, children, strategy: :one_for_one}
  end
end
