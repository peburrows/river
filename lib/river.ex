defmodule River do
  use Application

  def start(_type, _args) do
    River.Supervisor.start_link()
  end
end
