defmodule River.Stream do
  defstruct [
    id:     0,
    window: 0,
    conn:   %River.Conn{},
    listener: nil
  ]
end
