defmodule Beamulator.Clients.QuestDBHttp do
  @behaviour Beamulator.Clients.QuestDB
  require Logger

  @headers [{"Content-Type", "application/json"}, {"Accept", "application/json"}]
  @write_headers [{"Content-Type", "text/plain"}]

  @impl true
  def test_connection(url) do
    uri =
      URI.new!(url <> "/exec")
      |> URI.append_query(URI.encode_query(exec: "SELECT 1"))
      |> URI.to_string()

    case HTTPoison.get(uri, @headers) do
      {:ok, %HTTPoison.Response{status_code: code}} when code in 200..299 -> :ok
      {:ok, %HTTPoison.Response{status_code: code, body: body}} -> {:error, {code, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def exec(url, query) do
    uri =
      URI.new!(url <> "/exec")
      |> URI.append_query(URI.encode_query(query: query))
      |> URI.to_string()

    case HTTPoison.get(uri, @headers) do
      {:ok, %HTTPoison.Response{status_code: code}} when code in 200..299 -> :ok
      {:ok, %HTTPoison.Response{status_code: code, body: body}} -> {:error, {code, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def write(url, payload) do
    case HTTPoison.post(url <> "/write", payload, @write_headers) do
      {:ok, %HTTPoison.Response{status_code: code}} when code in 200..299 -> :ok
      {:ok, %HTTPoison.Response{status_code: code, body: body}} -> {:error, {code, body}}
      {:error, reason} -> {:error, reason}
    end
  end
end
