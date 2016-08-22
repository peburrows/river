defmodule River.FrameTypes do
  defmacro __using__(_opts) do
    quote do
      # this might be lazy, but it'll allow us to share these definitions across modules
      @data          0x0
      @headers       0x1
      @priority      0x2
      @rst_stream    0x3
      @settings      0x4
      @push_promise  0x5
      @ping          0x6
      @goaway        0x7
      @window_update 0x8
      @continuation  0x9
    end
  end
end
