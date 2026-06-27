defmodule ShoppingListWeb.ItemLive.Index do
  use ShoppingListWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :items, [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>Shopping list UI coming soon</div>
    """
  end
end
