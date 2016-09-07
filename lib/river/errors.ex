defmodule River.Errors do
  def code_to_error(0x0), do: :NO_ERROR
  def code_to_error(0x1), do: :PROTOCOL_ERROR
  def code_to_error(0x2), do: :INTERNAL_ERROR
  def code_to_error(0x3), do: :FLOW_CONTROL_ERROR
  def code_to_error(0x4), do: :SETTINGS_TIMEOUT
  def code_to_error(0x5), do: :STREAM_CLOSED
  def code_to_error(0x6), do: :FRAME_SIZE_ERROR
  def code_to_error(0x7), do: :REFUSED_STREAM
  def code_to_error(0x8), do: :CANCEL
  def code_to_error(0x9), do: :COMPRESSION_ERROR
  def code_to_error(0xa), do: :CONNECT_ERROR
  def code_to_error(0xb), do: :ENHANCE_YOUR_CALM
  def code_to_error(0xc), do: :INADEQUATE_SECURITY
  def code_to_error(0xd), do: :HTTP_1_1_REQUIRED
end
