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
  def code_to_error(0xA), do: :CONNECT_ERROR
  def code_to_error(0xB), do: :ENHANCE_YOUR_CALM
  def code_to_error(0xC), do: :INADEQUATE_SECURITY
  def code_to_error(0xD), do: :HTTP_1_1_REQUIRED

  def error_to_code(:NO_ERROR), do: 0x0
  def error_to_code(:PROTOCOL_ERROR), do: 0x1
  def error_to_code(:INTERNAL_ERROR), do: 0x2
  def error_to_code(:FLOW_CONTROL_ERROR), do: 0x3
  def error_to_code(:SETTINGS_TIMEOUT), do: 0x4
  def error_to_code(:STREAM_CLOSED), do: 0x5
  def error_to_code(:FRAME_SIZE_ERROR), do: 0x6
  def error_to_code(:REFUSED_STREAM), do: 0x7
  def error_to_code(:CANCEL), do: 0x8
  def error_to_code(:COMPRESSION_ERROR), do: 0x9
  def error_to_code(:CONNECT_ERROR), do: 0xA
  def error_to_code(:ENHANCE_YOUR_CALM), do: 0xB
  def error_to_code(:INADEQUATE_SECURITY), do: 0xC
  def error_to_code(:HTTP_1_1_REQUIRED), do: 0xD
end
