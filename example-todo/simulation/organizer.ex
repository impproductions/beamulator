defmodule Beamulator.Behaviors.Organizer do
  alias Beamulator.Utils
  alias Beamulator.Lab.Duration, as: D
  use Beamulator.Behavior

  require Logger

  alias Beamulator.Actions

  @decision_wait_ms D.new(h: 2)
  @max_tasks 50
  @min_tasks 10

  @impl true
  def default_tags() do
    MapSet.new()
  end

  @impl Beamulator.Behavior
  def default_state() do
    %{
      name: Faker.Person.name(),
      email: Faker.Internet.email(),
      tasks: []
    }
  end

  @impl Beamulator.Behavior
  def act(%{actor_name: name, actor_state: _} = data) do
    {:ok, tasks} = execute(data, &Actions.list_tasks/0)

    new_data =
      if :rand.uniform() < 0.5 do
        if length(tasks) < @max_tasks do
          {:ok, new_data} = add_task(data)
          new_data
        else
          Logger.info(
            "#{data.actor_name} has reached the maximum number of tasks. Not adding a new task."
          )

          data
        end
      else
        if length(tasks) > @min_tasks do
          {:ok, new_data} = remove_task(data, tasks)
          new_data
        else
          Logger.info("#{name} has no tasks to remove.")
          data
        end
      end

    wait(new_data)
  end

  defp add_task(data) do
    new_task_title = Faker.Lorem.sentence(3)
    Logger.info("#{data.actor_name} is adding a new task: #{new_task_title}")
    _ = execute(data, &Actions.add_task/1, %{title: new_task_title})
    refresh_tasks(data)
  end

  defp remove_task(data, tasks) do
    task = Enum.random(tasks)
    Logger.info("#{data.actor_name} is removing task: #{task["title"]}")
    _ = execute(data, &Actions.delete_task/1, %{id: task["id"]})
    refresh_tasks(data)
  end

  defp refresh_tasks(data) do
    Logger.info("#{data.actor_name} is refreshing their task list.")
    {:ok, tasks} = execute(data, &Actions.list_tasks/0)

    new_state =
      data.actor_state
      |> Map.put(:tasks, tasks)
      |> Map.put(:tasks, tasks)

    {:ok, %{data | actor_state: new_state}}
  end

  defp wait(data) do
    to_wait = Utils.random_int(div(@decision_wait_ms, 2), @decision_wait_ms)
    Logger.info("#{data.actor_name} is waiting for #{D.to_string(to_wait)}.")
    {:ok, to_wait, data}
  end
end
