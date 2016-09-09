defmodule River.Flags do
  use Bitwise
  use River.FrameTypes
  alias River.{Frame}

  def encode(%{}=flags) do
    flags
    |> Enum.filter_map(fn({_k, v}) -> v end, fn({k, _v})-> key_to_val(k) end)
    |> Enum.reduce(0, fn(el, acc) -> el ||| acc end)
  end

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

  def has_flag?(%Frame{flags: flags}, f),
    do: has_flag?(flags, f)

  def has_flag?(flags, f) when is_list(flags),
    do: Enum.any?(flags, &(&1 == f))

  def has_flag?(flags, f) do
    case flags &&& f do
      ^f -> true
      _ -> false
    end
  end

  defp get_flags(acc, f, {flag, name}) do
    case f &&& flag do
      ^flag -> [name|acc]
      _     -> acc
    end
  end

  defp key_to_val(:ack),         do: 0x1
  defp key_to_val(:end_stream),  do: 0x1
  defp key_to_val(:end_headers), do: 0x4
  defp key_to_val(:padded),      do: 0x8
  defp key_to_val(:priority),    do: 0x20
end
