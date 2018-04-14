defmodule River do
  use Application
  alias River.Client

  defdelegate get(uri, opts \\ []), to: Client
  defdelegate put(uri, data, opts \\ []), to: Client
  defdelegate post(uri, data, opts \\ []), to: Client
  defdelegate delete(uri, opts \\ []), to: Client
  defdelegate request(uri, opts), to: Client

  def start(_type, _args), do: River.Supervisor.start_link()

  def version, do: River.Mixfile.project()[:version]
end
