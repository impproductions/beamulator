defmodule Beamulator.Behaviors.BigSpender do
  use Beamulator.Behavior

  alias Beamulator.Actions

  @next_buy_wait_ticks 3600
  @decision_wait_ticks 300

  @impl Beamulator.Behavior
  def default_state() do
    %{
      name: Faker.Person.name(),
      email: Faker.Internet.email(),
      total_spent: 0,
      catalog: [],
      wait_ticks: 0
    }
  end

  @impl Beamulator.Behavior
  def act(_tick, %{name: name, state: state} = data) do
    cond do
      state.catalog == [] ->
        # Step 1: Fetch available products
        Logger.debug("BigSpender #{name} is checking available products.")

        {:ok, products} = execute(name, &Actions.user_list_available_products/1, %{
          name: name,
          email: state.email
        })

        new_wait_ticks = :rand.uniform(@decision_wait_ticks)

        new_data = %{
          data
          | state: %{state | catalog: products, wait_ticks: new_wait_ticks}
        }

        Logger.debug("BigSpender #{state.name} received a catalog with #{length(products)} items.")
        {:ok, new_data}

      state.wait_ticks > 0 ->
        # Step 2: Wait before purchasing
        new_data = %{
          data
          | state: %{state | wait_ticks: state.wait_ticks - 1}
        }

        Logger.debug("BigSpender #{state.name} is waiting to make a purchase (#{new_data.state.wait_ticks} ticks left).")
        {:ok, new_data}

      true ->
        # Step 3: Pick a product and buy it
        chosen_product = Enum.random(state.catalog)

        Logger.debug("BigSpender #{state.name} decided to buy #{chosen_product.product} for $#{chosen_product.price}")

        _ = execute(name, &Actions.user_purchase/1, %{
          name: name,
          email: state.email,
          product: chosen_product.product,
          price: chosen_product.price
        })

        new_data = %{
          data
          | state: %{
              state
              | total_spent: state.total_spent + chosen_product.price,
                catalog: [], # Clear catalog to trigger a new fetch next cycle
                wait_ticks: 1000 + :rand.uniform(@next_buy_wait_ticks - 1000)
            }
        }


        Logger.debug("BigSpender #{state.name} has spent a total of $#{new_data.state.total_spent}")
        {:ok, new_data}
    end
  end
end
