defmodule Beamulator.Actions do
  use SourceInjector
  require Logger
  alias HTTPoison

  @api_base_url "http://localhost:8080"

  # iex console: Beamulator.Actions.create_user(%{username: "user1", password: "password"})
  def create_user(%{username: username, password: password}) do
    Logger.debug("Creating user: #{username}")
    payload = Jason.encode!(%{username: username, password: password})

    case HTTPoison.post(
           "#{@api_base_url}/users",
           payload,
           [{"Content-Type", "application/json"}]
         ) do
      {:ok, %HTTPoison.Response{status_code: status, body: body}} when status in 200..299 ->
        user = Jason.decode!(body)
        Logger.info("User created successfully: #{inspect(user)}")
        {:ok, user}

      {:ok, resp} ->
        Logger.error("Failed to create user: #{inspect(resp)}")
        {:error, "User not created"}

      {:error, reason} ->
        Logger.error("Failed to create user: #{inspect(reason)}")
        {:error, "Could not create user"}
    end
  end

  # iex console: Beamulator.Actions.get_user(%{username: "user1", password: "password"})
  def get_user(%{username: username, password: password}) do
    Logger.debug("Fetching user info for: #{username}")

    case HTTPoison.get(
           "#{@api_base_url}/users/me",
           [{"X-User", username}, {"X-Password", password}]
         ) do
      {:ok, %HTTPoison.Response{status_code: status, body: body}} when status in 200..299 ->
        user = Jason.decode!(body)
        Logger.info("Retrieved user info: #{inspect(user)}")
        {:ok, user}

      {:ok, resp} ->
        Logger.error("Failed to fetch user info: #{inspect(resp)}")
        {:error, "User not found"}

      {:error, reason} ->
        Logger.error("Failed to fetch user info: #{inspect(reason)}")
        {:error, "Could not retrieve user info"}
    end
  end

  # iex console: Beamulator.Actions.update_user(%{username: "user1", password: "password", new_password: "new_password"})
  def update_user(%{username: username, password: password, new_password: new_password}) do
    Logger.debug("Updating password for user: #{username}")
    payload = Jason.encode!(%{password: new_password})

    case HTTPoison.put(
           "#{@api_base_url}/users/me",
           payload,
           [{"Content-Type", "application/json"}, {"X-User", username}, {"X-Password", password}]
         ) do
      {:ok, %HTTPoison.Response{status_code: status, body: body}} when status in 200..299 ->
        user = Jason.decode!(body)
        Logger.info("User updated successfully: #{inspect(user)}")
        {:ok, user}

      {:ok, resp} ->
        Logger.error("Failed to update user: #{inspect(resp)}")
        {:error, "User not updated"}

      {:error, reason} ->
        Logger.error("Failed to update user: #{inspect(reason)}")
        {:error, "Could not update user"}
    end
  end

  # iex console: Beamulator.Actions.delete_user(%{username: "user1", password: "password"})
  def delete_user(%{username: username, password: password}) do
    Logger.debug("Deleting user: #{username}")

    case HTTPoison.delete(
           "#{@api_base_url}/users/me",
           [{"X-User", username}, {"X-Password", password}]
         ) do
      {:ok, %HTTPoison.Response{status_code: status, body: body}} when status in 200..299 ->
        Logger.info("User deleted successfully: #{inspect(body)}")
        {:ok, "User deleted"}

      {:ok, resp} ->
        Logger.error("Failed to delete user: #{inspect(resp)}")
        {:error, "User not deleted"}

      {:error, reason} ->
        Logger.error("Failed to delete user: #{inspect(reason)}")
        {:error, "Could not delete user"}
    end
  end

  # iex console: Beamulator.Actions.get_todos(%{username: "user1", password: "password"})
  def get_todos(%{username: username, password: password}) do
    Logger.debug("Fetching todos for user: #{username}")

    case HTTPoison.get(
           "#{@api_base_url}/todos",
           [{"X-User", username}, {"X-Password", password}]
         ) do
      {:ok, %HTTPoison.Response{status_code: status, body: body}} when status in 200..299 ->
        todos = Jason.decode!(body)
        Logger.info("Retrieved #{length(todos)} todos")
        {:ok, todos}

      {:ok, resp} ->
        Logger.error("Failed to fetch todos: #{inspect(resp)}")
        {:error, "Todos not found"}

      {:error, reason} ->
        Logger.error("Failed to fetch todos: #{inspect(reason)}")
        {:error, "Could not retrieve todos"}
    end
  end

  # iex console: Beamulator.Actions.create_todo(%{username: "user1", password: "password", title: "New todo", completed: false})
  def create_todo(%{username: username, password: password, title: title, completed: completed}) do
    Logger.debug("Creating todo for user #{username} with title: #{title}")
    payload = Jason.encode!(%{title: title, completed: completed})

    case HTTPoison.post(
           "#{@api_base_url}/todos",
           payload,
           [{"Content-Type", "application/json"}, {"X-User", username}, {"X-Password", password}]
         ) do
      {:ok, %HTTPoison.Response{status_code: status, body: body}} when status in 200..299 ->
        todo = Jason.decode!(body)
        Logger.info("Todo created successfully: #{inspect(todo)}")
        {:ok, todo}

      {:ok, resp} ->
        Logger.error("Failed to create todo: #{inspect(resp)}")
        {:error, "Todo not created"}

      {:error, reason} ->
        Logger.error("Failed to create todo: #{inspect(reason)}")
        {:error, "Could not create todo"}
    end
  end

  # iex console: Beamulator.Actions.update_todo(%{username: "user1", password: "password", id: "1", title: "Updated title", completed: true})
  def update_todo(%{
        username: username,
        password: password,
        id: id,
        title: title,
        completed: completed
      }) do
    Logger.debug(
      "Updating todo #{id} for user #{username} with title: #{title} and completed: #{completed}"
    )

    payload = Jason.encode!(%{title: title, completed: completed})

    case HTTPoison.put(
           "#{@api_base_url}/todos/#{id}",
           payload,
           [{"Content-Type", "application/json"}, {"X-User", username}, {"X-Password", password}]
         ) do
      {:ok, %HTTPoison.Response{status_code: status, body: body}} when status in 200..299 ->
        todo = Jason.decode!(body)
        Logger.info("Todo updated successfully: #{inspect(todo)}")
        {:ok, todo}

      {:ok, resp} ->
        Logger.error("Failed to update todo: #{inspect(resp)}")
        {:error, "Todo not updated"}

      {:error, reason} ->
        Logger.error("Failed to update todo: #{inspect(reason)}")
        {:error, "Could not update todo"}
    end
  end

  # iex console: Beamulator.Actions.delete_todo(%{username: "user1", password: "password", id: "1"})
  def delete_todo(%{username: username, password: password, id: id}) do
    Logger.debug("Deleting todo #{id} for user #{username}")

    case HTTPoison.delete(
           "#{@api_base_url}/todos/#{id}",
           [{"X-User", username}, {"X-Password", password}]
         ) do
      {:ok, %HTTPoison.Response{status_code: status, body: body}} when status in 200..299 ->
        Logger.info("Todo deleted successfully: #{inspect(body)}")
        {:ok, "Todo deleted"}

      {:ok, resp} ->
        Logger.error("Failed to delete todo: #{inspect(resp)}")
        {:error, "Todo not deleted"}

      {:error, reason} ->
        Logger.error("Failed to delete todo: #{inspect(reason)}")
        {:error, "Could not delete todo"}
    end
  end
end
