defmodule River.FrameTypes do
  defmacro data,     do: quote do: 0x0
  defmacro headers,  do: quote do: 0x1
  defmacro priority, do: quote do: 0x2
  defmacro rst_stream, do: quote do: 0x3
  defmacro settings, do: quote do: 0x4
  defmacro push_promise, do: quote do: 0x5
  defmacro ping, do: quote do: 0x6
  defmacro goaway, do: quote do: 0x7
  defmacro window_update, do: quote do: 0x8
  defmacro continuation, do: quote do: 0x9
end
