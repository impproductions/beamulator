defmodule Beamulator.Behavior.Data do
  @enforce_keys [:name, :config, :state]
  defstruct [:name, :config, :state]

  @type t :: %__MODULE__{
          name: String.t(),
          config: map(),
          state: map()
        }
end

defmodule Beamulator.Behavior.Complaint do
  @enforce_keys [:checker, :message, :severity, :code]
  defstruct [:checker, :message, :severity, :code]

  @type t :: %__MODULE__{
          checker: fun(),
          message: String.t(),
          severity: :urgent | :annoying | :justsayin,
          code: String.t()
        }
end

defmodule Beamulator.Behavior.ComplaintBuilder do
  defmacro build_complaint(checker, message, severity) do
    code = Macro.to_string(checker)
    quote do
      %Beamulator.Behavior.Complaint{
        checker: unquote(checker),
        message: unquote(message),
        severity: unquote(severity),
        code: unquote(code)
      }
    end
  end
end

defmodule Beamulator.Behavior do
  @doc """
  The default_state function should return the initial state of the behavior.
  """
  @callback default_state() :: map()

  @doc """
  The act function is called by the ActionExecutor to execute an action.
  It returns a tuple with:
    - the result of the action, either `:ok` or `:error`
    - the number of ticks to wait before the next action
    - the updated behavior data
  """
  @callback act(tick :: integer(), actor_data :: Beamulator.Behavior.Data.t()) ::
              {result :: :ok, wait_ticks :: integer(), new_data :: Beamulator.Behavior.Data.t()}
              | {:error, integer(), String.t()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Beamulator.Behavior

      require Logger
      alias Beamulator.ActionExecutor

      def execute(name, action) do
        execute(name, action, nil)
      end

      def execute(name, action, args) do
        Logger.debug("#{name} executing action #{inspect(action)} with args #{inspect(args)}")
        result = ActionExecutor.exec({__MODULE__, name}, action, args)
        Logger.info("#{name} executed action #{inspect(action)} with args #{inspect(args)}")
        result
      end

      def execute(name, action, args, complaint) when is_struct(complaint) do
        execute(name, action, args, [complaint])
      end

      def execute(name, action, args, complaints) when is_list(complaints) do
        {status, result} = execute(name, action, args)

        complaints
        |> Enum.each(fn complaint ->
          condition = complaint.checker.({status, result})

          if condition do
            Logger.error(
              "Complaint triggered: #{complaint.message}. Checker code: #{complaint.code}"
            )

            GenServer.cast(Beamulator.ActionLoggerPersistent, {
              :log_complaint,
              {
                __MODULE__,
                name,
                complaint.message,
                complaint.severity,
                action,
                args,
                %{
                  checker: complaint.code,
                  status: status,
                  result: result
                }
              }
            })
          end
        end)

        result
      end
    end
  end
end

defmodule Beamulator.Behavior.Registry do
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
    found =
      :code.all_loaded()
      |> Enum.map(fn {module, _file} -> module end)
      |> Enum.filter(&module_in_behaviors_namespace?/1)

    Logger.info("Found behaviors: #{inspect(found)}")

    found
    |> Enum.each(&register/1)
  end

  defp module_in_behaviors_namespace?(module) do
    module
    |> Atom.to_string()
    |> String.starts_with?("Elixir.Beamulator.Behaviors.")
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
