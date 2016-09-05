defmodule River.Client do
  def get(%URI{}=uri) do
    {:ok, conn} = River.Connection.create(uri.host)
    River.Connection.get(conn, uri.path)
  end
  def get(url), do: get(URI.parse(url))

  def post(%URI{}=uri, data) do
    {:ok, conn} = River.Connection.create(uri.host)
    River.Connection.post(conn, uri.path, data)
  end
  def post(url, data), do: post(URI.parse(url), data)

  def put(%URI{}=uri, data) do
    {:ok, conn} = River.Connection.create(uri.host)
    River.Connection.put(conn, uri.path, data)
  end
  def put(url, data), do: put(URI.parse(url), data)
end
