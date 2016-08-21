try do
  import_file "~/.iex.exs"
rescue
  _ -> :ok
end

alias Experimental.DynamicSupervisor
