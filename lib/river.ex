defmodule River do
  use Application

  def start(_type, _args) do
    IO.puts "we are starting our app!"
    ret = River.Supervisor.start_link()
    ret
  end
end
