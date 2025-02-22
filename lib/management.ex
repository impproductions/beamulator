defmodule AlertFunctions do
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
    if Node.self() == :beamulacrum do
      IO.puts(
        "!!! ALERT !!! The function #{mod}.#{fun}/#{arity} is for manual use only. You're not supposed to use this in code. If you're seeing this message after manually running a Manage.[function] command in a shell, you can ignore it."
      )
    end
  end
end

defmodule Manage do
  require AlertFunctions
  import AlertFunctions, only: [defwithalert: 2]

  defwithalert behavior_list() do
    Beamulacrum.Behavior.Registry.list_behaviors()
  end

  defwithalert actor_list() do
    Registry.lookup(Beamulacrum.ActorRegistry, :actors)
    |> Enum.map(&simplify_actor_data/1)
  end

  defp simplify_actor_data({pid, {behavior, serial_id, name}}) do
    {behavior, serial_id, name, pid}
  end

  defwithalert actor_state(pid_string) when is_binary(pid_string) do
    pid_string =
      if String.starts_with?(pid_string, "#PID") do
        String.slice(pid_string, 4..-1//1)
      else
        pid_string
      end

    p_id = pid_string |> String.to_charlist() |> :erlang.list_to_pid()

    case Registry.lookup(Beamulacrum.ActorRegistry, :actors)
         |> Enum.find(fn {pid, _} -> pid == p_id end) do
      {pid, {behavior, serial_id, name}} ->
        actor_state = GenServer.call(pid, :state)

        IO.puts("""
        Actor #{name} (#{behavior}) (#{serial_id}) [#{inspect(pid)}]
        State: #{inspect(actor_state, pretty: true, syntax_colors: [number: :red, atom: :cyan, string: :green, identifier: :blue])}
        """)

        :ok

      _ ->
        "Actor not found"
    end
  end

  defwithalert actor_spawn(behavior_module) do
    behaviour_name = behavior_module |> Atom.to_string() |> String.split(".") |> List.last()
    name = "#{behaviour_name} #{Beamulacrum.Tools.increasing_int()}"
    actor_spawn(name, behavior_module, %{})
  end

  defwithalert actor_spawn(name, behavior_module) do
    actor_spawn(name, behavior_module, %{})
  end

  defwithalert actor_spawn(name, behavior_module, config) do
    Beamulacrum.SupervisorActors.start_actor(name, behavior_module, config)
  end

  defwithalert actor_kill(pid_string) when is_binary(pid_string) do
    pid_string =
      if String.starts_with?(pid_string, "#PID") do
        String.slice(pid_string, 4..-1//1)
      else
        pid_string
      end

    IO.puts("Killing actor with PID #{pid_string}")
    pid = pid_string |> String.to_charlist() |> :erlang.list_to_pid()

    DynamicSupervisor.terminate_child(Beamulacrum.SupervisorActors, pid)
  end

  def actors_by_behavior(behavior_module) do
    Registry.lookup(Beamulacrum.ActorRegistry, :actors)
    |> Enum.filter(fn {_, {behavior, _, _}} -> behavior == behavior_module end)
    |> Enum.map(&simplify_actor_data/1)
  end

end
