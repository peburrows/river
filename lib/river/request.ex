defmodule River.Request do
  @type headers :: [{binary, binary}] | %{binary => binary}

  defstruct [
    headers: [{"user-agent", "River/#{River.version}"}],
    uri:     nil,
    method:  :get,
    data:    nil
  ]

  @doc """
    Builds a request struct returning an error if the request would
    be invalid.
  """
  @spec new(URI.t, atom, any, headers) ::
    {:ok, Request.t} | {:error, :invalid_uri} | {:error, :invalid_method}
  def new(_uri, _method, _data \\ nil, _headers \\ [])
  def new(nil=_uri, _, _, _), do: {:error, :invalid_uri}
  def new(%URI{scheme: nil}, _, _, _), do: {:error, :invalid_uri}
  def new(%URI{authority: nil}, _, _, _), do: {:error, :invalid_uri}
  def new(_, nil=_method, _, _), do: {:error, :invalid_method}
  def new(%URI{path: nil}=uri, method, data, headers) do
    path = if method == :options, do: "*", else: "/"
    new(%{uri | path: path}, method, data, headers)
  end
  def new(uri, method, data, headers) do
    req =
      %__MODULE__{method: method, uri: uri, data: data}
      |> add_headers(headers)
    {:ok, req}
  end

  def add_header(request, {_,_}=header),
    do: add_headers(request, [header])
  def add_headers(request, []),
    do: %{request | headers: Enum.reverse(request.headers)}
  # allow the user-agent to be overwritten
  def add_headers(request, [{"user-agent", _val}=ua | headers]) do
    filtered = Enum.reject(request.headers, fn({key, _}) ->
      key == "user-agent"
    end)

    add_headers(%{request | headers: [ua | filtered]}, headers)
  end
  def add_headers(request, [{key, val} | headers])
      when key != ":method" and key != ":scheme" and key != ":path" and key != ":authority" do
    add_headers(%{request | headers: [{String.downcase(key), val} | request.headers]}, headers)
  end
  def add_headers(request, [_ | headers]) do
    add_headers(request, headers)
  end

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
