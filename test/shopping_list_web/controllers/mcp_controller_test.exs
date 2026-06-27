defmodule ShoppingListWeb.McpControllerTest do
  use ShoppingListWeb.ConnCase, async: false

  alias ShoppingList.List

  @rpc_id 1

  defp mcp_request(method, params) do
    %{
      "jsonrpc" => "2.0",
      "method" => method,
      "params" => params,
      "id" => @rpc_id
    }
  end

  defp post_mcp(conn, method, params \\ %{}) do
    post(conn, ~p"/api/mcp", mcp_request(method, params))
  end

  setup do
    List.clear_items()
    :ok
  end

  describe "list_items" do
    test "returns empty array initially", %{conn: conn} do
      conn = post_mcp(conn, "list_items")
      json = json_response(conn, 200)
      assert json["jsonrpc"] == "2.0"
      assert json["id"] == @rpc_id
      assert json["result"] == []
    end

    test "returns all items", %{conn: conn} do
      List.create_item(%{"name" => "Bread"})
      List.create_item(%{"name" => "Cheese"})

      conn = post_mcp(conn, "list_items")
      json = json_response(conn, 200)
      assert length(json["result"]) == 2
    end
  end

  describe "add_item" do
    test "creates item and returns it", %{conn: conn} do
      conn = post_mcp(conn, "add_item", %{"name" => "Milk", "quantity" => 2})
      json = json_response(conn, 200)
      assert json["result"]["name"] == "Milk"
      assert json["result"]["quantity"] == 2
      assert json["result"]["id"] != nil
    end

    test "with missing name returns error", %{conn: conn} do
      conn = post_mcp(conn, "add_item", %{"quantity" => 2})
      json = json_response(conn, 200)
      assert json["error"]["code"] == -32_602
      assert json["error"]["message"] == "name is required"
    end

    test "with empty name returns error", %{conn: conn} do
      conn = post_mcp(conn, "add_item", %{"name" => ""})
      json = json_response(conn, 200)
      assert json["error"]["code"] == -32_602
    end
  end

  describe "update_item" do
    setup do
      {:ok, item} = List.create_item(%{"name" => "Milk"})
      %{item: item}
    end

    test "modifies item fields", %{conn: conn, item: item} do
      conn =
        post_mcp(conn, "update_item", %{
          "id" => item.id,
          "attrs" => %{"name" => "Almond Milk", "quantity" => 3}
        })

      json = json_response(conn, 200)
      assert json["result"]["name"] == "Almond milk"
      assert json["result"]["quantity"] == 3
    end

    test "with invalid ID returns error", %{conn: conn} do
      conn =
        post_mcp(conn, "update_item", %{
          "id" => "invalid-id",
          "attrs" => %{"name" => "Something"}
        })

      json = json_response(conn, 200)
      assert json["error"]["code"] == -32_602
      assert json["error"]["message"] == "Item not found"
    end
  end

  describe "remove_item" do
    setup do
      {:ok, item} = List.create_item(%{"name" => "Milk"})
      %{item: item}
    end

    test "deletes item", %{conn: conn, item: item} do
      conn = post_mcp(conn, "remove_item", %{"id" => item.id})
      json = json_response(conn, 200)
      assert json["result"]["status"] == "ok"
      assert List.list_items() == []
    end

    test "with invalid ID returns error", %{conn: conn} do
      conn = post_mcp(conn, "remove_item", %{"id" => "invalid-id"})
      json = json_response(conn, 200)
      assert json["error"]["code"] == -32_602
      assert json["error"]["message"] == "Item not found"
    end
  end

  describe "reorder_items" do
    setup do
      {:ok, item1} = List.create_item(%{"name" => "First"})
      {:ok, item2} = List.create_item(%{"name" => "Second"})
      {:ok, item3} = List.create_item(%{"name" => "Third"})
      %{item1: item1, item2: item2, item3: item3}
    end

    test "updates sort_order correctly", %{conn: conn, item1: item1, item2: item2, item3: item3} do
      conn =
        post_mcp(conn, "reorder_items", %{
          "item_ids" => [item1.id, item3.id, item2.id]
        })

      json = json_response(conn, 200)
      assert json["result"]["status"] == "ok"

      items = List.list_items()
      assert Enum.at(items, 0).id == item1.id
      assert Enum.at(items, 1).id == item3.id
      assert Enum.at(items, 2).id == item2.id
    end

    test "with invalid IDs returns error", %{conn: conn} do
      conn =
        post_mcp(conn, "reorder_items", %{
          "item_ids" => ["invalid-id"]
        })

      json = json_response(conn, 200)
      assert json["error"]["code"] == -32_602
      assert json["error"]["message"] == "Invalid item IDs"
    end
  end

  describe "clear_items" do
    test "removes all items", %{conn: conn} do
      List.create_item(%{"name" => "First"})
      List.create_item(%{"name" => "Second"})

      conn = post_mcp(conn, "clear_items")
      json = json_response(conn, 200)
      assert json["result"]["status"] == "ok"
      assert List.list_items() == []
    end
  end

  describe "error handling" do
    test "unknown method returns -32601", %{conn: conn} do
      conn = post_mcp(conn, "unknown_method")
      json = json_response(conn, 200)
      assert json["error"]["code"] == -32_601
      assert json["error"]["message"] =~ "unknown_method"
    end

    test "missing jsonrpc field returns -32600", %{conn: conn} do
      conn = post(conn, ~p"/api/mcp", %{"id" => @rpc_id})
      json = json_response(conn, 400)
      assert json["error"]["code"] == -32_600
    end
  end
end
