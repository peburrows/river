defmodule River.ResponseTest do
  use ExUnit.Case, async: true
  use River.FrameTypes
  alias River.{Response, Frame}

  test "adding a data frame appends the payload to the body" do
    assert %Response{
      body:    "full body",
      frames:  [%Frame{type: @data}]
    } = Response.add_frame(
      %Response{body: "full "},
      %Frame{
        type: @data,
        payload: %Frame.Data{data: "body"}
      })
  end

  test "adding a header frame adds the headers to the header list" do
    headers = [{"status", "200"}, {"content-type", "html"}]
    assert %Response{
      headers: ^headers,
      frames:  [%Frame{type: @headers, payload: %Frame.Headers{headers: headers}}]
    } = Response.add_frame(%Response{}, %Frame{type: @headers, payload: %Frame.Headers{headers: headers}})
  end

  test "adding a continuation frame adds the headers to the header list" do
    headers = [{"random", "value"}]
    assert %Response{
      headers: ^headers,
      frames:  [%Frame{type: @continuation, payload: %Frame.Continuation{headers: ^headers}}]
    } = Response.add_frame(%Response{}, %Frame{type: @continuation, payload: %Frame.Continuation{headers: headers}})
  end

  test "adding a headers frame with a status code sets the status" do
    assert %Response{
      code: 200
    } = Response.add_frame(
      %Response{},
      %Frame{
        type: @headers,
        payload: %Frame.Headers{headers: [{":status", "200"}]}
      })
  end

  test "adding a content type header sets the content type" do
    assert %Response{
      content_type: "text/html"
    } = Response.add_frame(%Response{}, %Frame{type: @headers, payload: %Frame.Headers{headers: [{"content-type", "text/html"}]}})
  end

  test "add a frame with a :END_STREAM flag should close the response" do
    assert %Response{
      closed: true
    } = Response.add_frame(%Response{}, %Frame{flags: %{end_stream: true}})
  end
end
