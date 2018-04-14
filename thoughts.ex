{:ok, response} = River.get("https://http2.golang.org/", [{"X-My-API-Key", "abc123"}])

{:ok, response} =
  River.post("https://http2.golang.org/", "data:goes:here", [{"my-header", "my-header-val"}])

{:ok, pid} =
  River.stream(:get, "https://http2.golang.org/", fn frame ->
    # each one of these is a frame, and you're expected to handle it accordingly
    # probably only pass along data frames
    case frame do
      %River.Frame{type: @data} -> :data
      %River.Frame{type: @headers} -> :header
      _ -> :ignore
    end
  end)

# or, maybe you just go into a receive loop...?
{:ok, pid} = River.stream(:get, "https://http2.golang.org/", self())

receive do
  %River.Frame{type: @data} -> :data
after
  5_000 ->
    :timeout
end

# I think we can support both options

# How do we handle the frames that require a response?
# PING frames, for instance, require a response
# SETTINGS frames also require a response, and require
# us to update our internal state.

# connection
#  \_ streamHandler
#  \_ streamHandler
#  \_ streamHandler
