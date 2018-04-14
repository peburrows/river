defmodule River.Response do
  require River.FrameTypes
  alias River.{Frame, FrameTypes}

  defstruct code: nil,
            content_type: nil,
            __status: :ok,
            closed: false,
            headers: [],
            frames: [],
            body: ""

  def add_frame(%__MODULE__{} = response, %Frame{type: FrameTypes.data()} = frame) do
    %{response | frames: [frame | response.frames], body: response.body <> frame.payload.data}
    |> handle_flags(frame)
  end

  def add_frame(%__MODULE__{} = response, %Frame{type: FrameTypes.headers()} = frame) do
    %{response | frames: [frame | response.frames]}
    |> add_headers(frame.payload.headers)
    |> handle_flags(frame)
  end

  def add_frame(%__MODULE__{} = response, %Frame{type: FrameTypes.continuation()} = frame) do
    %{response | frames: [frame | response.frames]}
    |> add_headers(frame.payload.headers)
    |> handle_flags(frame)
  end

  def add_frame(
        %__MODULE__{} = response,
        %Frame{type: FrameTypes.rst_stream(), payload: code} = frame
      ) do
    %{
      response
      | frames: [frame | response.frames],
        closed: true,
        __status: :error,
        code: code.error
    }
    |> handle_flags(frame)
  end

  def add_frame(%__MODULE__{} = response, %Frame{} = frame) do
    %{response | frames: [frame | response.frames]}
    |> handle_flags(frame)
  end

  defp add_headers(%__MODULE__{} = response, []) do
    %{response | headers: Enum.reverse(response.headers)}
  end

  defp add_headers(%__MODULE__{} = response, [{":status", code} | tail]) do
    %{
      response
      | code: String.to_integer(code, 10),
        headers: [{":status", code} | response.headers]
    }
    |> add_headers(tail)
  end

  defp add_headers(%__MODULE__{} = response, [{"content-type", type} | tail]) do
    %{response | content_type: type, headers: [{"content-type", type} | response.headers]}
    |> add_headers(tail)
  end

  defp add_headers(%__MODULE__{} = response, [head | tail]) do
    %{response | headers: [head | response.headers]}
    |> add_headers(tail)
  end

  defp handle_flags(response, %Frame{flags: %{end_stream: true}}) do
    %{response | closed: true}
  end

  defp handle_flags(response, _), do: response
end
