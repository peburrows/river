defmodule River.Conn do
  # the name is confusing, but this is an external behaviour
  use Connection
  use River.FrameTypes
  use Bitwise
  alias Experimental.DynamicSupervisor
  alias River.{Conn, Frame, Frame.Settings, Frame.WindowUpdate, Encoder}

  @default_header_table_size 4096
  # for some reason, I can't get the golang server to respect the initial window
  @initial_window_size 65_535
  # @max_frame_size 16_777_215

  defstruct [
    host:      nil,
    protocol:  "h2",
    send_ctx:  nil,
    recv_ctx:  nil,
    send_window: 0,
    recv_window: @initial_window_size,
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
               MAX_CONCURRENT_STREAMS: 250,
               INITIAL_WINDOW_SIZE: @initial_window_size,
               HEADER_TABLE_SIZE: @default_header_table_size,
               # MAX_FRAME_SIZE: @max_frame_size,
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
    after timeout ->
        # this timeout isn't quite right as it will timeout if the response is
        # streaming, but is big enough that it takes longer than the timeout.
        # we need a connect timeout and also a receive timeout (which should timeout if
        # the time between packets is longer than the timeout value)
      {:error, :timeout}
    end
  end

  def connect(info, %Conn{host: host}=conn) do
    host = String.to_charlist(host)

    case :ssl.connect(host, 443, ssl_options(host)) do
      {:ok, socket} ->
        River.Frame.http2_header
        :ssl.send(socket, River.Frame.http2_header)

        # frame = River.Frame.Settings.encode(conn.settings, 0)
        frame = Encoder.encode(%Frame{
              type: @settings,
              payload: %Settings{
                settings: conn.settings
              }})

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

    headers = [
      {":method", "GET"},
      {":scheme", "https"},
      {":path", path},
      {":authority", host},
      {"accept", "*/*"},
      {"user-agent", "River/0.0.1"},
      # {"accept-encoding", "gzip, deflate"}
    ]

    f = Encoder.encode(%Frame{
          type: @headers,
          stream_id: stream_id,
          flags: %{end_headers: true, end_stream: true},
          payload: %Frame.Headers{
            headers: headers
          }}, ctx)

    :ssl.send(socket, f)
    {:noreply, %{conn | stream_id: stream_id, streams: streams+1 } }
  end

  def handle_info({:ssl, what, payload} = msg, conn) do
    %{
      recv_ctx: ctx,
      socket:   socket,
      buffer:   prev,
      host:     host,
    } = conn

    # ["packet: ", byte_size(payload), payload] |> IO.inspect
    conn = decode_frames(conn, prev <> payload, ctx, [])

    # ["after", conn] |> IO.inspect
    {:noreply, conn}
  end

  defp handle_frame(conn, %{type: @settings, flags: %{ack: false}}=frame) do
    f = Encoder.encode(%Frame{
          type: @settings,
          stream_id: 0,
          flags: %{ack: true},
          payload: %Settings{
            settings: []
          }})
    :ssl.send(conn.socket, f)
    %{conn | settings: conn.settings ++ frame.payload.settings}
  end

  defp handle_frame(%{recv_window: window}=conn, %{type: @data, length: len, stream_id: stream}) do
    window = window - len
    IO.puts "the window: #{inspect window}"

    if window <= 0 do
      frame1 = %Frame{
        type: @window_update,
        stream_id: stream,
        payload: %WindowUpdate{
          increment: @initial_window_size
        }}

      # IO.puts "sending window update frame #{inspect frame1} :: #{inspect Encoder.encode(frame1)}"
      :ssl.send(conn.socket, Encoder.encode(frame1))
      :ssl.send(conn.socket, Encoder.encode(%{frame1 | stream_id: 0}))
      %{conn | recv_window: @initial_window_size}
    else
      IO.puts "we still have room on the window: #{inspect window}"
      %{conn | recv_window: window}
    end

  end

  defp handle_frame(conn, %{flags: %{end_stream: true}}) do
    %{conn | streams: conn.streams-1}
  end

  defp handle_frame(conn, _frame), do: conn

  defp decode_frames(conn, <<>>, _ctx, stack),
    do: %{conn | buffer: <<>>}
    # do: {%{conn | buffer: <<>>}, Enum.reverse(stack)}

  defp decode_frames(conn, payload, ctx, stack) do
    case Frame.decode(payload, ctx) do
      {:ok, frame, more} ->
        IO.puts "frame! :: #{inspect frame.length} :: #{inspect frame.flags}"
        {:ok, pid} = DynamicSupervisor.start_child(River.StreamSupervisor, [[name: :"stream-#{conn.host}-#{frame.stream_id}"]])
        River.StreamHandler.add_frame(pid, frame)
        conn = handle_frame(conn, frame)
        decode_frames(conn, more, ctx, [frame | stack])
      {:error, :invalid_frame, buffer} ->
        %{conn | buffer: buffer}
        # ["incomplete frame", byte_size(buffer)] |> IO.inspect
        # { %{conn | buffer: buffer}, Enum.reverse(stack) }
    end
  end

  def handle_info(msg, conn) do
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
