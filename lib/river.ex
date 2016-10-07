defmodule River do
  use Application

  def start(_type, _args),
    do: River.Supervisor.start_link()

  def version,
    do: River.Mixfile.project[:version]
end
