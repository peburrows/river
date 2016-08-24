defmodule River.Response do
  defstruct [
    status:   nil,
    code:     nil,
    headers:  [],
    body:     "",
    frames: []
  ]
end
