defmodule River.Frame.DataTest do
  use ExUnit.Case, async: true

  test "we can decode a frame from a non-padded payload" do
    payload = "hello"
    assert {:ok,
            %River.Frame.Data{
              padding:   0,
              flags:     %River.Frame.Data.Flags{end_stream: false, padded: false},
              payload:   ^payload
            }
    }= River.Frame.Data.decode(%River.Frame.Data{length: byte_size(payload)}, 0x0, payload)
  end

  test "we can decode a frame from a padded payload" do
    payload = "hello"
    padding = "world"
    pad_size= byte_size(padding)
    # we add one to the length to account for the pad-length byte
    payload_length = byte_size(payload <> padding) + 1
    assert {:ok,
            %River.Frame.Data{
              padding:   ^pad_size,
              flags:     %River.Frame.Data.Flags{padded: true},
              payload:   ^payload
            }
    } = River.Frame.Data.decode(%River.Frame.Data{length: payload_length}, 0x8, <<byte_size(padding)::8, payload::binary, padding::binary>>)
  end

  test "we can extract flags properly" do
    assert {:ok,
            %River.Frame.Data{
              flags: %River.Frame.Data.Flags{padded: true, end_stream: false}
            }
    } = River.Frame.Data.decode(%River.Frame.Data{length: 5}, 0x8, <<1::8, "enough to parse">>)

    assert {:ok,
            %River.Frame.Data{
              flags: %{padded: false, end_stream: true}
            }
    } = River.Frame.Data.decode(%River.Frame.Data{}, 0x1, "")
  end

  test "an incomplete frame properly reports as such" do
    assert {:error, :incomplete_frame} = River.Frame.Data.decode(%River.Frame.Data{length: 30}, 0x0, "")
  end
end
