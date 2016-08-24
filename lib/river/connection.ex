defmodule River.BaseConnection do
  # defmodule Stream.Supervisor do
  #   alias Experimental.DynamicSupervisor
  #   use DynamicSupervisor

  #   def start_link(opts) do
  #     DynamicSupervisor.start_link(__MODULE__, [], opts)
  #   end

  #   def init() do
  #     children = [
  #       worker(River.StreamHandler, [])
  #     ]
  #     {:ok, children, strategy: :one_for_one}
  #   end
  # end

  require Bitwise
  use Connection # the Connection behavior from the connection package

  def start_link(host, opts \\ []) do
    IO.puts "the start link opts: #{inspect opts}"
    Connection.start_link(__MODULE__, [host: host], opts)
  end

  def init([host: host]) do
    IO.puts "calling init!"
    state = %{
        stream_id: 1,
        host:      host,
        socket:    nil, # nil so we can set the socket in connect
        widow:     "",
        encode_ctx: HPACK.Context.new(%{max_size: 4096}),
        decode_ctx: HPACK.Context.new(%{max_size: 4096}),
     }

    {:connect, :init, state}
  end

  def get(pid, path) do
    Connection.cast(pid, {:get, path})
  end

  def connect(info, %{host: host}=state) do
    IO.puts "info to connect: #{inspect info}"
    IO.puts "we are connecting - #{inspect host}"
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

    IO.puts ""
    case :ssl.connect(host, 443, opts) do
      {:ok, socket} ->
        River.Frame.http2_header
        :ssl.send(socket, River.Frame.http2_header)
        frame = River.Frame.Settings.encode([
          MAX_CONCURRENT_STREAMS: 100,
          INITIAL_WINDOW_SIZE: 65535,
          HEADER_TABLE_SIZE: 4096,
          # ENABLE_PUSH: 0
        ], 0)

        IO.puts "#{IO.ANSI.green_background}#{Base.encode16(frame, case: :lower)}#{IO.ANSI.reset}"

        :ssl.send(socket, frame)
        {:ok, %{state | socket: socket}}
      {:error, _} = error ->
        IO.puts "connection was no good for some reason #{inspect error}"
        {:backoff, 1000, state}
    end
  end

  # when we make a request, we need to spin up a new GenServer to handle this stream
  def handle_cast({:get, path}, state) do
    %{socket: socket, host: host, stream_id: stream_id, encode_ctx: ctx} = state
    :ssl.setopts(socket, [active: true])

    {headers, ctx} = HPACK.encode([
      {":method", "GET"},
      {":scheme", "https"},
      {":path", path},
      {":authority", host},
      {"accept", "*/*"},
      {"user-agent", "River/0.0.1"}
    ], ctx)

    stream_id = stream_id + 2

    f = River.Frame.encode(headers, stream_id, 0x1, Bitwise.|||(0x4, 0x1))
    IO.puts "the headers (stream ID - #{stream_id}): #{inspect headers}"

    IO.puts "#{IO.ANSI.green_background}#{Base.encode16(f, case: :lower)}#{IO.ANSI.reset}"

    :ssl.send(socket, f)
    {:noreply, %{state | encode_ctx: ctx, stream_id: stream_id} }
  end

  def handle_info({:ssl, _, payload} = msg, state) do
    %{
      decode_ctx: ctx,
      socket:     socket,
      widow:      prev,
      host:       host
    } = state

    {new_state, frames} =
      case River.Frame.decode_frames(prev <> payload, ctx) do
        {:ok, frames, ctx} ->
          {%{state | decode_ctx: ctx}, frames}
        {:error, :incomplete_frame, frames, widow, ctx} ->
          {%{state | decode_ctx: ctx, widow: widow}, frames}
      end

    for f <- frames do
      IO.puts "adding this frame: #{inspect f}"
      {:ok, pid} = River.Stream.start_link(name: :"#{host}-#{f.stream_id}")
      River.Stream.add_frame(pid, f)
      IO.puts "the response as of now: #{inspect River.Stream.get_response(pid)}"
    end

    {:noreply, new_state}
  end

  def handle_info(msg, state) do
    IO.puts "unhandled message: #{inspect msg}"
    {:noreply, state}
  end
end
