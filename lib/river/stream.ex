defmodule River.Stream do
  use River.FrameTypes

  defstruct [
    id:     0,
    window: 0,
    conn:   %River.Conn{},
    listener: nil,
    state:   :idle,
  ]

  def add_frame(stream, frame) do
    transition_state(stream, frame)
  end

  defp transition_state(%{state: :idle} = stream, %{type: @headers}),
    do: %{stream | state: :open}

  defp transition_state(%{state: :idle} = stream, %{type: @push_promise}),
    do: %{stream | state: :reserved}

  defp transition_state(%{state: :reserved} = stream, %{type: @headers}),
    do: %{stream | state: :half_closed}

  defp transition_state(%{state: :open} = stream, %{flags: %{end_stream: true}}),
    do: %{stream | state: :half_closed}

  defp transition_state(stream, %{type: @rst_stream}),
    do: %{stream | state: :closed}
   
end
