defmodule River.Frame.Settings do
  def decode(payload, ctx),    do: decode(payload, ctx, [])
  defp decode(<<>>, ctx, acc), do: {acc, ctx}
  defp decode(<<id::16, value::32, rest::binary>>, ctx, acc) do
    decode(rest, ctx, [{name(id), value} | acc])
  end

  defp name(0x1), do: :SETTINGS_HEADER_TABLE_SIZE
  defp name(0x2), do: :SETTINGS_ENABLE_PUSH
  defp name(0x3), do: :SETTINGS_MAX_CONCURRENT_STREAMS
  defp name(0x4), do: :SETTINGS_INITIAL_WINDOW_SIZE
  defp name(0x5), do: :SETTINGS_MAX_FRAME_SIZE
  defp name(0x6), do: :SETTINGS_MAX_HEADER_LIST_SIZE
end
