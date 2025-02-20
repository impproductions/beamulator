defmodule Beamulacrum.Actions do
  @moduledoc "User-defined actions."

  require Logger

  def onboard_user(%{onboarder: onboarder}) do
    IO.puts("Onboarder #{onboarder} is creating a new user")
    Logger.info("Onboarder #{onboarder} is creating a new user")

    new_user_name = Faker.Person.name() <> " " <> to_string(Beamulacrum.Tools.increasing_int())
    new_email = Faker.Internet.email()

    IO.puts("Onboarder #{onboarder} created a new user: #{new_user_name} with email #{new_email}")
    Logger.info("Onboarder #{onboarder} created a new user: #{new_user_name} with email #{new_email}")
    {:ok, %{name: new_user_name, email: new_email}}
  end

  def user_purchase(%{name: name, email: email, product: product, price: price}) do
    IO.puts("User #{name} (#{email}) purchased product #{product} for #{price}")
    Logger.info("User #{name} (#{email}) purchased product #{product} for #{price}")
    {:ok, nil}
  end

  def user_refund(%{name: name, email: email, product: product, price: price}) do
    IO.puts("User #{name} (#{email}) requested a refund for product #{product} worth #{price}")
    Logger.info("User #{name} (#{email}) requested a refund for product #{product} worth #{price}")

    case :rand.uniform(2) do
      1 ->
        IO.puts("Refund request for user #{email} failed")
        Logger.error("Refund request for user #{email} failed")
        {:error, "Refund request failed"}
      _ ->
        IO.puts("Refund request for user #{email} succeeded")
        Logger.info("Refund request for user #{email} succeeded")
        {:ok, nil}
    end
    {:ok, nil}
  end

  def user_change_email(%{name: name, email: email, new_email: new_email}) do
    IO.puts("User #{name} (#{email}) changed their email to #{new_email}")
    Logger.info("User #{name} (#{email}) changed their email to #{new_email}")
    {:ok, nil}
  end

  def user_list_available_products(%{name: name, email: email}) do
    IO.puts("User #{name} (#{email}) is browsing available products")
    Logger.info("User #{name} (#{email}) is browsing available products")
    all_products = [
      %{product: "Luxury Watch", price: 5000},
      %{product: "Sports Car", price: 75000},
      %{product: "Private Jet Rental", price: 200000},
      %{product: "Designer Handbag", price: 12000},
      %{product: "High-End Gaming PC", price: 8000},
      %{product: "Exclusive Club Membership", price: 15000},
      %{product: "Fine Art Piece", price: 50000},
      %{product: "Luxury Watch", price: 5000},
      %{product: "Sports Car", price: 75000},
      %{product: "Private Jet Rental", price: 200000},
      %{product: "Socks", price: 5},
      %{product: "T-Shirt", price: 10},
      %{product: "Sneakers", price: 50},
      %{product: "Jeans", price: 100},
      %{product: "Jacket", price: 200},
      %{product: "Smartphone", price: 1000},
      %{product: "Laptop", price: 1500},
    ]
    product_list = Enum.take_random(all_products, :rand.uniform(Enum.count(all_products)))
    IO.puts("User #{email} received a list of #{length(product_list)} available products")
    Logger.info("User #{email} received a list of #{length(product_list)} available products")
    {:ok, product_list}
  end
end
