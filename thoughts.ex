{:ok, response} = River.get("/", [{"X-My-API-Key", "abc123"}])

{:ok, response} = River.post("/", "data:goes:here", [{"my-header", "my-header-val"}])

{:ok, pid} = River.stream(:get, "/", fn(frame)->
  # each one of these is a frame, and you're expected to handle it accordingly
  case frame do
    %River.Frame{type: @data}    -> :data
    %River.Frame{type: @headers} -> :header
    _                            -> :ignore
  end
end)
