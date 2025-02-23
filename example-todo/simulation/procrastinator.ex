defmodule Beamulacrum.Behaviors.Procrastinator do
  alias Beamulacrum.Tools
  use Beamulacrum.Behavior

  require Logger
  alias Beamulacrum.Actions

  @decision_wait_ticks 50

  @impl Beamulacrum.Behavior
  def default_state() do
    %{
      name: Faker.Person.name(),
      email: Faker.Internet.email(),
      tasks: [],
      tick_counter: 0,
      wait_ticks: 0
    }
  end

  @impl Beamulacrum.Behavior
  def act(_tick, %{name: name, state: state} = data) do
    if state.wait_ticks > 0 do
      new_state = %{state | wait_ticks: state.wait_ticks - 1}
      {:ok, %{data | state: new_state}}
    else
      {:ok, tasks} = execute(name, &Actions.list_tasks/0)

      # With 50% chance, do nothing; otherwise, mark a task as complete or incomplete equally.
      case :rand.uniform() do
        r when r < 0.5 ->
          Logger.info("#{name} is procrastinating and doing nothing.")
          wait(name, data)

        r when r < 0.75 ->
          if tasks != [] do
            task = Enum.random(tasks)
            Logger.info("#{name} is marking task '#{task["title"]}' as complete.")
            _ = execute(name, &Actions.update_task/1, %{
              id: task["id"],
              title: task["title"],
              completed: true
            })
            refresh_tasks(name, data)
          else
            Logger.info("#{name} has no tasks to mark complete.")
            wait(name, data)
          end

        _ ->
          if tasks != [] do
            task = Enum.random(tasks)
            Logger.info("#{name} is marking task '#{task["title"]}' as incomplete.")
            _ = execute(name, &Actions.update_task/1, %{
              id: task["id"],
              title: task["title"],
              completed: false
            })
            refresh_tasks(name, data)
          else
            Logger.info("#{name} has no tasks to mark incomplete.")
            wait(name, data)
          end
      end
    end
  end

  defp wait(name, data) do
    Logger.info("#{name} is waiting.")
    to_wait = Tools.random_int(div(@decision_wait_ticks, 2), @decision_wait_ticks)
    new_state = Map.put(data.state, :wait_ticks, to_wait)
    {:ok, %{data | state: new_state}}
  end

  defp refresh_tasks(name, data) do
    Logger.info("#{name} is refreshing their task list.")
    {:ok, tasks} = execute(name, &Actions.list_tasks/0)

    new_state =
      data.state
      |> Map.put(:tasks, tasks)
      |> Map.update!(:tick_counter, &(&1 + 1))
      |> Map.put(:wait_ticks, @decision_wait_ticks)

    {:ok, %{data | state: new_state}}
  end
end
