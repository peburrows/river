defmodule River.Flags do
  require Bitwise
  use River.FrameTypes

  def flags(@settings, f) do
    get_flags([], f, {0x1, :ACK})
  end

  def flags(@data, f) do
    get_flags([], f, {0x1, :END_STREAM})
  end

  def flags(@push_promise, f) do
    []
    |> get_flags(f, {0x4, :END_HEADERS})
    |> get_flags(f, {0x8, :PADDED})
  end

  def flags(@headers, f) do
    []
    |> get_flags(f, {0x1, :END_STREAM})
    |> get_flags(f, {0x4, :END_HEADERS})
    |> get_flags(f, {0x8, :PADDED})
    |> get_flags(f, {0x20, :PRIORITY})
  end

  def flags(@rst_stream, _f), do: []
  def flags(@goaway, _f),     do: []

  defp get_flags(acc, f, {flag, name}) do
    case Bitwise.&&&(f, flag) do
      ^flag -> [name|acc]
      _     -> acc
    end
  end
end
