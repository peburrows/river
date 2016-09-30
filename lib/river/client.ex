defmodule River.Client do
  alias River.{Request}

  def get(uri, timeout \\ 5_000)
  def get(%URI{} = uri, timeout) do
    {:ok, conn} = River.Conn.create(uri.host)
    River.Conn.request!(conn, %Request{uri: uri}, timeout)
  end
  def get(uri, timeout), do: get(URI.parse(uri), timeout)

  def put(uri, data, timeout \\ 5_000)
  def put(%URI{} = uri, data, timeout) do
    {:ok, conn} = River.Conn.create(uri.host)
    River.Conn.request!(conn, %Request{uri: uri, data: data, method: :put}, timeout)
  end
  def put(uri, data, timeout), do: put(URI.parse(uri), data, timeout)

  def post(uri, data, timeout \\ 5_000)
  def post(%URI{} = uri, data, timeout) do
    {:ok, conn} = River.Conn.create(uri.host)
    River.Conn.request!(%Request{method: :post, uri: uri, data: data}, timeout)
  end
  def post(uri, data, timeout), do: post(URI.parse(uri), data, timeout)
end
