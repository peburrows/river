defmodule River.Response do
  use River.FrameTypes
  alias River.{Response, Frame}

  defstruct [
    code:         nil,
    content_type: nil,
    headers:      [],
    frames:       [],
    body:         "",
  ]

  def add_frame(%__MODULE__{}=response, %Frame{type: @data}=frame) do
    %{response |
      frames: [frame|response.frames],
      body: response.body <> frame.payload
    }
  end

  def add_frame(%__MODULE__{}=response, %Frame{type: @headers}=frame) do
    %{response | frames:  [frame|response.frames]}
    |> add_headers(frame.payload)
  end

  def add_frame(%__MODULE__{}=response, %Frame{}=frame) do
    %{response | frames: [frame|response.frames]}
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
end
