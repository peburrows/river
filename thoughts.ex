{:ok, response} = River.get("https://http2.golang.org/", [{"X-My-API-Key", "abc123"}])

{:ok, response} = River.post("https://http2.golang.org/", "data:goes:here", [{"my-header", "my-header-val"}])

{:ok, pid} = River.stream(:get, "https://http2.golang.org/", fn(frame)->
  # each one of these is a frame, and you're expected to handle it accordingly
  case frame do
    %River.Frame{type: @data}    -> :data
    %River.Frame{type: @headers} -> :header
    _                            -> :ignore
  end
end)

"""
How do we handle the frames that require a response?
PING frames, for instance, require a response
SETTINGS frames also require a response, and require
us to update our internal state.
"""

"""
connection
 \- streamHandler
 \- streamHandler
 \- streamHandler
"""
