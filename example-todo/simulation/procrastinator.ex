defmodule Beamulator.Behaviors.Procrastinator do
  alias Beamulator.Behavior.Complaint
  alias Beamulator.Tools
  use Beamulator.Behavior

  require Logger
  alias Beamulator.Actions

  @decision_wait_ticks 50

  @impl Beamulator.Behavior
  def default_state() do
    %{
      name: Faker.Person.name(),
      email: Faker.Internet.email(),
      tasks: []
    }
  end

  @impl Beamulator.Behavior
  def act(_tick, %{name: name, state: _} = data) do
    {:ok, tasks} = execute(name, &Actions.list_tasks/0)

    {:ok, new_data} =
      case :rand.uniform() do
        r when r < 0.5 ->
          Logger.info("#{name} is procrastinating and doing nothing.")
          {:ok, data}

        r when r < 0.75 ->
          if tasks != [] do
            task = Enum.random(tasks)
            Logger.info("#{name} is marking task '#{task["title"]}' as complete.")

            {:ok, updated_task} =
              execute(name, &Actions.update_task/1, %{
                id: task["id"],
                title: task["title"],
                completed: true
              })

            complain_when(
              not updated_task["completed"],
              %Complaint{
                message: "I marked a task complete but it's still marked incomplete",
                severity: :annoying,
                behavior: __MODULE__,
                actor: name,
                action: &Actions.update_task/1,
                expected: %{
                  id: task["id"],
                  title: task["title"],
                  completed: true
                },
                actual: updated_task
              }
            )

            refresh_tasks(name, data)
          else
            Logger.info("#{name} has no tasks to mark complete.")
            {:ok, data}
          end

        _ ->
          if tasks != [] do
            task = Enum.random(tasks)
            Logger.info("#{name} is marking task '#{task["title"]}' as incomplete.")

            {:ok, updated_task} =
              execute(name, &Actions.update_task/1, %{
                id: task["id"],
                title: task["title"],
                completed: false
              })

            complain_when(updated_task["completed"], %Complaint{
              message: "I marked a task incomplete but it's still marked complete",
              severity: :annoying,
              behavior: __MODULE__,
              actor: name,
              action: &Actions.update_task/1,
              expected: %{
                id: task["id"],
                title: task["title"],
                completed: false
              },
              actual: updated_task
            })

            refresh_tasks(name, data)
          else
            Logger.info("#{name} has no tasks to mark incomplete.")
            {:ok, data}
          end
      end

    wait(name, new_data)
  end

  defp wait(name, data) do
    Logger.info("#{name} is waiting.")
    to_wait = Tools.random_int(div(@decision_wait_ticks, 2), @decision_wait_ticks)
    {:ok, to_wait, data}
  end

  defp refresh_tasks(name, data) do
    Logger.info("#{name} is refreshing their task list.")
    {:ok, tasks} = execute(name, &Actions.list_tasks/0)

    new_state =
      data.state
      |> Map.put(:tasks, tasks)

    {:ok, %{data | state: new_state}}
  end
end
