defmodule River.Client do
  alias River.{Request}

  def get(uri, opts \\ [])
  def get(%URI{} = uri, opts) do
    {:ok, conn} = River.Conn.create(uri.host)
    opts = default_opts(opts)
    River.Conn.request!(conn, build_request(uri, :get, opts), opts.timeout)
  end
  def get(uri, opts), do: get(URI.parse(uri), opts)

  def put(uri, data, opts \\ [])
  def put(%URI{} = uri, data, opts) do
    {:ok, conn} = River.Conn.create(uri.host)
    opts = default_opts(opts)
    River.Conn.request!(conn, build_request(uri, :put, opts, data), opts.timeout)
  end
  def put(uri, data, opts), do: put(URI.parse(uri), data, opts)

  def post(uri, data, opts \\ [])
  def post(%URI{} = uri, data, opts) do
    {:ok, conn} = River.Conn.create(uri.host)
    opts = default_opts(opts)
    River.Conn.request!(conn, build_request(uri, :post, opts, data), opts.timeout)
  end
  def post(uri, data, opts), do: post(URI.parse(uri), data, opts)


  defp default_opts(opts) do
    Keyword.merge([
      timeout: 5_000,
      headers: [],
    ], opts) |> Enum.into(%{})
  end

  defp build_request(uri, method, opts, data \\ nil) do
    %Request{uri: uri, data: data, method: method}
    |> Request.add_headers(opts.headers)
  end
end
