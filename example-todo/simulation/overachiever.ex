defmodule Beamulacrum.Behaviors.Overachiever do
  use Beamulacrum.Behavior

  alias Beamulacrum.Actions
  require Logger

  @decision_wait_ticks 200
  @min_tasks 5
  @min_active_tasks 4

  @impl Beamulacrum.Behavior
  def default_state() do
    %{
      name: Faker.Person.name(),
      email: Faker.Internet.email(),
      tasks: [],
      wait_ticks: 0
    }
  end

  @impl Beamulacrum.Behavior
  def act(_tick, %{name: name, state: state} = data) do
    if state.wait_ticks > 0 do
      new_data = %{data | state: %{state | wait_ticks: state.wait_ticks - 1}}
      {:ok, new_data}
    else
      {:ok, tasks} = execute(name, &Actions.list_tasks/0)
      active_tasks = Enum.filter(tasks, fn task -> !task["completed"] end)

      cond do
        length(tasks) < @min_tasks or length(active_tasks) < @min_active_tasks ->
          # Not enough total tasks OR too few non-completed tasks -> Add one
          add_task(name, data)

        length(tasks) >= @min_tasks ->
          # Enough tasks -> Pick a random one and attempt it
          attempt_task(name, data, tasks)
      end
    end
  end

  defp add_task(name, data) do
    new_task_title = Faker.Lorem.sentence(3)
    Logger.info("#{name} is adding a new task: #{new_task_title}")

    _ = execute(name, &Actions.add_task/1, %{title: new_task_title})
    refresh_tasks(name, data)
  end

  defp attempt_task(name, data, tasks) do
    task = Enum.random(tasks)

    Logger.info("#{name} is attempting task: #{task["title"]}")

    success = :rand.uniform() < 0.5

    if success do
      case execute(name, &Actions.update_task/1, %{id: task["id"], title: task["title"], completed: true}) do
        {:ok, _} ->
          Logger.info("#{name} successfully completed task: #{task["title"]}")
          refresh_tasks(name, data)

        {:error, reason} ->
          Logger.info("#{name} couldn't update '#{task["title"]}': #{inspect(reason)}")
          refresh_tasks(name, data)
      end
    else
      refresh_tasks(name, data)
    end
  end

  defp refresh_tasks(name, data) do
    Logger.info("#{name} is refreshing their task list.")
    {:ok, tasks} = execute(name, &Actions.list_tasks/0)

    new_data = %{
      data
      | state: %{
          data.state
          | tasks: tasks,
            wait_ticks: @decision_wait_ticks
        }
    }

    {:ok, new_data}
  end
end
