defmodule River.Request do
  defstruct [
    headers: [],
    uri:     nil,
    method:  :get,
    data:    nil
  ]
end
