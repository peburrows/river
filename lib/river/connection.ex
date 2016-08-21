defmodule River.Connection do
  defmodule Stream.Supervisor do
    alias Experimental.DynamicSupervisor
    use DynamicSupervisor

    def start_link(opts) do
      DynamicSupervisor.start_link(__MODULE__, [], opts)
    end

    def init() do
      children = [
        worker(River.StreamHandler, [])
      ]
      {:ok, children, strategy: :one_for_one}
    end
  end

  require Bitwise
  use GenServer

  def start_link(host, opts \\ []) do
    GenServer.start_link(__MODULE__, [host: host], opts)
  end

  def init([host: host]) do
    # connect to the server, of course
    {:ok, ctx} = HPack.Table.start_link(1_000)
    {:ok, %{
        stream_id: 0,
        host:      host,
        socket:    connect!(host),
        ctx:       ctx,
     }}
  end

  # when we make a request, we need to spin up a new GenServer to handle this stream
  def handle_cast({:get, path}, state) do
    %{ctx: ctx, socket: socket, host: host, stream_id: stream_id} = state
    :ssl.setopts(socket, [active: true])

    headers = HPack.encode([
      {":method", "GET"},
      {":scheme", "https"},
      {":path", path},
      {":authority", host},
      {"accept", "*/*"},
      {"user-agent", "River/0.0.1"}
    ], ctx)

    f = River.Frame.encode(headers, stream_id+1, 0x1, Bitwise.|||(0x4, 0x1))
    IO.puts "the headers: #{inspect f}"

    :ssl.send(socket, f)
    {:noreply, %{state | stream_id: stream_id+1} }
  end

  def handle_info({:ssl, _, payload} = msg, state) do
    %{ctx: ctx, socket: socket} = state
    River.Frame.decode(payload, ctx, socket)
    {:noreply, state}
  end

  def handle_info(msg, state) do
    IO.puts "unhandled message: #{inspect msg}"
    {:noreply, state}
  end

  defp connect!(host) do
    host = String.to_charlist(host)
    verify_fun = {(&:ssl_verify_hostname.verify_fun/3), [{:check_hostname, host}]}
    certs = :certifi.cacerts()
    opts = [
      :binary,
      {:packet, 0},
      {:active, false},
      {:verify, :verify_peer},
      {:depth, 99},
      {:cacerts, certs},
      {:alpn_advertised_protocols, ["h2", "http/1.1"]},
      {:verify_fun, verify_fun}
    ]

    {:ok, socket} = :ssl.connect(host, 443, opts)
    :ssl.send(socket, "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n")
    frame = River.Frame.encode(<<0x3::size(16), 100::size(32), 0x4::size(16), 65535::size(32)>>, 0, 0x4)
    :ssl.send(socket, frame)
    socket
  end
end
