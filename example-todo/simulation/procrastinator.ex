defmodule Beamulacrum.Behaviors.Procrastinator do
  use Beamulacrum.Behavior

  require Logger

  alias Beamulacrum.Actions

  @decision_wait_ticks 500
  @max_active_tasks 12
  @min_active_tasks 8
  @completion_chance 0.1
  @task_add_frequency 3

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
      new_data = %{data | state: %{state | wait_ticks: state.wait_ticks - 1}}
      {:ok, new_data}
    else
      {:ok, tasks} = execute(name, &Actions.list_tasks/0)
      active_tasks = Enum.filter(tasks, fn task -> !task["completed"] end)

      cond do
        rem(state.tick_counter, @task_add_frequency) == 0 ->
          add_task(name, data)

        :rand.uniform() < @completion_chance && active_tasks != [] and length(active_tasks) >= @min_active_tasks ->
          complete_task(name, data, active_tasks)

        length(active_tasks) > @max_active_tasks ->
          delete_task(name, data, active_tasks)

        true ->
          wait(name, data)
      end
    end
  end

  defp add_task(name, data) do
    new_task_title = Faker.Lorem.sentence(3)
    Logger.info("#{name} is adding a new task: #{new_task_title}")

    _ = execute(name, &Actions.add_task/1, %{title: new_task_title})
    refresh_tasks(name, data)
  end

  defp complete_task(name, data, active_tasks) do
    task = Enum.random(active_tasks)
    Logger.info("#{name} is reluctantly completing a task: #{task["title"]}")

    _ = execute(name, &Actions.update_task/1, %{id: task["id"], title: task["title"], completed: true})
    refresh_tasks(name, data)
  end

  defp delete_task(name, data, active_tasks) do
    task = Enum.random(active_tasks)
    Logger.info("#{name} is overwhelmed and deleting task: #{task["title"]}")

    _ = execute(name, &Actions.delete_task/1, %{id: task["id"]})
    refresh_tasks(name, data)
  end

  defp wait(name, data) do
    Logger.info("#{name} is doing nothing and avoiding responsibilities.")
    new_data = %{data | state: %{data.state | wait_ticks: @decision_wait_ticks}}
    {:ok, new_data}
  end

  defp refresh_tasks(name, data) do
    Logger.info("#{name} is refreshing their task list.")
    {:ok, tasks} = execute(name, &Actions.list_tasks/0)

    new_data = %{
      data
      | state: %{
          data.state
          | tasks: tasks,
            tick_counter: data.state.tick_counter + 1,
            wait_ticks: @decision_wait_ticks
        }
    }

    {:ok, new_data}
  end
end
