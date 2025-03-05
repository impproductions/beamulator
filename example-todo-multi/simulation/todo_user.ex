defmodule Beamulator.Behaviors.TodoUser do
  alias Beamulator.Actions
  alias Beamulator
  alias Beamulator.Tools
  alias Beamulator.Tools.Duration, as: D
  use Beamulator.Behavior
  require Logger

  @self_deletion_chance 0.01
  @decision_wait_ms D.new(h: 2)

  @impl Beamulator.Behavior
  def default_state() do
    %{
      registered: false,
      username: Faker.Person.name(),
      password: Faker.Pokemon.name(),
      todos: [],
      last_action: "none"
    }
  end

  @impl Beamulator.Behavior
  def act(_tick, %{actor_name: name, actor_state: state} = data) do
    cond do
      not state.registered ->
        Logger.info("#{name} is registering as a new user.")

        execute(name, &Actions.create_user/1, %{
          username: state.username,
          password: state.password
        })

        new_state = Map.put(state, :registered, true)
        wait(name, %{data | actor_state: Map.put(new_state, :last_action, "registered")})

      :rand.uniform() < @self_deletion_chance ->
        Logger.info("#{name} is deleting itself.")
        new_state = Map.put(state, :last_action, "self deleted")
        wait(name, %{data | actor_state: new_state})

      true ->
        if :rand.uniform() < 0.5 do
          Logger.info("#{name} is creating a new todo item.")

          execute(name, &Actions.create_todo/1, %{
            username: state.username,
            password: state.password,
            title: Faker.Lorem.sentence(),
            completed: false
          })

          case execute(name, &Actions.get_todos/1, %{
                 username: state.username,
                 password: state.password
               }) do
            {:ok, todos} ->
              new_state = Map.put(state, :todos, todos)

              wait(name, %{data | actor_state: Map.put(new_state, :last_action, "created todo")})

            _ ->
              wait(name, %{data | actor_state: Map.put(state, :last_action, "created todo")})
          end
        else
          Logger.info("#{name} is deleting a todo item.")

          case execute(name, &Actions.get_todos/1, %{
                 username: state.username,
                 password: state.password
               }) do
            {:ok, todos} when todos != [] ->
              todo = Enum.random(todos)

              execute(name, &Actions.delete_todo/1, %{
                username: state.username,
                password: state.password,
                id: todo["id"]
              })

              case execute(name, &Actions.get_todos/1, %{
                     username: state.username,
                     password: state.password
                   }) do
                {:ok, todos} ->
                  new_state = Map.put(state, :todos, todos)

                  wait(name, %{
                    data
                    | actor_state: Map.put(new_state, :last_action, "deleted todo")
                  })

                _ ->
                  Logger.info("#{name} has no todos to delete.")

                  wait(name, %{
                    data
                    | actor_state: Map.put(state, :last_action, "no todos to delete")
                  })
              end

            _ ->
              Logger.info("#{name} has no todos to delete.")

              wait(name, %{data | actor_state: Map.put(state, :last_action, "no todos to delete")})
          end
        end
    end
  end

  defp wait(name, data) do
    to_wait = Tools.random_int(div(@decision_wait_ms, 2), @decision_wait_ms)
    Logger.info("#{name} is waiting for #{D.to_string(to_wait)}.")
    {:ok, to_wait, data}
  end
end
