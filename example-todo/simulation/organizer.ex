defmodule Beamulator.Behaviors.Organizer do
  alias Beamulator.Tools
  use Beamulator.Behavior

  require Logger

  alias Beamulator.Actions

  @decision_wait_ticks 500
  @max_tasks 50
  @min_tasks 10

  @impl Beamulator.Behavior
  def default_state() do
    %{
      name: Faker.Person.name(),
      email: Faker.Internet.email(),
      tasks: [],
    }
  end

  @impl Beamulator.Behavior
  def act(_tick, %{name: name, state: _} = data) do
    {:ok, tasks} = execute(name, &Actions.list_tasks/0)

    new_data =
      if :rand.uniform() < 0.5 do
        if length(tasks) < @max_tasks do
          {:ok, new_data} = add_task(name, data)
          new_data
        else
          Logger.info("#{name} has reached the maximum number of tasks. Not adding a new task.")
          data
        end
      else
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

  defp refresh_tasks(name, data) do
    Logger.info("#{name} is refreshing their task list.")
    {:ok, tasks} = execute(name, &Actions.list_tasks/0)

    new_state =
      data.state
      |> Map.put(:tasks, tasks)

    {:ok, %{data | state: new_state}}
  end

  defp wait(name, data) do
    Logger.info("#{name} is waiting.")
    to_wait = Tools.random_int(div(@decision_wait_ticks, 2), @decision_wait_ticks)
    {:ok, to_wait, data}
  end
end
