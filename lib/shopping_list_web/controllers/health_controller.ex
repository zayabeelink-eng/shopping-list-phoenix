defmodule ShoppingListWeb.HealthController do
  use ShoppingListWeb, :controller

  alias ShoppingList.List.Item
  alias ShoppingList.Repo
  import Ecto.Query

  def index(conn, _params) do
    item_count =
      Item
      |> where([i], is_nil(i.deleted_at))
      |> Repo.aggregate(:count, :id)

    database = if is_integer(item_count), do: "connected", else: "disconnected"

    conn
    |> put_resp_content_type("application/json")
    |> json(%{status: "ok", item_count: item_count, database: database})
  rescue
    _ ->
      conn
      |> put_resp_content_type("application/json")
      |> json(%{status: "error", item_count: 0, database: "disconnected"})
  end
end
