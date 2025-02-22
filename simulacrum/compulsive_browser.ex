defmodule Beamulacrum.Behaviors.CompulsiveBrowser do
  use Beamulacrum.Behavior

  alias Beamulacrum.ActionExecutor
  alias Beamulacrum.Actions

  @next_buy_wait_ticks 5000  # Long delay between small purchases
  @browse_wait_ticks 200      # Shorter delay before browsing again

  @impl Beamulacrum.Behavior
  def default_state() do
    %{
      name: Faker.Person.name(),
      email: Faker.Internet.email(),
      total_spent: 0,
      catalog: [],
      wait_ticks: 0
    }
  end

  @impl Beamulacrum.Behavior
  def act(_tick, %{name: name, state: state} = data) do
    cond do
      state.wait_ticks > 0 ->
        # Step 1: Waiting before browsing or purchasing
        new_data = %{
          data
          | state: %{state | wait_ticks: state.wait_ticks - 1}
        }

        IO.puts("CompulsiveBrowser #{state.name} is waiting to browse again (#{new_data.state.wait_ticks} ticks left).")
        {:ok, new_data}

      state.catalog == [] or :rand.uniform(3) == 1 ->
        # Step 2: Browse products frequently
        IO.puts("CompulsiveBrowser #{name} is browsing available products.")

        {:ok, products} =
          ActionExecutor.exec({__MODULE__, name}, &Actions.user_list_available_products/1, %{
            name: name,
            email: state.email
          })

        new_wait_ticks = :rand.uniform(@browse_wait_ticks)

        new_data = %{
          data
          | state: %{state | catalog: products, wait_ticks: new_wait_ticks}
        }

        IO.puts("CompulsiveBrowser #{state.name} refreshed their catalog with #{length(products)} items.")
        {:ok, new_data}

      :rand.uniform(5) == 1 ->
        # Step 3: Occasionally buy a small item
        small_items = Enum.filter(state.catalog, fn p -> p.price <= 100 end)

        if small_items == [] do
          IO.puts("CompulsiveBrowser #{state.name} didn't find any small items to buy.")
          {:ok, data}
        else
          chosen_product = Enum.random(small_items)

          IO.puts("CompulsiveBrowser #{state.name} decided to buy #{chosen_product.product} for $#{chosen_product.price}")

          _ = ActionExecutor.exec({__MODULE__, name}, &Actions.user_purchase/1, %{
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
                  wait_ticks: 1000 + :rand.uniform(@next_buy_wait_ticks - 1000)
              }
          }

          IO.puts("CompulsiveBrowser #{state.name} has spent a total of $#{new_data.state.total_spent}")
          {:ok, new_data}
        end

      true ->
        # Step 4: Default to waiting
        new_wait_ticks = :rand.uniform(@browse_wait_ticks)
        new_data = %{data | state: %{state | wait_ticks: new_wait_ticks}}

        IO.puts("CompulsiveBrowser #{state.name} is idly browsing and waiting.")
        {:ok, new_data}
    end
  end
end
