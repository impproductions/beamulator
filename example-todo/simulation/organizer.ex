defmodule Beamulacrum.Behaviors.Organizer do
  alias Beamulacrum.Tools
  use Beamulacrum.Behavior

  require Logger

  alias Beamulacrum.Actions

  @decision_wait_ticks 50
  @max_tasks 50
  @min_tasks 10

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
      # Decide with equal likelihood whether to add or remove a task.
      new_data =
        if :rand.uniform() < 0.5 do
          # Attempt to add a task if not over the maximum.
          if length(tasks) < @max_tasks do
            {:ok, new_data} = add_task(name, data)
            new_data
          else
            Logger.info("#{name} has reached the maximum number of tasks. Not adding a new task.")
            data
          end
        else
          # Attempt to remove a task if any exist.
          if length(tasks) > @min_tasks do
            {:ok, new_data} = remove_task(name, data, tasks)
            new_data
          else
            Logger.info("#{name} has no tasks to remove.")
            data
          end
        end

      wait(name, new_data)
    end
  end

  defp add_task(name, data) do
    new_task_title = Faker.Lorem.sentence(3)
    Logger.info("#{name} is adding a new task: #{new_task_title}")
    _ = execute(name, &Actions.add_task/1, %{title: new_task_title})
    refresh_tasks(name, data)
  end

  defp remove_task(name, data, tasks) do
    task = Enum.random(tasks)
    Logger.info("#{name} is removing task: #{task["title"]}")
    _ = execute(name, &Actions.delete_task/1, %{id: task["id"]})
    refresh_tasks(name, data)
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

    new_state = data.state
    |> Map.put(:tasks, tasks)
    |> Map.update!(:tick_counter, &(&1 + 1))
    |> Map.put(:wait_ticks, @decision_wait_ticks)

    {:ok, %{data | state: new_state}}
  end
end
