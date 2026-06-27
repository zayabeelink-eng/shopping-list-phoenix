defmodule ShoppingListWeb.ItemJSON do
  @doc """
  Renders a single item as JSON.
  """
  def show(%{item: item}) do
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

  @doc """
  Renders a list of items as JSON.
  """
  def index(%{items: items}) do
    %{data: Enum.map(items, &show/1)}
  end
end
