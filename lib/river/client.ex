defmodule River.Client do
  def get(uri, timeout \\ 5_000)
  def get(%URI{} = uri, timeout) do
    {:ok, conn} = River.Conn.create(uri.host)
    River.Conn.get(conn, uri.path, timeout)
  end
  def get(url, timeout), do: get(URI.parse(url), timeout)
end
