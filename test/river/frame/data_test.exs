defmodule River.Frame.DataTest do
  use ExUnit.Case, async: true
  alias River.{Frame, Frame.Data}

  test "we can decode a frame from a non-padded payload" do
    payload = "hello"

    assert %Frame{
             payload: %Data{
               padding: 0,
               data: ^payload
             }
           } = Data.decode(%Frame{length: byte_size(payload)}, payload)
  end

  test "we can decode a frame from a padded payload" do
    payload = "hello"
    padding = "world"
    pad_size = byte_size(padding)
    # we add one to the length to account for the pad-length byte
    payload_length = byte_size(payload <> padding) + 1

    assert %Frame{
             payload: %Data{
               padding: ^pad_size,
               data: ^payload
             },
             flags: %Data.Flags{padded: true}
           } =
             Data.decode(
               %Frame{length: payload_length, flags: %Data.Flags{padded: true}},
               <<byte_size(padding)::8, payload::binary, padding::binary>>
             )
  end

  # test "we can extract flags properly" do
  #   assert {:ok,
  #           %Data{
  #             flags: %Data.Flags{padded: true, end_stream: false}
  #           }
  #   } = Data.decode(%Frame{length: 5}, 0x8, <<1::8, "enough to parse">>)

  #   assert {:ok,
  #           %Data{
  #             flags: %{padded: false, end_stream: true}
  #           }
  #   } = Data.decode(%Frame{}, 0x1, "")
  # end

  test "an incomplete frame properly reports as such" do
    assert {:error, :invalid_frame} = Data.decode(%Frame{length: 30}, "")
  end
end
