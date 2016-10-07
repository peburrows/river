defmodule River.Request do
  defstruct [
    headers: [{"user-agent", "River/#{River.version}"}],
    uri:     nil,
    method:  :get,
    data:    nil
  ]

  def add_header(request, {_,_}=header),
    do: add_headers(request, [header])

  def add_headers(request, []), do: %{request | headers: Enum.reverse(request.headers)}

  # allow the user-agent to be overwritten
  def add_headers(request, [{"user-agent", val}=ua | headers]) do
    filtered = Enum.reject(request.headers, fn({key, _}) ->
      key == "user-agent"
    end)

    add_headers(%{request | headers: [ua | filtered]}, headers)
  end

  def add_headers(request, [{key, val} | headers])
      when key != ":method" and key != ":scheme" and key != ":path" and key != ":authority" do
    add_headers(%{request | headers: [{String.downcase(key), val} | request.headers]}, headers)
  end

  def add_headers(request, [_ | headers]), do: add_headers(request, headers)

  def header_list(%{uri: %{scheme: scheme, path: path, authority: auth},
                    method: method, headers: headers}) do
    [
      {":method",    (method |> Atom.to_string |> String.upcase)},
      {":scheme",    scheme},
      {":path",      path},
      {":authority", auth},
      # {"accept",     "*/*"},
    ] ++ headers
  end

end
