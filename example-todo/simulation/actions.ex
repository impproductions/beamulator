defmodule Beamulacrum.Actions do
  use SourceInjector
  require Logger
  alias HTTPoison

  @api_base_url "http://127.0.0.1:8000"

  def list_tasks() do
    Logger.debug("Fetching all tasks from the server")

    case HTTPoison.get("#{@api_base_url}/tasks") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        tasks = Jason.decode!(body)
        Logger.info("Retrieved #{length(tasks)} tasks")
        {:ok, tasks}

      {:error, reason} ->
        Logger.error("Failed to fetch tasks: #{inspect(reason)}")
        {:error, "Could not retrieve tasks"}
    end
  end

  def add_task(%{title: title}) do
    Logger.debug("Adding a new task: #{title}")

    payload = Jason.encode!(%{id: "", title: title, completed: false})

    case HTTPoison.post("#{@api_base_url}/tasks", payload, [{"Content-Type", "application/json"}]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        task = Jason.decode!(body)
        Logger.info("Task added successfully: #{inspect(task)}")
        {:ok, task}

      {:error, reason} ->
        Logger.error("Failed to add task: #{inspect(reason)}")
        {:error, "Could not add task"}
    end
  end

  def update_task(%{id: id, title: title, completed: completed}) do
    Logger.debug("Updating task #{id} with title '#{title}' and completed status #{completed}")

    payload = Jason.encode!(%{id: id, title: title, completed: completed})

    case HTTPoison.put("#{@api_base_url}/tasks/#{id}", payload, [{"Content-Type", "application/json"}]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        task = Jason.decode!(body)
        Logger.info("Task updated successfully: #{inspect(task)}")
        {:ok, task}

      {:error, reason} ->
        Logger.error("Failed to update task: #{inspect(reason)}")
        {:error, "Could not update task"}
    end
  end

  def delete_task(%{id: id}) do
    Logger.debug("Deleting task with ID: #{id}")

    case HTTPoison.delete("#{@api_base_url}/tasks/#{id}") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Logger.info("Task deleted successfully: #{inspect(body)}")
        {:ok, "Task deleted"}

      {:error, reason} ->
        Logger.error("Failed to delete task: #{inspect(reason)}")
        {:error, "Could not delete task"}
    end
  end
end
