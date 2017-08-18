defmodule River.Conn do
  # the name is confusing, but this is an external behaviour
  use Connection
  require River.FrameTypes
  use Bitwise
  alias River.{Conn, Frame, Frame.Settings, Frame.WindowUpdate, Encoder,
               Request, StreamHandler, FrameTypes}

  @default_header_table_size 4096
  @initial_window_size 65_535
  @flow_control_increment 2_147_483_647
  @max_frame_size 16_384

  defstruct [
    host:      nil,
    port:      nil,
    protocol:  "h2",
    send_ctx:  nil,
    recv_ctx:  nil,
    send_window: @initial_window_size,
    recv_window: @initial_window_size,
    buffer:    "",
    socket:    nil,
    stream_id: -1,
    streams:   0,
    send_settings: [],
    recv_settings: [],
  ]

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    }
  end

  def create(host, port \\ 443, opts \\ []) do
    name = Keyword.get(opts, :name, :"conn-#{host}")

    Supervisor.start_child(
      River.ConnectionSupervisor,
      [host, port, [name: name]]
    )
  end

  def start_link(host, port, opts \\ []) do
    case Connection.start_link(__MODULE__, %Conn{host: host, port: port}, opts) do
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
             send_settings: [
               MAX_CONCURRENT_STREAMS: 250,
               INITIAL_WINDOW_SIZE: @initial_window_size,
               HEADER_TABLE_SIZE: @default_header_table_size,
               # MAX_FRAME_SIZE: @max_frame_size,
             ],
            }

    {:connect, :init, conn}
  end

  def request!(pid, %Request{}=req, timeout) do
    Connection.cast(pid, {req, self()})
    listen(pid, timeout)
  end

  def initial_window_size, do: @initial_window_size

  defp listen(child, timeout) do
    receive do
      {:ok, response} ->
        {:ok, response}
      {:frame, _frame} ->
        listen(child, timeout)
      other ->
        other
    after timeout ->
        # this isn't the best way to do this, but it will work
        Process.exit(child, :timeout)
        {:error, :timeout}
    end
  end

  def connect(_info, %Conn{host: host, port: port} = conn) do
    host = String.to_charlist(host)

    case :ssl.connect(host, port, ssl_options(host)) do
      {:ok, socket} ->
        :ssl.send(socket, River.Frame.http2_header)

        frame = %Frame{
          type: FrameTypes.settings,
          payload: %Settings{settings: conn.send_settings}
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
    perform_request(req, parent, conn)
  end

  defp perform_request(%Request{}=req, parent, %{socket: socket}=conn) do
    :ssl.setopts(socket, [active: true])

    conn =
      conn
      |> add_stream(parent)
      |> send_headers(req)
      |> send_data(req)

    {:noreply, conn}
  end

  defp add_stream(%{stream_id: id, streams: count}=conn, parent) do
    id = id + 2
    {:ok, _} = StreamHandler.get_pid(conn, id, parent)
    %{conn | stream_id: id, streams: count + 1}
  end

  defp send_headers(%{send_ctx: ctx, socket: socket, stream_id: id} = conn, %{method: method} = req) do
    fragments =
      conn
      |> header_block(req)
      |> header_block_fragments(max_send_frame_size(conn))
    frame_count = length(fragments)

    frame_data =
      fragments
      |> Enum.with_index()
      |> Enum.map(fn {fragment, i} ->
        %Frame{
          type: (if i == 0, do: FrameTypes.headers, else: FrameTypes.continuation),
          stream_id: id,
          flags: %{
            end_headers: i == frame_count - 1,
            end_stream: method == :get,
          },
          payload: %River.Frame.Headers{
            header_block_fragment: fragment,
          },
          length: byte_size(fragment)
        }
        |> Encoder.encode(ctx)
      end)
      |> Enum.reduce(<<>>, &(&2 <> &1))
      :ssl.send(socket, frame_data)
    conn
  end

  defp header_block_fragments(block, max_size) do
    case block do
      <<fragment::binary-size(max_size), rest::binary>> ->
        [fragment | header_block_fragments(rest, max_size)]
      <<>> ->
        []
      fragment ->
        [fragment]
    end
  end

  defp max_send_frame_size(%{send_settings: settings}),
    do: Keyword.get(settings, :MAX_FRAME_SIZE, @max_frame_size)

  defp header_block(%{send_ctx: ctx} = _conn, request) do
    request
    |> Request.header_list()
    |> HPack.encode(ctx)
  end

  defp send_data(conn, %{method: :get}), do: conn

  # we have sent all the data
  defp send_data(conn, %{data: <<>>}), do: conn
  # defp send_data(%{send_window: 0}=conn, req) do
  #   # we need some internal buffer here - we should defer to the stream
  # end
  defp send_data(%{stream_id: stream_id} = conn, %{data: data}=req) do
    # AHHH! duplication!
    case data do
      <<_payload::binary-size(@max_frame_size) , rest::binary>> ->
        frame =
          %Frame{
            type: FrameTypes.data,
            stream_id: stream_id,
            flags: %{end_stream: true},
            payload: %Frame.Data{data: data}
          }
        {:ok, pid} = StreamHandler.get_pid(conn, stream_id)
        StreamHandler.send_frame(pid, frame)
        # send the data, and then call send_data again
        send_data(conn, %{req | data: rest})
      data ->
        frame =
          %Frame{
            type: FrameTypes.data,
            stream_id: stream_id,
            flags: %{end_stream: true},
            payload: %Frame.Data{data: data}
          }
        {:ok, pid} = StreamHandler.get_pid(conn, stream_id)
        StreamHandler.send_frame(pid, frame)
    end

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
    %{conn | recv_settings: conn.recv_settings ++ frame.payload.settings}
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

      # this is a blocking call, so we need to maybe move it into an asyc func
      :ssl.send(conn.socket, Encoder.encode(%{frame1 | stream_id: 0}))
      %{conn | recv_window: window + @flow_control_increment}
    else
      %{conn | recv_window: window}
    end
  end

  defp handle_frame(%{send_window: window} = conn, %{type: FrameTypes.window_update, payload: %{increment: inc}}) do
    %{conn | send_window: window + inc}
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
        {:ok, pid} = StreamHandler.get_pid(conn, frame.stream_id)
        StreamHandler.recv_frame(pid, frame)
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
