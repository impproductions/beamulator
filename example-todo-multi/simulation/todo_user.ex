defmodule Beamulator.Behaviors.TodoUser do
  alias Beamulator.Actions
  alias Beamulator
  alias Beamulator.Utils
  alias Beamulator.Lab.Duration, as: D
  use Beamulator.Behavior
  require Logger

  @decision_wait_ms D.new(m: 30)

  @impl true
  def default_tags(), do: MapSet.new()

  @impl true
  def default_state() do
    %{
      registered: false,
      username: Faker.Person.name(),
      password: Faker.Pokemon.name(),
      todos: [],
      last_action: "none"
    }
  end

  @impl true
  def act(%{actor_state: state} = actor_data) do
    cond do
      not state.registered ->
        register_self(actor_data)

      :rand.uniform() < 0.5 ->
        create_todo(actor_data)

      true ->
        delete_todo(actor_data)
    end
  end

  defp register_self(%{actor_state: state} = actor_data) do
    Logger.info("#{actor_data.actor_name} is registering as a new user.")

    execute(actor_data, &Actions.create_user/1, auth_data(state))

    new_state = Map.put(state, :registered, true)
    wait(%{actor_data | actor_state: Map.put(new_state, :last_action, "registered")})
  end

  defp delete_todo(%{actor_state: state} = actor_data) do
    Logger.info("#{actor_data.actor_name} is deleting a todo item.")

    with {:ok, todos} when todos != [] <-
           execute(actor_data, &Actions.get_todos/1, auth_data(state)),
         todo <- Enum.random(todos),
         {:ok, _} <-
           execute(actor_data, &Actions.delete_todo/1, with_auth_data(%{id: todo["id"]}, state)),
         {:ok, updated_todos} <-
           execute(actor_data, &Actions.get_todos/1, auth_data(state)) do
      new_state = Map.put(state, :todos, updated_todos)

      wait(%{
        actor_data
        | actor_state: Map.put(new_state, :last_action, "deleted todo")
      })
    else
      _ ->
        Logger.info("#{actor_data.actor_name} has no todos to delete.")

        wait(%{
          actor_data
          | actor_state: Map.put(state, :last_action, "no todos to delete")
        })
    end
  end

  defp create_todo(%{actor_state: state} = actor_data) do
    Logger.info("#{actor_data.actor_name} is creating a new todo item.")

    todo_item = %{
      title: Faker.Lorem.sentence(),
      completed: false
    }

    with {:ok, _} <-
           execute(actor_data, &Actions.create_todo/1, with_auth_data(todo_item, state)),
         {:ok, todos} <-
           execute(actor_data, &Actions.get_todos/1, auth_data(state)) do
      new_state = Map.put(state, :todos, todos)

      wait(%{
        actor_data
        | actor_state: Map.put(new_state, :last_action, "created todo")
      })
    else
      _ ->
        wait(%{actor_data | actor_state: Map.put(state, :last_action, "created todo")})
    end
  end

  defp auth_data(state) do
    %{
      username: state.username,
      password: state.password
    }
  end

  defp with_auth_data(map, state) do
    Map.merge(map, auth_data(state))
  end

  defp wait(actor_data) do
    to_wait =
      Utils.random_int(div(@decision_wait_ms, 2), @decision_wait_ms)
      |> Utils.Time.adjust_to_time_window(8, 18)

    new_scheduled_time = Utils.Time.simulation_time_after!(to_wait)
    real_scheduled_time = Utils.Time.real_time_after!(to_wait)

    Logger.info(
      "#{actor_data.actor_name} is waiting for #{D.to_string(to_wait)} and is scheduled to act at #{new_scheduled_time} (#{real_scheduled_time} real time)."
    )

    {:ok, to_wait, actor_data}
  end
end
