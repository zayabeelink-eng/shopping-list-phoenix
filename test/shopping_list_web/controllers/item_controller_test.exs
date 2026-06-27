defmodule ShoppingListWeb.ItemControllerTest do
  use ShoppingListWeb.ConnCase, async: false

  alias ShoppingList.List

  @create_attrs %{"name" => "Milk", "quantity" => 2}
  @update_attrs %{"name" => "Almond Milk", "quantity" => 3}

  defp create_item(_) do
    {:ok, item} = List.create_item(@create_attrs)
    %{item: item}
  end

  describe "GET /api/items" do
    test "returns empty list initially", %{conn: conn} do
      conn = get(conn, ~p"/api/items")
      json = json_response(conn, 200)
      assert json["data"] == []
    end

    test "returns list of items", %{conn: conn} do
      {:ok, _item} = List.create_item(%{"name" => "Bread"})
      conn = get(conn, ~p"/api/items")
      json = json_response(conn, 200)
      assert length(json["data"]) == 1
      assert Enum.at(json["data"], 0)["name"] == "Bread"
    end
  end

  describe "POST /api/items" do
    test "creates an item and returns it with ID", %{conn: conn} do
      conn = post(conn, ~p"/api/items", item: @create_attrs)
      json = json_response(conn, 201)
      assert json["name"] == "Milk"
      assert json["quantity"] == 2
      assert json["id"] != nil
    end

    test "with blank name returns 422", %{conn: conn} do
      conn = post(conn, ~p"/api/items", item: %{"name" => ""})
      assert json_response(conn, 422)["error"] == "Invalid parameters"
    end

    test "with missing name returns 422", %{conn: conn} do
      conn = post(conn, ~p"/api/items", item: %{})
      assert json_response(conn, 422)["error"] == "Invalid parameters"
    end
  end

  describe "PUT /api/items/:id" do
    setup [:create_item]

    test "updates item fields", %{conn: conn, item: item} do
      conn = put(conn, ~p"/api/items/#{item.id}", item: @update_attrs)
      json = json_response(conn, 200)
      assert json["name"] == "Almond milk"
      assert json["quantity"] == 3
    end

    test "with invalid ID returns 404", %{conn: conn} do
      conn = put(conn, ~p"/api/items/invalid-id", item: @update_attrs)
      assert json_response(conn, 404)["error"] == "Item not found"
    end
  end

  describe "DELETE /api/items/:id" do
    setup [:create_item]

    test "removes item", %{conn: conn, item: item} do
      conn = delete(conn, ~p"/api/items/#{item.id}")
      assert response(conn, 204)
      assert List.list_items() == []
    end

    test "with invalid ID returns 404", %{conn: conn} do
      conn = delete(conn, ~p"/api/items/invalid-id")
      assert json_response(conn, 404)["error"] == "Item not found"
    end
  end

  describe "PUT /api/items/reorder" do
    setup [:create_item]

    test "sets correct sort_order", %{conn: conn, item: item1} do
      {:ok, item2} = List.create_item(%{"name" => "Second"})
      {:ok, item3} = List.create_item(%{"name" => "Third"})

      conn = put(conn, ~p"/api/items/reorder", %{"item_ids" => [item1.id, item3.id, item2.id]})
      assert response(conn, 200)

      items = List.list_items()
      assert Enum.at(items, 0).id == item1.id
      assert Enum.at(items, 1).id == item3.id
      assert Enum.at(items, 2).id == item2.id
    end

    test "with invalid ID returns 422", %{conn: conn} do
      conn = put(conn, ~p"/api/items/reorder", %{"item_ids" => ["invalid-id"]})
      assert json_response(conn, 422)["error"] == "Invalid item IDs"
    end
  end

  describe "DELETE /api/items/clear" do
    test "removes all items", %{conn: conn} do
      List.create_item(%{"name" => "First"})
      List.create_item(%{"name" => "Second"})

      conn = delete(conn, ~p"/api/items/clear")
      assert response(conn, 200)
      assert List.list_items() == []
    end
  end
end
