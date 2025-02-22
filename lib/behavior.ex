defmodule Beamulacrum.Behavior.Data do
  @enforce_keys [:name, :config, :state]
  defstruct [:name, :config, :state]

  @type t :: %__MODULE__{
          name: String.t(),
          config: map(),
          state: map()
        }
end

defmodule Beamulacrum.Behavior do
  @moduledoc """
  A behavior that all actor behaviors must implement.
  """
  @callback default_state() :: map()
  @callback act(tick :: integer(), Beamulacrum.Behavior.Data.t()) ::
              {:ok, Beamulacrum.Behavior.Data.t()} | {:error, String.t()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Beamulacrum.Behavior

      require Logger

      alias Beamulacrum.ActionExecutor

      def execute(name, action, args) do
        ActionExecutor.exec({__MODULE__, name}, action, args)
      end
    end
  end
end

defmodule Beamulacrum.Behavior.Registry do
  require Logger

  use GenServer

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def register(behavior_module, data \\ %{}) when is_atom(behavior_module) do
    GenServer.call(__MODULE__, {:register, behavior_module, data})
  end

  def list_behaviors do
    GenServer.call(__MODULE__, :list_behaviors)
  end

  def scan_and_register_all_behaviors do
    Logger.debug("Scanning and registering all behaviors...")

    :code.all_loaded()
    |> Enum.map(fn {module, _file} -> module end)
    |> Enum.filter(&module_in_behaviors_namespace?/1)
    |> Enum.map(fn module ->
      if function_exported?(module, :register, 0) do
        Logger.debug("Registering #{module}")
        module
      else
        Logger.debug("Module #{module} does not implement register/0")
      end
    end)
    |> Enum.each(fn module -> register(module) end)
  end

  defp module_in_behaviors_namespace?(module) do
    module
    |> Atom.to_string()
    |> String.starts_with?("Elixir.Beamulacrum.Behaviors.")
  end

  @impl true
  def init(_init_arg) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:register, module, data}, _from, state) do
    new_state = Map.put(state, module, data)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:list_behaviors, _from, state) do
    {:reply, state, state}
  end
end
