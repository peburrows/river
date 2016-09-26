defmodule River.Flags do
  use Bitwise
  use River.FrameTypes
  alias River.{Frame}

  def encode(%{} = flags) do
    flags
    |> Enum.filter_map(fn({_k, v}) -> v end, fn({k, _v})-> key_to_val(k) end)
    |> Enum.reduce(0, fn(el, acc) -> el ||| acc end)
  end

  def flags(@settings, f) do
    get_flags(%{}, f, {0x1, :ack})
  end

  def flags(@data, f) do
    get_flags(%{}, f, {0x1, :end_stream})
  end

  def flags(@push_promise, f) do
    %{}
    |> get_flags(f, {0x4, :end_headers})
    |> get_flags(f, {0x8, :padded})
  end

  def flags(@headers, f) do
    %{}
    |> get_flags(f, {0x1,  :end_stream})
    |> get_flags(f, {0x4,  :end_headers})
    |> get_flags(f, {0x8,  :padded})
    |> get_flags(f, {0x20, :priority})
  end

  def flags(@rst_stream, _f), do: %{}
  def flags(@goaway, _f),     do: %{}


  def has_flag?(%Frame{flags: flags}, f),
    do: has_flag?(flags, f)

  def has_flag?(flags, f) when is_map(flags),
    do: Map.get(flags, f, false)

  def has_flag?(flags, f) do
    f = key_to_val(f)
    case flags &&& f do
      ^f -> true
      _ -> false
    end
  end

  defp get_flags(into, flags, {f, name}) do
    case has_flag?(flags, f) do
      true -> Map.put(into, name, true)
      _    -> into
    end
  end

  defp key_to_val(:ack),         do: 0x1
  defp key_to_val(:end_stream),  do: 0x1
  defp key_to_val(:end_headers), do: 0x4
  defp key_to_val(:padded),      do: 0x8
  defp key_to_val(:priority),    do: 0x20
  defp key_to_val(k),            do: k
end
