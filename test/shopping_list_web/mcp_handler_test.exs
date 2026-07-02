defmodule ShoppingListWeb.MCPHandlerTest do
  use ShoppingList.DataCase, async: false

  alias ShoppingList.List
  alias ShoppingListWeb.MCPHandler

  setup do
    List.clear_items()
    :ok
  end

  describe "handle_initialize/2" do
    test "returns server info and capabilities" do
      state = %{}

      {:ok, result, _state} =
        MCPHandler.handle_initialize(%{"protocolVersion" => "2025-03-26"}, state)

      assert result.protocolVersion == "2025-03-26"
      assert result.serverInfo.name == "shopping-list-phoenix"
      assert result.serverInfo.version == "0.1.0"
      assert result.capabilities.tools == %{}
    end
  end

  describe "handle_list_tools/2" do
    test "returns all 5 tools" do
      state = %{}
      {:ok, tools, _next_cursor, _state} = MCPHandler.handle_list_tools(nil, state)

      assert length(tools) == 5

      names = Enum.map(tools, fn tool -> tool.name end)
      assert "list_items" in names
      assert "add_item" in names
      assert "update_item" in names
      assert "remove_item" in names
      assert "reorder_items" in names
    end
  end

  describe "handle_call_tool - list_items" do
    test "returns empty list when no items" do
      state = %{}

      {:ok, [%{type: "text", text: json}], _state} =
        MCPHandler.handle_call_tool("list_items", %{}, state)

      assert Jason.decode!(json) == []
    end

    test "returns all items" do
      state = %{}
      {:ok, _item1} = List.create_item(%{"name" => "Milk", "quantity" => 2})
      {:ok, _item2} = List.create_item(%{"name" => "Bread", "quantity" => 1})

      {:ok, [%{type: "text", text: json}], _state} =
        MCPHandler.handle_call_tool("list_items", %{}, state)

      items = Jason.decode!(json)
      assert length(items) == 2
    end
  end

  describe "handle_call_tool - add_item" do
    test "adds an item with valid name" do
      state = %{}

      {:ok, [%{type: "text", text: json}], _state} =
        MCPHandler.handle_call_tool("add_item", %{"name" => "Milk", "quantity" => 2}, state)

      result = Jason.decode!(json)
      assert result["name"] == "Milk"
      assert result["quantity"] == 2
    end

    test "adds an item with default quantity" do
      state = %{}

      {:ok, [%{type: "text", text: json}], _state} =
        MCPHandler.handle_call_tool("add_item", %{"name" => "Bread"}, state)

      result = Jason.decode!(json)
      assert result["name"] == "Bread"
      assert result["quantity"] == 1
    end

    test "returns error when name is missing" do
      state = %{}

      {:ok, %{content: [%{type: "text", text: msg}], isError: true}, _state} =
        MCPHandler.handle_call_tool("add_item", %{}, state)

      assert msg == "name is required"
    end

    test "returns error when name is blank" do
      state = %{}

      {:ok, %{content: [%{type: "text", text: msg}], isError: true}, _state} =
        MCPHandler.handle_call_tool("add_item", %{"name" => "  "}, state)

      assert msg == "name is required"
    end
  end

  describe "handle_call_tool - update_item" do
    setup do
      {:ok, item} = List.create_item(%{"name" => "Milk", "quantity" => 1})
      %{item: item}
    end

    test "updates item fields", %{item: item} do
      state = %{}

      {:ok, [%{type: "text", text: json}], _state} =
        MCPHandler.handle_call_tool(
          "update_item",
          %{
            "id" => item.id,
            "attrs" => %{"name" => "Almond Milk", "quantity" => 3}
          },
          state
        )

      result = Jason.decode!(json)
      assert result["name"] == "Almond milk"
      assert result["quantity"] == 3
    end

    test "marks item as completed", %{item: item} do
      state = %{}

      {:ok, [%{type: "text", text: json}], _state} =
        MCPHandler.handle_call_tool(
          "update_item",
          %{
            "id" => item.id,
            "attrs" => %{"is_completed" => true}
          },
          state
        )

      result = Jason.decode!(json)
      assert result["is_completed"] == true
    end

    test "returns error when id is missing" do
      state = %{}

      {:ok, %{content: [%{type: "text", text: msg}], isError: true}, _state} =
        MCPHandler.handle_call_tool("update_item", %{}, state)

      assert msg == "id is required"
    end

    test "returns error when item not found" do
      state = %{}

      {:ok, %{content: [%{type: "text", text: msg}], isError: true}, _state} =
        MCPHandler.handle_call_tool(
          "update_item",
          %{
            "id" => "nonexistent",
            "attrs" => %{"name" => "Something"}
          },
          state
        )

      assert msg == "Item not found"
    end
  end

  describe "handle_call_tool - remove_item" do
    setup do
      {:ok, item} = List.create_item(%{"name" => "Milk"})
      %{item: item}
    end

    test "removes an existing item", %{item: item} do
      state = %{}

      {:ok, [%{type: "text", text: json}], _state} =
        MCPHandler.handle_call_tool("remove_item", %{"id" => item.id}, state)

      result = Jason.decode!(json)
      assert result["status"] == "ok"
      assert List.list_items() == []
    end

    test "returns error when id is missing" do
      state = %{}

      {:ok, %{content: [%{type: "text", text: msg}], isError: true}, _state} =
        MCPHandler.handle_call_tool("remove_item", %{}, state)

      assert msg == "id is required"
    end

    test "returns error when item not found" do
      state = %{}

      {:ok, %{content: [%{type: "text", text: msg}], isError: true}, _state} =
        MCPHandler.handle_call_tool("remove_item", %{"id" => "nonexistent"}, state)

      assert msg == "Item not found"
    end
  end

  describe "handle_call_tool - reorder_items" do
    setup do
      {:ok, item1} = List.create_item(%{"name" => "First"})
      {:ok, item2} = List.create_item(%{"name" => "Second"})
      {:ok, item3} = List.create_item(%{"name" => "Third"})
      %{item1: item1, item2: item2, item3: item3}
    end

    test "reorders items correctly", %{item1: item1, item2: item2, item3: item3} do
      state = %{}

      {:ok, [%{type: "text", text: json}], _state} =
        MCPHandler.handle_call_tool(
          "reorder_items",
          %{
            "item_ids" => [item1.id, item3.id, item2.id]
          },
          state
        )

      result = Jason.decode!(json)
      assert result["status"] == "ok"

      items = List.list_items()
      assert Enum.at(items, 0).id == item1.id
      assert Enum.at(items, 1).id == item3.id
      assert Enum.at(items, 2).id == item2.id
    end

    test "returns error when item_ids is missing" do
      state = %{}

      {:ok, %{content: [%{type: "text", text: msg}], isError: true}, _state} =
        MCPHandler.handle_call_tool("reorder_items", %{}, state)

      assert msg == "item_ids must be a list"
    end

    test "returns error for invalid item IDs" do
      state = %{}

      {:ok, %{content: [%{type: "text", text: msg}], isError: true}, _state} =
        MCPHandler.handle_call_tool(
          "reorder_items",
          %{
            "item_ids" => ["invalid-id"]
          },
          state
        )

      assert msg == "Invalid item IDs"
    end
  end

  describe "handle_call_tool - unknown tool" do
    test "returns error for unknown tool" do
      state = %{}

      assert {:error, "Tool not found", _state} =
               MCPHandler.handle_call_tool("unknown_tool", %{}, state)
    end
  end
end
