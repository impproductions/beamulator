defmodule Beamulacrum.Behaviors.Onboarder do
  @behaviour Beamulacrum.Behavior

  # alias Beamulacrum.ActionExecutor
  alias Beamulacrum.Actions
  alias Beamulacrum.Connectors.Internal
  alias Beamulacrum.Tools.Time

  @next_onboard_hours 3  # Time before onboarding a new user

  @user_behaviors [
    Beamulacrum.Behaviors.BigSpender,
    Beamulacrum.Behaviors.CompulsiveBrowser,
    Beamulacrum.Behaviors.Scammer
  ]

  @impl Beamulacrum.Behavior
  def default_state() do
    %{
      name: Faker.Person.name(),
      onboarded_users: 0,
      wait_ticks: :rand.uniform(@next_onboard_hours * Time.hour())
    }
  end

  @impl Beamulacrum.Behavior
  def act(_tick, %{name: name, state: state} = data) do
    if state.wait_ticks > 0 do
      # Step 1: Wait before onboarding a new user
      new_data = %{data | state: %{state | wait_ticks: state.wait_ticks - 1}}
      IO.puts("Onboarder #{name} is waiting to onboard a new user (#{new_data.state.wait_ticks} ticks left).")
      {:ok, new_data}
    else
      # Step 2: Onboard a new user
      {:ok, new_user} = Actions.onboard_user(%{onboarder: name})

      %{name: new_user_name, email: new_email} = new_user

      new_behavior = Enum.random(@user_behaviors)

      case Internal.create_actor(new_user_name, new_behavior, %{email: new_email}) do
        {:ok, _pid} ->
          new_state = %{
            state
            | onboarded_users: state.onboarded_users + 1,
              wait_ticks: :rand.uniform(@next_onboard_hours * Time.hour())
          }

          IO.puts("Successfully onboarded #{new_user_name}. Total onboarded: #{new_state.onboarded_users}")
          {:ok, %{data | state: new_state}}

        {:error, reason} ->
          IO.puts("Failed to onboard #{new_user_name}: #{inspect(reason)}")
          {:ok, %{data | state: %{state | wait_ticks: 1000}}}  # Retry sooner if failed
      end
    end
  end
end
