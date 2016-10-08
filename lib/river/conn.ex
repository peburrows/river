defmodule River.Conn do
  # the name is confusing, but this is an external behaviour
  use Connection
  require River.FrameTypes
  use Bitwise
  alias Experimental.DynamicSupervisor
  alias River.{Conn, Frame, Frame.Settings, Frame.WindowUpdate, Encoder, Request, Stream, FrameTypes}

  @default_header_table_size 4096
  @initial_window_size 65_535
  @flow_control_increment 2_147_483_647

  defstruct [
    host:      nil,
    protocol:  "h2",
    send_ctx:  nil,
    recv_ctx:  nil,
    send_window: @initial_window_size,
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
      {:frame, _frame} ->
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
          type: FrameTypes.settings,
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

  defp make_request(%Request{}=req, parent, %{socket: socket}=conn) do
    # %{host: host, stream_id: stream_id, socket: socket, send_ctx: ctx, streams: streams}=conn) do

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
    {:ok, _} =
      DynamicSupervisor.start_child(River.StreamSupervisor, [
            [name: :"stream-#{host}-#{id}"],
            %Stream{conn: conn, id: id, listener: parent, recv_window: @initial_window_size}
          ])

    %{conn | stream_id: id, streams: count + 1}
  end

  defp send_headers(%{send_ctx: ctx, socket: socket, stream_id: id} = conn, req) do
    frame = %Frame{
      type: FrameTypes.headers,
      stream_id: id,
      flags: header_flags(req),
      payload: %Frame.Headers{headers: Request.header_list(req)}
    } |> Encoder.encode(ctx)

    :ssl.send(socket, frame)
    conn
  end

  defp header_flags(%{method: :get}), do: %{end_headers: true, end_stream: true}
  defp header_flags(_), do: %{end_headers: true}

  defp send_data(conn, %{method: :get}), do: conn

  # we have sent all the data
  defp send_data(conn, %{data: <<>>}), do: conn
  defp send_data(%{send_window: 0}=conn, req) do
    IO.puts "no send window"
    # we need to increment the flow control window
    # or, rather, we need to wait for the flow control window to be incremented
  end
  defp send_data(%{stream_id: stream_id, socket: socket} = conn, %{data: data}=req) do
    frame = %Frame{
      type: FrameTypes.data,
      stream_id: stream_id,
      flags: %{end_stream: true},
      payload: %Frame.Data{data: data}
    } |> Encoder.encode

    :ssl.send(socket, frame)

    # this doesn't yet handle data that is too large for the flow control window...
    %{conn | send_window: conn.send_window - byte_size(data)}
  end

  def handle_info({:ssl, _what, payload}, %{recv_ctx: ctx, buffer: buffer} = conn) do
    conn = decode_frames(conn, buffer <> payload, ctx, [])
    {:noreply, conn}
  end

  def handle_info(_message, conn) do
    {:noreply, conn}
  end

  defp handle_frame(conn, %{type: FrameTypes.settings, flags: %{ack: false}} = frame) do
    f = Encoder.encode(%Frame{
          type: FrameTypes.settings,
          stream_id: 0,
          flags: %{ack: true},
          payload: %Settings{
            settings: []
          }})
    :ssl.send(conn.socket, f)
    %{conn | settings: conn.settings ++ frame.payload.settings}
  end

  defp handle_frame(%{recv_window: window} = conn, %{type: FrameTypes.data, length: len, stream_id: stream}) do
    window = window - len
    if window <=  0 do
      frame1 = %Frame{
        type: FrameTypes.window_update,
        stream_id: stream,
        payload: %WindowUpdate{
          increment: @flow_control_increment
        }}

      :ssl.send(conn.socket, Encoder.encode(%{frame1 | stream_id: 0}))
      %{conn | recv_window: window + @flow_control_increment}
    else
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
        # we're assuming it exists, but that might be a bad assumption
        pid = Process.whereis(:"stream-#{conn.host}-#{frame.stream_id}")
        River.StreamHandler.recv_frame(pid, frame)
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
