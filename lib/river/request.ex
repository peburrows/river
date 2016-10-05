defmodule River.Request do
  defstruct [
    headers: [],
    uri:     nil,
    method:  :get,
    data:    nil
  ]

  def add_headers(request, []), do: %{request | headers: Enum.reverse(request.headers)}

  def add_headers(request, [{key, val}| headers])
      when key != ":method" and key != ":scheme" and key != ":path" and key != ":authority" do
    add_headers(%{request | headers: [{String.downcase(key), val} | request.headers]}, headers)
  end

  def add_headers(request, [_ | headers]), do: add_headers(request, headers)

  def header_list(%{uri: %{scheme: scheme, path: path, authority: auth}, method: method, headers: headers}) do
    [
      {":method",    (method |> Atom.to_string |> String.upcase)},
      {":scheme",    scheme},
      {":path",      path},
      {":authority", auth},
      # {"accept",     "*/*"},
      # {"user-agent", "River/0.0.1"},
    ] ++ headers
  end

end
