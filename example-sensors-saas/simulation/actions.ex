defmodule Beamulator.Actions do
  @moduledoc """
  Example-side actions. The collectors call `send_collected_metrics/1` with a
  batch of readings; this module POSTs them to the IoT-SaaS backend at the
  URL configured in `INGEST_BACKEND_URL` (defaults to http://localhost:4100).
  """

  use SourceInjector
  require Logger

  @default_url "http://localhost:4100"
  @timeout_ms 2_000

  @doc """
  Sends a batch of readings to the backend.

  `batch` is a map with:
    %{
      collector_id: "Collector-1",
      readings: [%{sensor_id: 1, metric: "temperature", value: 21.5, ts_ms: 1700000000000}, ...]
    }

  Returns `{:ok, response_map} | {:error, reason_string}`.
  """
  def send_collected_metrics(%{collector_id: cid, readings: readings} = batch)
      when is_binary(cid) and is_list(readings) do
    url = backend_url() <> "/ingest"
    body = Jason.encode!(batch)
    headers = [{"content-type", "application/json"}]

    case HTTPoison.post(url, body, headers, recv_timeout: @timeout_ms, timeout: @timeout_ms) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        {:ok, "ok wrote #{length(readings)}"}

      {:ok, %HTTPoison.Response{status_code: 400}} ->
        {:error, "rejected bad payload"}

      {:ok, %HTTPoison.Response{status_code: 503}} ->
        {:error, "backend unavailable 503"}

      {:ok, %HTTPoison.Response{status_code: code}} ->
        {:error, "unexpected status #{code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "transport failure"}
    end
  end

  @doc """
  Toggles the backend's chaos injector. `args` is a map with `error_rate`
  (0..1) and `duration_ms` (non-negative integer).
  """
  def toggle_backend_chaos(%{error_rate: rate, duration_ms: dur})
      when is_number(rate) and is_integer(dur) do
    url = backend_url() <> "/admin/chaos"
    body = Jason.encode!(%{error_rate: rate, duration_ms: dur})
    headers = [{"content-type", "application/json"}]

    case HTTPoison.post(url, body, headers, recv_timeout: @timeout_ms, timeout: @timeout_ms) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        {:ok, "chaos updated"}

      {:ok, %HTTPoison.Response{status_code: code}} ->
        {:error, "chaos toggle failed #{code}"}

      {:error, %HTTPoison.Error{}} ->
        {:error, "transport failure"}
    end
  end

  defp backend_url do
    System.get_env("INGEST_BACKEND_URL") || @default_url
  end
end
