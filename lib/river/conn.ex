defmodule River.Conn do
  # the name is confusing, but this is an external behaviour
  use Connection
  use Bitwise
  alias Experimental.DynamicSupervisor
  alias River.{Conn}

  defstruct [
    host:      nil,
    protocol:  "h2",
    send_ctx:  nil,
    recv_ctx:  nil,
    buffer:    "",
    socket:    nil,
    stream_id: -1,
    streams:   0,
    settings:  []
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

  def init(%Conn{host: host}=state) do
    {:ok, send_ctx} = HPack.Table.start_link(4096)
    {:ok, recv_ctx} = HPack.Table.start_link(4096)

    state = %{state | send_ctx: send_ctx, recv_ctx: recv_ctx }

    {:connect, :init, state}
  end

  def get(pid, path, timeout \\ 5_000) do
    Connection.cast(pid, {:get, path, self})
    receive do
      {:ok, response} ->
        {:ok, response}
      other ->
        IO.puts "we got a different message from someone: #{inspect other}"
        other
    after timeout -> # eventually, we need to customize the timeout
      IO.puts "well, we got nothing after #{timeout}ms"
      {:error, :timeout}
    end
  end

  def connect(info, %Conn{host: host}=state) do
    host = String.to_charlist(host)

    IO.puts "about to call the things! :: #{inspect host}"
    case :ssl.connect(host, 443, ssl_options(host)) do
      {:ok, socket} ->
        IO.puts "connected alright!"
        River.Frame.http2_header
        :ssl.send(socket, River.Frame.http2_header)
        frame = River.Frame.Settings.encode([
          MAX_CONCURRENT_STREAMS: 100,
          INITIAL_WINDOW_SIZE: 65535,
          HEADER_TABLE_SIZE: 4096,
          # ENABLE_PUSH: 0
        ], 0)

        # IO.puts "#{IO.ANSI.green_background}#{Base.encode16(frame, case: :lower)}#{IO.ANSI.reset}"

        :ssl.send(socket, frame)
        IO.puts "the connection was established for #{host}"
        {:ok, %{state | socket: socket}}
      {:error, _} = error ->
        IO.puts "connection was no good for some reason #{inspect error}"
        {:backoff, 1000, state}
      other ->
        IO.puts "the connection was just weird? :: #{inspect other}"
        {:backoff, 1000, state}
    end
  end

  def handle_cast({:get, path}, state), do: handle_cast({:get, path, nil}, state)
  def handle_cast({:get, path, parent}, state) do
    IO.puts "we are being asked to GET"
    # the problem here might be that this call will block until it fires
    # off the request, which is less than ideal. What we should do here is
    # spin up a RequestHandler of some sort to trigger it and handle things
    %{
      socket:    socket,
      host:      host,
      stream_id: stream_id,
      send_ctx:  ctx,
      streams:   streams
    } = state

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
    {:noreply, %{state | stream_id: stream_id, streams: streams+1 } }
  end

  def handle_info({:ssl, _, payload} = msg, state) do
    %{
      recv_ctx: ctx,
      socket:   socket,
      buffer:   prev,
      host:     host,
    } = state

    {new_state, frames} =
      case River.Frame.decode_frames(prev <> payload, ctx) do
        {:ok, frames} ->
          {state, frames}
        {:error, :incomplete_frame, frames, buffer} ->
          {%{state | buffer: buffer}, frames}
      end

    for f <- frames do
      # IO.puts "adding this frame: #{inspect f}"
      {:ok, pid} = DynamicSupervisor.start_child(River.StreamSupervisor, [[name: :"stream-#{host}-#{f.stream_id}"]])

      River.StreamHandler.add_frame(pid, f)
      # IO.puts "the response as of now: #{inspect River.StreamHandler.get_response(pid)}"
    end

    {:noreply, new_state}
  end

  def handle_info(msg, state) do
    IO.puts "unhandled message: #{inspect msg}"
    {:noreply, state}
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
