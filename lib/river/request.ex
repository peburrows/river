defmodule River.Request do
  defstruct [
    headers: [],
    path:    nil,
    method:  :get,
    data:    nil
  ]
end
