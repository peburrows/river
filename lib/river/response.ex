defmodule River.Response do
  use River.FrameTypes
  alias River.{Response, Frame, Flags}

  defstruct [
    code:         nil,
    content_type: nil,
    closed:       false,
    headers:      [],
    frames:       [],
    body:         "",
  ]

  def add_frame(%__MODULE__{}=response, %Frame{type: @data}=frame) do
    %{response |
      frames: [frame|response.frames],
      body: response.body <> frame.payload
    } |> handle_flags(frame)
  end

  def add_frame(%__MODULE__{}=response, %Frame{type: @headers}=frame) do
    %{response | frames:  [frame|response.frames]}
    |> add_headers(frame.payload)
    |> handle_flags(frame)
  end

  def add_frame(%__MODULE__{}=response, %Frame{}=frame) do
    %{response | frames: [frame|response.frames]}
    |> handle_flags(frame)
  end

  defp add_headers(%__MODULE__{}=response, []) do
    %{response | headers: Enum.reverse(response.headers)}
  end

  defp add_headers(%__MODULE__{}=response, [{":status", code}|tail]) do
    %{response |
      code:    String.to_integer(code, 10),
      headers: [{":status", code}|response.headers]
    } |> add_headers(tail)
  end

  defp add_headers(%__MODULE__{}=response, [{"content-type", type}|tail]) do
    %{response |
      content_type: type,
      headers:      [{"content-type", type} | response.headers]
    } |> add_headers(tail)
  end

  defp add_headers(%__MODULE__{}=response, [head|tail]) do
    %{response | headers: [head|response.headers]}
    |> add_headers(tail)
  end

  defp handle_flags(response, %Frame{flags: flags}) when is_list(flags) do
    case Flags.has_flag?(flags, :END_STREAM) do
      true -> %{response | closed: true}
      _ -> response
    end
  end

  defp handle_flags(response, %Frame{flags: flags}) do
    case Flags.has_flag?(flags, 0x1) do
      true -> %{response | closed: true}
      _ -> response
    end
  end
end
