defmodule ShoppingListWeb.ItemController do
  use ShoppingListWeb, :controller

  alias ShoppingList.List

  def index(conn, _params) do
    items = List.list_items()
    render(conn, :index, items: items)
  end

  def create(conn, %{"item" => item_params}) do
    case List.create_item(item_params) do
      {:ok, item} ->
        conn
        |> put_status(:created)
        |> render(:show, item: item)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid parameters", details: format_errors(changeset)})
    end
  end

  def update(conn, %{"id" => id, "item" => item_params}) do
    item = List.get_item!(id)

    case List.update_item(item, item_params) do
      {:ok, item} ->
        render(conn, :show, item: item)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid parameters", details: format_errors(changeset)})
    end
  rescue
    Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> json(%{error: "Item not found"})
  end

  def delete(conn, %{"id" => id}) do
    item = List.get_item!(id)

    case List.delete_item(item) do
      {:ok, _item} ->
        send_resp(conn, :no_content, "")

      {:error, _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to delete item"})
    end
  rescue
    Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> json(%{error: "Item not found"})
  end

  def reorder(conn, %{"item_ids" => item_ids}) when is_list(item_ids) do
    case List.reorder_item_ids(item_ids) do
      :ok ->
        send_resp(conn, :ok, "")

      :error ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid item IDs"})
    end
  end

  def reorder(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "item_ids must be a list"})
  end

  def clear(conn, _params) do
    _ = List.clear_items()
    send_resp(conn, :ok, "")
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
