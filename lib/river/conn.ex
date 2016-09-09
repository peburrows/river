defmodule River.Conn do
  # the name is confusing, but this is an external behaviour
  use Connection
  use Bitwise
  alias Experimental.DynamicSupervisor
  alias River.{Conn, Frame}

  @default_header_table_size 4096

  defstruct [
    host:      nil,
    protocol:  "h2",
    send_ctx:  nil,
    recv_ctx:  nil,
    buffer:    "",
    socket:    nil,
    stream_id: -1,
    streams:   0,
    settings:  [],
    server_settings: []
  ]

  def create(host, opts \\ []) do
    name = Keyword.get(opts, :name, :"conn-#{host}")

    DynamicSupervisor.start_child(
      River.ConnectionSupervisor,
      [host, [name: name]]
    )
  end

  def start_link(host, opts \\ []) do
    case Connection.start_link(__MODULE__, %Conn{host: host}, opts) do
      {:ok, pid} ->
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        {:ok, pid}
    end
  end

  def init(%Conn{host: host}=conn) do
    {:ok, send_ctx} = HPack.Table.start_link(@default_header_table_size)
    {:ok, recv_ctx} = HPack.Table.start_link(@default_header_table_size)

    conn = %{conn |
              send_ctx: send_ctx,
              recv_ctx: recv_ctx,
              settings: [
                MAX_CONCURRENT_STREAMS: 100,
                INITIAL_WINDOW_SIZE: 65535,
                HEADER_TABLE_SIZE: @default_header_table_size,
              ],
             }

    {:connect, :init, conn}
  end

  def get(pid, path, timeout \\ 5_000) do
    Connection.cast(pid, {:get, path, self})
    receive do
      {:ok, response} ->
        {:ok, response}
      other ->
        other
    after timeout -> # eventually, we need to customize the timeout
      {:error, :timeout}
    end
  end

  def connect(info, %Conn{host: host}=conn) do
    host = String.to_charlist(host)

    case :ssl.connect(host, 443, ssl_options(host)) do
      {:ok, socket} ->
        River.Frame.http2_header
        :ssl.send(socket, River.Frame.http2_header)

        frame = River.Frame.Settings.encode(conn.settings, 0)

        :ssl.send(socket, frame)
        {:ok, %{conn | socket: socket}}
      {:error, _} = error ->
        {:backoff, 1000, conn}
      other ->
        {:backoff, 1000, conn}
    end
  end

  def disconnect(info, %Conn{socket: socket}=conn) do
    # we need to disconnect from the ssl socket
    :ssl.close(socket)
    {:stop, :exit, conn}
  end

  def handle_cast({:get, path}, conn), do: handle_cast({:get, path, nil}, conn)
  def handle_cast({:get, path, parent}, conn) do
    # the problem here might be that this call will block until it fires
    # off the request, which is less than ideal. What we should do here is
    # spin up a RequestHandler of some sort to trigger it and handle things
    %{
      socket:    socket,
      host:      host,
      stream_id: stream_id,
      send_ctx:  ctx,
      streams:   streams
    } = conn

    stream_id = stream_id + 2

    {:ok, _} = DynamicSupervisor.start_child(River.StreamSupervisor, [[name: :"stream-#{host}-#{stream_id}"], parent])

    :ssl.setopts(socket, [active: true])

    headers = HPack.encode([
      {":method", "GET"},
      {":scheme", "https"},
      {":path", path},
      {":authority", host},
      {"accept", "*/*"},
      {"user-agent", "River/0.0.1"}
    ], ctx)


    f = River.Frame.encode(headers, stream_id, 0x1, (0x4 ||| 0x1))

    # IO.puts "#{IO.ANSI.green_background}#{Base.encode16(f, case: :lower)}#{IO.ANSI.reset}"

    :ssl.send(socket, f)
    {:noreply, %{conn | stream_id: stream_id, streams: streams+1 } }
  end

  def handle_info({:ssl, _, payload} = msg, conn) do
    %{
      recv_ctx: ctx,
      socket:   socket,
      buffer:   prev,
      host:     host,
    } = conn


    {new_conn, frames} = decode_frames(conn, prev <> payload, ctx, [])

    for f <- frames do
      {:ok, pid} = DynamicSupervisor.start_child(River.StreamSupervisor, [[name: :"stream-#{host}-#{f.stream_id}"]])

      River.StreamHandler.add_frame(pid, f)
    end

    {:noreply, new_conn}
  end

  defp decode_frames(conn, <<>>, _ctx, stack),
    do: {conn, Enum.reverse(stack)}

  defp decode_frames(conn, payload, ctx, stack) do
    case Frame.decode(payload, ctx) do
      {:ok, frame, more} ->
        decode_frames(conn, more, ctx, [frame | stack])
      {:error, :invalid_frame} ->
        { %{conn | buffer: payload}, Enum.reverse(stack) }
    end
  end

  def handle_info(msg, conn) do
    IO.puts "unhandled message: #{inspect msg}"
    {:noreply, conn}
  end

  defp ssl_options(host) do
    verify_fun = {(&:ssl_verify_hostname.verify_fun/3), [{:check_hostname, host}]}

    [
      :binary,
      {:packet, 0},
      {:active, false},
      {:verify, :verify_peer},
      {:depth, 99},
      {:cacerts, :certifi.cacerts()},
      {:alpn_advertised_protocols, ["h2", "http/1.1"]},
      {:verify_fun, verify_fun}
    ]
  end
end
