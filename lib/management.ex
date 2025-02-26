defmodule AlertFunctions do
  require Logger

  defmacro defwithalert(head, do: body) do
    quote do
      def unquote(head) do
        mod = __MODULE__
        {fun, arity} = __ENV__.function
        AlertFunctions.alert_manual_command({mod, fun, arity})
        unquote(body)
      end
    end
  end

  def alert_manual_command({mod, fun, arity}) do
    # only show warning in the main node
    if Node.self() == :beamulator do
      Logger.warning(
        "!!! ALERT !!! The function #{mod}.#{fun}/#{arity} is for manual use only. You're not supposed to use this in code. If you're seeing this message after manually running a Manage.[function] command in a shell, you can ignore it."
      )
    end
  end
end

defmodule Manage do
  require Logger
  require AlertFunctions

  import AlertFunctions, only: [defwithalert: 2]

  defwithalert behavior_list() do
    Beamulator.Behavior.Registry.list_behaviors()
  end

  defwithalert actor_list() do
    Registry.lookup(Beamulator.ActorRegistry, :actors)
    |> Enum.map(&simplify_actor_data/1)
  end

  defp simplify_actor_data({pid, {behavior, serial_id, name}}) do
    {behavior, serial_id, name, pid}
  end

  defwithalert actor_state(pid_string) when is_binary(pid_string) do
    pid = extract_pid(pid_string)

    case Registry.lookup(Beamulator.ActorRegistry, :actors)
         |> Enum.find(fn {p_id, _} -> pid == p_id end) do
      {pid, {behavior, serial_id, name}} ->
        actor_state = GenServer.call(pid, :state)
        {:message_queue_len, mailbox_length} = Process.info(pid, :message_queue_len)

        housekeeping = %{
          pid: inspect(pid),
          mailbox_length: mailbox_length
        }

        actor_state =
          Map.put(actor_state, :__housekeeping__, housekeeping)
          |> Map.put(:__struct__, inspect(Map.get(actor_state, :__struct__)))
          |> Map.put(:__behavior__, behavior)

        Logger.debug(
          "Fetched state for actor #{name} (#{behavior}) (#{serial_id}) [#{inspect(pid)}]"
        )

        Logger.debug("""
        State: #{inspect(actor_state, pretty: true, syntax_colors: [number: :red, atom: :cyan, string: :green, identifier: :blue])}
        """)

        actor_state

      _ ->
        Logger.error("Actor with PID #{pid_string} not found")
        "Actor not found"
    end
  end

  defwithalert actor_spawn(behavior_module) do
    behaviour_name = behavior_module |> Atom.to_string() |> String.split(".") |> List.last()
    name = "#{behaviour_name} #{Beamulator.Tools.increasing_int()}"

    Logger.info("Spawning actor: #{name} with behavior #{behavior_module}")
    actor_spawn(name, behavior_module, %{})
  end

  defwithalert actor_spawn(name, behavior_module) do
    Logger.info("Spawning actor: #{name} with behavior #{behavior_module}")
    actor_spawn(name, behavior_module, %{})
  end

  defwithalert actor_spawn(name, behavior_module, config) do
    Logger.info(
      "Spawning actor: #{name} with behavior #{behavior_module} and config #{inspect(config)}"
    )

    Beamulator.SupervisorActors.create_actor(name, behavior_module, config)
  end

  defwithalert actor_kill(pid_string) when is_binary(pid_string) do
    pid = extract_pid(pid_string)
    Logger.info("Killing actor with PID #{inspect(pid)}")

    case DynamicSupervisor.terminate_child(Beamulator.SupervisorActors, pid) do
      :ok -> Logger.info("Successfully killed actor #{inspect(pid)}")
      {:error, reason} -> Logger.error("Failed to kill actor #{inspect(pid)}: #{inspect(reason)}")
    end
  end

  defwithalert actor_mailbox_length(pid_string) when is_binary(pid_string) do
    pid = extract_pid(pid_string)
    Logger.info("Fetching mailbox length for actor with PID #{inspect(pid)}")

    mailbox_length = Process.info(pid, :message_queue_len)

    Logger.info("Mailbox length for actor #{inspect(pid)}: #{inspect(mailbox_length)}")
  end

  def actors_by_behavior(behavior_module) do
    Registry.lookup(Beamulator.ActorRegistry, :actors)
    |> Enum.filter(fn {_, {behavior, _, _}} -> behavior == behavior_module end)
    |> Enum.map(&simplify_actor_data/1)
  end

  defp extract_pid(pid_string) do
    pid_string =
      if String.starts_with?(pid_string, "#PID") do
        String.slice(pid_string, 4..-1//1)
      else
        pid_string
      end

    pid_string |> String.to_charlist() |> :erlang.list_to_pid()
  end
end
