defmodule River.Client do
  alias River.{Request}

  def get(uri, opts \\ [])
  def get(%URI{} = uri, opts) do
    do_request(uri, default_opts(:get, opts))
  end
  def get(uri, opts) when is_binary(uri),
    do: get(URI.parse(uri), opts)

  def put(uri, data, opts \\ [])
  def put(%URI{} = uri, data, opts) do
    do_request(uri, default_opts(:put, opts, data))
  end
  def put(uri, data, opts) when is_binary(uri),
    do: put(URI.parse(uri), data, opts)

  def post(uri, data, opts \\ [])
  def post(%URI{} = uri, data, opts) do
    do_request(uri, default_opts(:post, opts, data))
  end
  def post(uri, data, opts) when is_binary(uri),
    do: post(URI.parse(uri), data, opts)

  def delete(uri, opts \\ [])
  def delete(%URI{} = uri, opts) do
    do_request(uri, default_opts(:delete, opts))
  end
  def delete(uri, opts) when is_binary(uri),
    do: delete(URI.parse(uri), opts)

  def request(%URI{} = uri, opts) when is_list(opts),
    do: do_request(uri, opts)
  def request(uri, opts) when is_binary(uri),
    do: request(URI.parse(uri), opts)

  # private

  defp do_request(%URI{} = uri, opts) do
    with {:ok, req} <- Request.new(uri, opts.method, opts.data, opts.headers),
         {:ok, conn} <- River.Conn.create(uri.host, uri.port)
    do
      River.Conn.request!(conn, req, opts.timeout)
    end
  end

  defp default_opts(opts) do
    Keyword.merge([
      timeout: 5_000,
      headers: []
    ], opts) |> Enum.into(%{})
  end

  defp default_opts(method, opts, data \\ nil) do
    Keyword.merge([
      method:  method,
      data:    data
    ], opts) |> default_opts()
  end
end
