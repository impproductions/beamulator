defmodule Beamulator.Role.ActPayload do
  @enforce_keys [:simulation_data, :actor_serial_id, :actor_name, :actor_config, :actor_state, :actor_runtime]
  defstruct [:simulation_data, :actor_serial_id, :actor_name, :actor_config, :actor_state, :actor_runtime]

  @type t :: %__MODULE__{
          simulation_data: Beamulator.Simulation.SimulationData.t(),
          actor_serial_id: integer(),
          actor_name: binary(),
          actor_config: map(),
          actor_state: map(),
          actor_runtime: map()
        }
end

defmodule Beamulator.Role.Complaint do
  @enforce_keys [:trigger, :message, :severity, :code]
  defstruct [:trigger, :message, :severity, :code]

  @type t :: %__MODULE__{
          trigger: fun(),
          message: binary(),
          severity: :urgent | :annoying | :justsayin,
          code: binary()
        }
end

defmodule Beamulator.Role.ComplaintBuilder do
  defmacro build_complaint(trigger, message, severity) do
    code = Macro.to_string(trigger)

    quote do
      %Beamulator.Role.Complaint{
        trigger: unquote(trigger),
        message: unquote(message),
        severity: unquote(severity),
        code: unquote(code)
      }
    end
  end
end

defmodule Beamulator.Role do
  @doc """
  The default_state function should return the initial state of the role.
  """
  @callback default_state() :: map()

  @doc """
  The default_tags function should return a set of tags that the role is associated with.
  """
  @callback default_tags() :: MapSet.t()

  @doc """
  The act function is called by the ActionExecutor to execute an action.
  It returns a tuple with:
    - the result of the action, either `:ok` or `:error`
    - the time to wait before the next action, in ms, in simulation time (e.s. 1 second is 100ms in simulation time if the simulation is running at 10x speed)
    - the updated role data
  """
  @callback act(actor_data :: Beamulator.Role.ActPayload.t()) ::
              {:ok, wait_ms :: integer(), new_data :: Beamulator.Role.ActPayload.t()}
              | {:error, wait_ms :: integer(), new_data :: Beamulator.Role.ActPayload.t()}

  @doc """
  Optional. Lists actions invokable manually for this role (e.g. from the dashboard).
  Each entry: `%{name: String.t(), function: function(), default_args: any()}`.
  `default_args` should be JSON-serializable; it pre-fills the dashboard's args input.
  If unimplemented, the default introspects `Beamulator.Actions` and exposes every public function.
  """
  @callback actions() :: [%{name: String.t(), function: function(), default_args: any()}]

  @optional_callbacks actions: 0

  @doc """
  Default `actions/0` implementation injected by `use Beamulator.Role` —
  introspects `Beamulator.Actions` and exposes every public function.
  """
  def default_actions() do
    if Code.ensure_loaded?(Beamulator.Actions) do
      Beamulator.Actions.__info__(:functions)
      |> Enum.reject(fn {name, _arity} ->
        name in [:__info__, :module_info, :__source_info__]
      end)
      |> Enum.map(fn {name, arity} ->
        %{
          name: Atom.to_string(name),
          function: Function.capture(Beamulator.Actions, name, arity),
          default_args: default_args_for_arity(arity)
        }
      end)
      |> Enum.sort_by(& &1.name)
    else
      []
    end
  end

  def default_args_for_arity(0), do: []
  def default_args_for_arity(1), do: nil
  def default_args_for_arity(n), do: List.duplicate(nil, n)

  @doc """
  Resolves a list of action specs (atoms or `{atom, opts}` tuples) into the
  full action entry shape, looking arities up in `Beamulator.Actions`.

  Specs:
    * `:send_collected_metrics` — uses the introspected arity and default args
    * `{:send_collected_metrics, default_args: [[1, "t", 0.0]]}` — overrides defaults
    * `:all` — fall back to exposing every public function in `Beamulator.Actions`
  """
  def resolve_actions(:all), do: default_actions()
  def resolve_actions(nil), do: default_actions()
  def resolve_actions(specs) when is_list(specs), do: Enum.map(specs, &resolve_spec/1)

  defp resolve_spec(name) when is_atom(name), do: build_entry(name, [])
  defp resolve_spec({name, opts}) when is_atom(name) and is_list(opts), do: build_entry(name, opts)

  defp build_entry(name, opts) do
    {fun, arity} = lookup_action!(name)
    default_args = Keyword.get_lazy(opts, :default_args, fn -> default_args_for_arity(arity) end)
    %{name: Atom.to_string(name), function: fun, default_args: default_args}
  end

  defp lookup_action!(name) do
    unless Code.ensure_loaded?(Beamulator.Actions) do
      raise "Beamulator.Actions module is not loaded; cannot resolve action #{inspect(name)}"
    end

    case Enum.find(Beamulator.Actions.__info__(:functions), fn {n, _a} -> n == name end) do
      {^name, arity} -> {Function.capture(Beamulator.Actions, name, arity), arity}
      nil -> raise "Beamulator.Actions has no function named #{inspect(name)}"
    end
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour Beamulator.Role
      import Beamulator.Role, only: [expose_actions: 1]

      Module.register_attribute(__MODULE__, :__beamulator_exposed_actions__,
        accumulate: false,
        persist: false
      )

      @__beamulator_exposed_actions__ nil
      @before_compile Beamulator.Role

      require Logger
      alias Beamulator.ActionExecutor

      def execute(actor_data, action) do
        execute(actor_data, action, nil)
      end

      def execute(actor_data, action, args) do
        Logger.debug(
          "#{actor_data.actor_name} executing action #{inspect(action)} with args #{inspect(args)}"
        )

        result = ActionExecutor.exec({__MODULE__, actor_data.actor_name}, action, args)

        Logger.info(
          "#{actor_data.actor_name} executed action #{inspect(action)} with args #{inspect(args)}"
        )

        result
      end

      def execute(actor_data, action, args, complaint) when is_struct(complaint) do
        execute(actor_data, action, args, [complaint])
      end

      def execute(actor_data, action, args, complaints) when is_list(complaints) do
        {status, result} = execute(actor_data, action, args)

        complaints
        |> Enum.each(fn complaint ->
          condition = complaint.trigger.({status, result})

          if condition do
            Logger.error(
              "Complaint triggered: #{complaint.message}. trigger code: #{complaint.code}"
            )

            Beamulator.Sinks.fan_out_complaint(%Beamulator.Sinks.Complaint{
              actor_id: {__MODULE__, actor_data.actor_name},
              message: complaint.message,
              severity: complaint.severity,
              action: action,
              args: args,
              meta: %{
                trigger: complaint.code,
                status: status,
                result: result
              },
              sim_time_ms: Beamulator.Clock.get_simulation_now()
            })
          end
        end)

        {status, result}
      end
    end
  end

  @doc """
  Declares the actions a role exposes for manual invocation (e.g. from the dashboard).

  Pass a list of atoms or `{atom, opts}` tuples. Use `:all` to expose every
  public function in `Beamulator.Actions` (the default when `expose_actions/1`
  is not called).

  Example:

      use Beamulator.Role
      expose_actions [
        :send_collected_metrics,
        {:flush, default_args: [%{force: true}]}
      ]
  """
  defmacro expose_actions(specs) do
    quote do
      @__beamulator_exposed_actions__ unquote(specs)
    end
  end

  defmacro __before_compile__(env) do
    if Module.defines?(env.module, {:actions, 0}) do
      nil
    else
      quote do
        def actions(), do: Beamulator.Role.resolve_actions(@__beamulator_exposed_actions__)
      end
    end
  end
end
