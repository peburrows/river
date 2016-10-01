defmodule River.Conn do
  # the name is confusing, but this is an external behaviour
  use Connection
  use River.FrameTypes
  use Bitwise
  alias Experimental.DynamicSupervisor
  alias River.{Conn, Frame, Frame.Settings, Frame.WindowUpdate, Encoder, Request}

  @default_header_table_size 4096
  @initial_window_size 65_535

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

  def init(%Conn{} = conn) do
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

  def request!(pid, %Request{}=req, timeout) do
    Connection.cast(pid, {req, self})
    listen(timeout)
  end

  defp listen(timeout) do
    receive do
      {:ok, response} ->
        {:ok, response}
      {:data} ->
        listen(timeout)
      other ->
        other
    after timeout ->
        {:error, :timeout}
    end
  end


  def connect(_info, %Conn{host: host} = conn) do
    host = String.to_charlist(host)

    case :ssl.connect(host, 443, ssl_options(host)) do
      {:ok, socket} ->
        :ssl.send(socket, River.Frame.http2_header)

        frame = %Frame{
          type: @settings,
          payload: %Settings{settings: conn.settings}
        }
        encoded_frame = Encoder.encode(frame)

        :ssl.send(socket, encoded_frame)
        {:ok, %{conn | socket: socket}}
      {:error, _} ->
        {:backoff, 1000, conn}
      _other ->
        {:backoff, 1000, conn}
    end
  end

  def disconnect(_info, %Conn{socket: socket} = conn) do
    # we need to disconnect from the ssl socket
    :ssl.close(socket)
    {:stop, :exit, conn}
  end

  def handle_cast({%Request{}=req, parent}, conn) do
    make_request(req, parent, conn)
  end

  defp make_request(%Request{method: method, uri: %{path: path}}=req, parent,
    %{host: host, stream_id: stream_id, socket: socket, send_ctx: ctx, streams: streams}=conn) do

    :ssl.setopts(socket, [active: true])

    conn =
      conn
      |> add_stream(parent)
      |> send_headers(req)
      |> send_data(req)

    {:noreply, conn}
  end

  defp add_stream(%{stream_id: id, streams: count, host: host}=conn, parent) do
    id = id + 2
    {:ok, _} = DynamicSupervisor.start_child(River.StreamSupervisor, [[name: :"stream-#{host}-#{id}"], conn.socket, parent])

    %{conn | stream_id: id, streams: count + 1}
  end

  defp send_headers(%{send_ctx: ctx, socket: socket, host: host, stream_id: id} = conn,
    %{headers: headers, method: method, uri: %{path: path}} = req) do
    headers = [
      {":method",    (method |> Atom.to_string |> String.upcase)},
      {":scheme",    "https"},
      {":path",      path},
      # this should probably be req.authority instead
      {":authority", host},
      {"accept",     "*/*"},
      {"user-agent", "River/0.0.1"},
    ] ++ headers

    frame = %Frame{
      type: @headers,
      stream_id: id,
      flags: header_flags(req),
      payload: %Frame.Headers{headers: headers}
    } |> Encoder.encode(ctx)

    :ssl.send(socket, frame)
    conn
  end

  defp header_flags(%{method: :get}), do: %{end_headers: true, end_stream: true}
  defp header_flags(_), do: %{end_headers: true}

  defp send_data(conn, %{method: :get}), do: conn
  defp send_data(%{stream_id: stream_id, socket: socket} = conn, %{data: data}) do
    frame = %Frame{
      type: @data,
      stream_id: stream_id,
      flags: %{end_stream: true},
      payload: %Frame.Data{data: data}
    } |> Encoder.encode

    :ssl.send(socket, frame)
    conn
  end

  def handle_info({:ssl, _what, payload}, %{recv_ctx: ctx, buffer: buffer} = conn) do
    conn = decode_frames(conn, buffer <> payload, ctx, [])
    {:noreply, conn}
  end

  def handle_info(_message, conn) do
    {:noreply, conn}
  end

  defp handle_frame(conn, %{type: @settings, flags: %{ack: false}} = frame) do
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

  defp handle_frame(%{recv_window: window} = conn, %{type: @data, length: len, stream_id: stream}) do
    window = window - len
    IO.puts "the window: #{inspect window}"

    if window <=  0 do
      frame1 = %Frame{
        type: @window_update,
        stream_id: stream,
        payload: %WindowUpdate{
          # increment: @initial_window_size + 200_000
          increment: 2_000_000
        }}

      # IO.puts "sending window update frame #{inspect frame1} :: #{inspect Encoder.encode(frame1)}"
      # :ssl.send(conn.socket, Encoder.encode(frame1))
      :ssl.send(conn.socket, Encoder.encode(%{frame1 | stream_id: 0}))
      %{conn | recv_window: 2_000_000 }
    else
      IO.puts "we still have room on the window: #{inspect window}"
      %{conn | recv_window: window}
    end

  end

  defp handle_frame(conn, %{flags: %{end_stream: true}}) do
    %{conn | streams: conn.streams - 1}
  end

  defp handle_frame(conn, _frame), do: conn

  defp decode_frames(conn, <<>>, _ctx, _stack),
    do: %{conn | buffer: <<>>}

  defp decode_frames(conn, payload, ctx, stack) do
    case Frame.decode(payload, ctx) do
      {:ok, frame, more} ->
        {:ok, pid} = DynamicSupervisor.start_child(River.StreamSupervisor, [[name: :"stream-#{conn.host}-#{frame.stream_id}"], conn.socket])
        River.StreamHandler.add_frame(pid, frame)
        conn = handle_frame(conn, frame)
        decode_frames(conn, more, ctx, [frame | stack])
      {:error, :invalid_frame, buffer} ->
        %{conn | buffer: buffer}
    end
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
