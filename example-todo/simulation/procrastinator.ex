defmodule Beamulator.Behaviors.Procrastinator do
  alias Beamulator.Utils
  alias Beamulator.Lab.Duration, as: D
  use Beamulator.Behavior
  import Beamulator.Behavior.ComplaintBuilder

  require Logger
  alias Beamulator.Actions

  @decision_wait_ms D.new(h: 2)

  @impl true
  def default_tags(), do: MapSet.new()

  @impl true
  def default_state() do
    %{
      name: Faker.Person.name(),
      email: Faker.Internet.email(),
      tasks: []
    }
  end

  @impl true
  def act(%{actor_name: name, actor_state: _} = data) do
    {:ok, tasks} = execute(data, &Actions.list_tasks/0)

    {:ok, new_data} =
      case :rand.uniform() do
        r when r < 0.5 ->
          Logger.info("#{name} is procrastinating and doing nothing.")
          {:ok, data}

        r when r < 0.75 ->
          if tasks != [] do
            task = Enum.random(tasks)
            Logger.info("#{name} is marking task '#{task["title"]}' as complete.")

            execute(
              data,
              &Actions.update_task/1,
              %{
                id: task["id"],
                title: task["title"],
                completed: true
              },
              build_complaint(
                fn {status, result} -> status == :ok and result["completed"] end,
                "I marked a task incomplete but it's still marked complete",
                :annoying
              )
            )

            refresh_tasks(data)
          else
            Logger.info("#{name} has no tasks to mark complete.")
            {:ok, data}
          end

        _ ->
          if tasks != [] do
            task = Enum.random(tasks)
            Logger.info("#{name} is marking task '#{task["title"]}' as incomplete.")

            execute(
              data,
              &Actions.update_task/1,
              %{
                id: task["id"],
                title: task["title"],
                completed: false
              },
              build_complaint(
                fn {status, result} -> status == :ok and not result["completed"] end,
                "I marked a task incomplete but it's still marked complete",
                :annoying
              )
            )

            refresh_tasks(data)
          else
            Logger.info("#{name} has no tasks to mark incomplete.")
            {:ok, data}
          end
      end

    wait(new_data)
  end

  defp wait(data) do
    to_wait = Utils.random_int(div(@decision_wait_ms, 2), @decision_wait_ms)
    Logger.info("#{data.actor_name} is waiting for #{D.to_string(to_wait)}.")
    {:ok, to_wait, data}
  end

  defp refresh_tasks(data) do
    Logger.info("#{data.actor_name} is refreshing their task list.")
    {:ok, tasks} = execute(data, &Actions.list_tasks/0)

    new_state =
      data.actor_state
      |> Map.put(:tasks, tasks)

    {:ok, %{data | actor_state: new_state}}
  end
end
