defmodule ShoppingList.Repo do
  use Ecto.Repo,
    otp_app: :shopping_list,
    adapter: Ecto.Adapters.SQLite3
end
