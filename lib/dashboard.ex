defmodule Dashboard do
  use GenServer

  @pages [:overview, :behavior, :actor]

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def start() do
    IO.puts("Starting dashboard...")
    start_link([])
  end

  def start(page, arg \\ nil) when page in @pages do
    IO.puts("Starting dashboard with page #{page} and arg #{arg}")
    start_link([])
    page_set(page, arg)
  end

  def stop() do
    IO.puts("Stopping dashboard...")
    GenServer.stop(__MODULE__)
  end

  def page_set(page) do
    IO.puts("Setting page to #{page}")
    GenServer.cast(__MODULE__, {:page_set, page, nil})
  end

  def page_set(page, arg) when is_atom(page) do
    IO.puts("Setting page to #{page} with arg #{arg}")
    GenServer.cast(__MODULE__, {:page_set, page, arg})
  end

  def init(state) do
    state =
      if Map.get(state, :page) == nil do
        Map.put(state, :page, :overview)
      end

    schedule_frame()
    {:ok, state}
  end

  def handle_info(:frame, state) do
    display_dashboard(state)
    schedule_frame()
    {:noreply, state}
  end

  def handle_cast({:page_set, page, arg}, state)
      when page in [:overview, :behavior, :actor] do
    {:noreply,
     state
     |> Map.put(:page, page)
     |> Map.put(:page_arg, arg)}
  end

  def handle_cast(_, state) do
    {:noreply, state}
  end

  defp schedule_frame() do
    Process.send_after(self(), :frame, div(1000, 2))
  end

  defp display_dashboard(state) do
    case state.page do
      :overview -> display_overview(state)
      :behavior -> display_behavior_state(state)
      :actor -> display_actor_state(state)
    end
  end

  def display_behavior_state(state) do
    display_header(state)
    IO.puts("Behavior State")
    IO.puts("\n--------- Behaviors ---------")

    Manage.behavior_list()
    |> Map.keys()
    |> Enum.map(fn behavior ->
      Manage.actors_by_behavior(behavior)
      |> Enum.map(fn {_, _, name, pid} ->
        "#{name} [#{inspect(pid)}]"
      end)
      |> Enum.join(", ")
      |> then(fn actors -> "#{behavior}:\n #{actors}" end)
    end)
    |> Enum.join("\n")
    |> IO.puts()
  end

  def display_actor_state(state) do
    actor = Map.get(state, :page_arg)

    display_header(state)
    IO.puts("------------------ Actor #{actor} ------------------")
    Manage.actor_state(actor)
    |> IO.puts()
  end

  def display_overview(state) do
    display_header(state)
    IO.puts("\n------------------ Overview ------------------")
    IO.puts("\n--------- Actors ---------")
    IO.puts(actor_counts())
    IO.puts("\n--------- Behaviors ---------")
    IO.puts(available_behaviors())
  end

  defp display_header(state) do
    IO.write(IO.ANSI.clear())
    IO.write(IO.ANSI.home())
    IO.puts("Dashboard #{Map.get(state, :page)} #{Map.get(state, :page_arg)}\t\t available pages: [#{@pages |> Enum.map(&inspect/1) |> Enum.join(", ")}]")
    IO.puts("\n--------- Clock ---------")
    IO.puts("Current tick: #{Beamulator.Clock.get_tick_number()}" <>
    "\t\tRunning at #{Beamulator.Clock.get_fps()} TPS\n")
  end

  defp actor_counts() do
    Manage.actor_list()
    |> Enum.group_by(fn {behavior, _id, _name, _pid} -> behavior end)
    |> Enum.map(fn {behavior, actors} -> "#{strip_namespace(behavior)}: #{length(actors)}" end)
    |> Enum.join("\n")
  end

  defp available_behaviors() do
    Manage.behavior_list()
    |> Enum.map(fn {behavior, _data} -> strip_namespace(behavior) end)
    |> Enum.join("\n")
  end

  defp strip_namespace(behavior) do
    behavior
    |> Atom.to_string()
    |> String.split(".")
    |> tl()
    |> Enum.join(".")
  end
end
