defmodule ShoppingListWeb.ItemJSON do
  def render("show.json", %{item: item}) do
    %{
      id: item.id,
      name: item.name,
      quantity: item.quantity,
      is_completed: item.is_completed,
      sort_order: item.sort_order,
      inserted_at: item.inserted_at,
      updated_at: item.updated_at
    }
  end

  def render("index.json", %{items: items}) do
    %{data: Enum.map(items, &item_to_map/1)}
  end

  defp item_to_map(item) do
    %{
      id: item.id,
      name: item.name,
      quantity: item.quantity,
      is_completed: item.is_completed,
      sort_order: item.sort_order,
      inserted_at: item.inserted_at,
      updated_at: item.updated_at
    }
  end
end
