defmodule ShoppingList.List do
  @moduledoc """
  The List context with full CRUD, reorder, and clear operations.
  All mutations broadcast to the "shopping_list_mutations" PubSub topic.
  """

  import Ecto.Query, warn: false

  alias ShoppingList.List.Item
  alias ShoppingList.Repo

  @topic "shopping_list_mutations"

  @doc """
  Subscribe to list mutation broadcasts.
  """
  def subscribe do
    Phoenix.PubSub.subscribe(ShoppingList.PubSub, @topic)
  end

  defp broadcast(event, data) do
    Phoenix.PubSub.broadcast(ShoppingList.PubSub, @topic, {event, data})
  end

  @doc """
  Returns the list of non-deleted items ordered by sort_order DESC, then inserted_at DESC.
  """
  def list_items do
    Item
    |> where([i], is_nil(i.deleted_at))
    |> order_by([i], desc: i.sort_order, desc: i.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns only incomplete, non-deleted items.
  """
  def list_active_items do
    Item
    |> where([i], is_nil(i.deleted_at) and not i.is_completed)
    |> order_by([i], desc: i.sort_order, desc: i.inserted_at)
    |> Repo.all()
  end

  @doc """
  Creates an item with valid attributes. Assigns sort_order as max(sort_order) + 1.
  """
  def create_item(attrs) when is_map(attrs) do
    max_sort =
      Item
      |> select([i], max(i.sort_order))
      |> Repo.one()
      |> Kernel.||(-1)

    attrs
    |> Item.changeset(%{sort_order: max_sort + 1})
    |> Repo.insert()
    |> case do
      {:ok, item} ->
        broadcast(:item_created, item)
        {:ok, item}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates an item with valid attributes.
  """
  def update_item(%Item{} = item, attrs) do
    item
    |> Item.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, item} ->
        broadcast(:item_updated, item)
        {:ok, item}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Soft deletes an item by setting deleted_at.
  """
  def delete_item(%Item{} = item) do
    item
    |> Item.changeset(%{deleted_at: NaiveDateTime.utc_now()})
    |> Repo.update()
    |> case do
      {:ok, item} ->
        broadcast(:item_deleted, item)
        {:ok, item}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Soft deletes all non-deleted items.
  """
  def clear_items do
    now = NaiveDateTime.utc_now()

    Item
    |> where([i], is_nil(i.deleted_at))
    |> Repo.update_all(set: [deleted_at: now])

    broadcast(:items_cleared, %{})

    :ok
  end

  @doc """
  Reorders items transactionally based on the provided list of IDs.
  The first ID in the list gets the highest sort_order.
  """
  def reorder_item_ids(item_ids) do
    total = length(item_ids)

    Repo.transaction(fn ->
      items = Repo.all(from i in Item, where: i.id in ^item_ids)

      if length(items) != total do
        Repo.rollback(:invalid_id)
      end

      item_map = Map.new(items, fn item -> {item.id, item} end)
      update_sort_orders(item_ids, item_map, total)
    end)
    |> case do
      :ok ->
        broadcast(:items_reordered, %{item_ids: item_ids})
        :ok

      :error ->
        :error
    end
  end

  defp update_sort_orders(item_ids, item_map, total) do
    Enum.with_index(item_ids)
    |> Enum.each(fn {id, index} ->
      item = Map.get(item_map, id)

      if is_nil(item) do
        Repo.rollback(:invalid_id)
      end

      sort_order = total - index - 1

      item
      |> Item.changeset(%{sort_order: sort_order})
      |> Repo.update!()
    end)

    :ok
  end

  @doc """
  Gets a single item by ID or raises if not found.
  """
  def get_item!(id) do
    Repo.get!(Item, id)
  end
end
