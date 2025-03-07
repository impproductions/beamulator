defmodule Beamulator.Behaviors.TodoUser do
  alias Beamulator.Actions
  alias Beamulator
  alias Beamulator.Tools
  alias Beamulator.Tools.Duration, as: D
  use Beamulator.Behavior
  require Logger

  @decision_wait_ms D.new(h: 2)

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
  def act(_tick, %{actor_state: state} = data) do
    cond do
      not state.registered ->
        register_self(data)

      :rand.uniform() < 0.5 ->
        create_todo(data)

      true ->
        delete_todo(data)
    end
  end

  defp register_self(%{actor_state: state} = data) do
    Logger.info("#{data.actor_name} is registering as a new user.")

    execute(data.actor_name, &Actions.create_user/1, auth_data(state))

    new_state = Map.put(state, :registered, true)
    wait(data.actor_name, %{data | actor_state: Map.put(new_state, :last_action, "registered")})
  end

  defp delete_todo(%{actor_state: state} = data) do
    Logger.info("#{data.actor_name} is deleting a todo item.")

    with {:ok, todos} when todos != [] <-
           execute(data.actor_name, &Actions.get_todos/1, auth_data(state)),
         todo <- Enum.random(todos),
         {:ok, _} <-
           execute(
             data.actor_name,
             &Actions.delete_todo/1,
             Map.merge(%{id: todo["id"]}, auth_data(state))
           ),
         {:ok, updated_todos} <-
           execute(data.actor_name, &Actions.get_todos/1, auth_data(state)) do
      new_state = Map.put(state, :todos, updated_todos)

      wait(data.actor_name, %{
        data
        | actor_state: Map.put(new_state, :last_action, "deleted todo")
      })
    else
      _ ->
        Logger.info("#{data.actor_name} has no todos to delete.")

        wait(data.actor_name, %{
          data
          | actor_state: Map.put(state, :last_action, "no todos to delete")
        })
    end
  end

  defp create_todo(%{actor_state: state} = data) do
    Logger.info("#{data.actor_name} is creating a new todo item.")

    with {:ok, _} <-
           execute(
             data.actor_name,
             &Actions.create_todo/1,
             %{
               title: Faker.Lorem.sentence(),
               completed: false
             }
             |> Map.merge(auth_data(state))
           ),
         {:ok, todos} <-
           execute(data.actor_name, &Actions.get_todos/1, auth_data(state)) do
      new_state = Map.put(state, :todos, todos)

      wait(data.actor_name, %{
        data
        | actor_state: Map.put(new_state, :last_action, "created todo")
      })
    else
      _ ->
        wait(data.actor_name, %{data | actor_state: Map.put(state, :last_action, "created todo")})
    end
  end

  defp auth_data(state) do
    %{
      username: state.username,
      password: state.password
    }
  end

  defp wait(name, data) do
    to_wait =
      Tools.random_int(div(@decision_wait_ms, 2), @decision_wait_ms)
      |> Tools.Time.adjust_to_time_window(8, 18)

    new_scheduled_time = Tools.Time.simulation_time_after!(to_wait)
    real_scheduled_time = Tools.Time.real_time_after!(to_wait)

    Logger.info(
      "#{name} is waiting for #{D.to_string(to_wait)} and is scheduled to act at #{new_scheduled_time} (#{real_scheduled_time} real time)."
    )

    {:ok, to_wait, data}
  end
end
