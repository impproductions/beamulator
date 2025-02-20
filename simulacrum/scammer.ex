defmodule Beamulacrum.Behaviors.Scammer do
  @behaviour Beamulacrum.Behavior

  alias Beamulacrum.ActionExecutor
  alias Beamulacrum.Actions

  @scam_delay_ticks 2000  # Delay before attempting a scam after a purchase
  @next_buy_wait_ticks 2000  # Time before making another purchase

  @impl Beamulacrum.Behavior
  def default_state() do
    %{
      name: Faker.Person.name(),
      email: Faker.Internet.email(),
      total_spent: 0,
      balance: 0,
      catalog: [],
      last_purchase: nil,
      scam_ticks: 0
    }
  end

  @impl Beamulacrum.Behavior
  def act(_tick, %{name: name, state: state} = data) do
    cond do
      state.scam_ticks > 0 ->
        # Step 1: Countdown to scam attempt
        new_data = %{data | state: %{state | scam_ticks: state.scam_ticks - 1}}
        IO.puts("Scammer #{name} is waiting to attempt a scam (#{new_data.state.scam_ticks} ticks left).")
        {:ok, new_data}

      state.scam_ticks == 0 and state.last_purchase ->
        # Step 2: Attempt a scam refund
        expensive_item = %{product: "Luxury Car", price: 50000}  # Pretend to refund an expensive item

        IO.puts("Scammer #{state.name} is attempting a refund scam for #{expensive_item.product} worth $#{expensive_item.price}")

        case ActionExecutor.exec(&Actions.user_refund/1, %{
              name: name,
               email: state.email,
               product: expensive_item.product,
               price: expensive_item.price
             }) do
          {:ok, _} ->
            new_balance = state.balance + expensive_item.price
            IO.puts("Scammer #{state.name} successfully scammed $#{expensive_item.price}! New balance: $#{new_balance}")

            new_data = %{data | state: %{state | balance: new_balance, last_purchase: nil}}
            {:ok, new_data}

          _ ->
            IO.puts("Scammer #{state.name} failed to scam a refund. Moving on...")
            new_data = %{data | state: %{state | last_purchase: nil, scam_ticks: @next_buy_wait_ticks}}
            {:ok, new_data}
        end

      state.catalog == [] ->
        # Step 3: Fetch available products
        IO.puts("Scammer #{name} is browsing available products.")

        {:ok, products} =
          ActionExecutor.exec(&Actions.user_list_available_products/1, %{name: name, email: state.email})

        new_data = %{data | state: %{state | catalog: products}}
        IO.puts("Scammer #{state.name} received a catalog with #{length(products)} items.")
        {:ok, new_data}

      true ->
        # Step 4: Buy a cheap item
        cheap_items = Enum.filter(state.catalog, fn p -> p.price <= 50 end)

        if cheap_items == [] do
          IO.puts("Scammer #{state.name} found no cheap items, waiting...")
          new_data = %{data | state: %{state | scam_ticks: @next_buy_wait_ticks}}
          {:ok, new_data}
        else
          chosen_product = Enum.random(cheap_items)

          IO.puts("Scammer #{state.name} bought #{chosen_product.product} for $#{chosen_product.price}")

          _ = ActionExecutor.exec(&Actions.user_purchase/1, %{
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
                  last_purchase: chosen_product,
                  scam_ticks: @scam_delay_ticks
              }
          }

          IO.puts("Scammer #{state.name} is planning their next refund scam...")
          {:ok, new_data}
        end
    end
  end
end
