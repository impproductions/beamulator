defmodule Dashboard do
  alias Beamulator.Clock
  alias Beamulator.Utils
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

    list = Utils.Actors.select_all()

    list
    |> Enum.group_by(fn {_, {b, _, _}} -> inspect(b) end)
    |> Enum.map(fn {b, actors} ->
      %{
        name: b,
        count: Enum.count(actors),
        actors: Enum.map(actors, fn {_, {_, n, _}} -> n end)
      }
    end)

    |> Enum.each(fn %{name: name, count: count, actors: actors} ->
      IO.puts("\n#{name} (#{count})")
      IO.puts(actors |> Enum.join(", "))
    end)
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
  end

  defp display_header(state) do
    IO.write(IO.ANSI.clear())
    IO.write(IO.ANSI.home())

    IO.puts(
      "Dashboard #{Map.get(state, :page)} #{Map.get(state, :page_arg)}\t\t available pages: [#{@pages |> Enum.map(&inspect/1) |> Enum.join(", ")}]"
    )

    IO.puts("\n--------- Clock ---------")
    IO.puts("Real duration: #{Clock.get_real_duration_ms() |> Utils.Duration.to_string()}")
    IO.puts("Simulation duration: #{Clock.get_simulation_duration_ms() |> Utils.Duration.to_string()}")
  end

  defp actor_counts() do
    Manage.actor_list()
    |> Enum.group_by(fn {behavior, _id, _name, _pid} -> behavior end)
    |> Enum.map(fn {behavior, actors} -> "#{strip_namespace(behavior)}: #{length(actors)}" end)
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
