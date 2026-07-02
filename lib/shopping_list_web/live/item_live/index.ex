defmodule ShoppingListWeb.ItemLive.Index do
  use ShoppingListWeb, :live_view

  alias ShoppingList.List

  embed_templates "item_live/*"

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      _ = List.subscribe()
    end

    socket =
      socket
      |> assign(:form, to_form(%{"name" => "", "quantity" => 1}))
      |> assign(:show_completed, false)
      |> stream(:items, List.list_items(), reset: true)

    {:ok, socket}
  end

  @impl true
  def handle_info({:item_created, _item}, socket) do
    {:noreply, stream(socket, :items, filtered_items(socket), reset: true)}
  end

  def handle_info({:item_updated, _item}, socket) do
    {:noreply, stream(socket, :items, filtered_items(socket), reset: true)}
  end

  def handle_info({:item_deleted, _item}, socket) do
    {:noreply, stream(socket, :items, filtered_items(socket), reset: true)}
  end

  def handle_info({:items_reordered, _data}, socket) do
    {:noreply, stream(socket, :items, filtered_items(socket), reset: true)}
  end

  def handle_info({:items_cleared, _data}, socket) do
    {:noreply, stream(socket, :items, [], reset: true)}
  end

  def handle_info(_info, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"name" => name, "quantity" => quantity}, socket) do
    quantity =
      case Integer.parse(quantity) do
        {int, _} when int > 0 -> int
        _ -> 1
      end

    {:noreply,
     assign(socket, :form, to_form(%{"name" => String.trim(name), "quantity" => quantity}))}
  end

  def handle_event("save", %{"name" => name, "quantity" => quantity}, socket) do
    name = String.trim(name)

    if name == "" do
      {:noreply,
       socket
       |> assign(
         :form,
         to_form(%{"name" => "", "quantity" => 1}, errors: [name: "can't be blank"])
       )}
    else
      quantity =
        case Integer.parse(quantity) do
          {int, _} when int > 0 -> int
          _ -> 1
        end

      case List.create_item(%{"name" => name, "quantity" => quantity}) do
        {:ok, _item} ->
          {:noreply, assign(socket, :form, to_form(%{"name" => "", "quantity" => 1}))}

        {:error, changeset} ->
          {:noreply, assign(socket, :form, to_form(changeset))}
      end
    end
  end

  def handle_event("toggle", %{"id" => id}, socket) do
    item = List.get_item!(id)
    _ = List.update_item(item, %{is_completed: !item.is_completed})
    {:noreply, socket}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    _ = List.get_item!(id) |> List.delete_item()
    {:noreply, socket}
  end

  def handle_event("update-quantity", %{"id" => id, "quantity" => quantity}, socket) do
    item = List.get_item!(id)

    quantity =
      case Integer.parse(quantity) do
        {int, _} when int > 0 -> int
        _ -> 1
      end

    _ = List.update_item(item, %{quantity: quantity})
    {:noreply, socket}
  end

  def handle_event("reorder", %{"ids" => ids}, socket) do
    _ = List.reorder_item_ids(ids)
    {:noreply, socket}
  end

  def handle_event("toggle-completed-filter", _params, socket) do
    show = not socket.assigns.show_completed

    items = if show, do: List.list_items(), else: List.list_active_items()

    {:noreply,
     socket
     |> assign(:show_completed, show)
     |> stream(:items, items, reset: true)}
  end

  defp filtered_items(socket) do
    if socket.assigns.show_completed do
      List.list_items()
    else
      List.list_active_items()
    end
  end
end
