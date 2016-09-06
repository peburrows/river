defmodule River.Client do
  def get(uri, timeout \\ 5000)
  def get(%URI{}=uri, timeout) do
    {:ok, conn} = River.Conn.create(uri.host)
    IO.puts "we are getting: #{uri.host} :: #{inspect conn}"
    River.Conn.get(conn, uri.path, timeout)
  end
  def get(url, timeout), do: get(URI.parse(url), timeout)

  def post(%URI{}=uri, data) do
    {:ok, conn} = River.Conn.create(uri.host)
    River.Conn.post(conn, uri.path, data)
  end
  def post(url, data), do: post(URI.parse(url), data)

  def put(%URI{}=uri, data) do
    {:ok, conn} = River.Conn.create(uri.host)
    River.Conn.put(conn, uri.path, data)
  end
  def put(url, data), do: put(URI.parse(url), data)
end
