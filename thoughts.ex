River.get(host)

# in the River:
{:ok, pid} = River.Connection.create(host)
River.get(pid, "/")

# which spins up a connection and then sits in a receive block until
# the stream in the connection that the request was issued on returns a message
# or until a timeout. The stream will message the caller in one of two ways:
# 1) when the :END_STREAM flag is sent from the connection
# 2) if the caller asks for the response to be streamed, it will notify the caller on each frame (sending maybe all frames, or maybe only DATA frames)
