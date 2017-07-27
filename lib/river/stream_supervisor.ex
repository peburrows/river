defmodule River.StreamSupervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    [Supervisor.child_spec({River.StreamHandler, []}, restart: :transient)]
    |> Supervisor.init(strategy: :simple_one_for_one)
  end
end
