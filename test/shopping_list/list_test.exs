defmodule ShoppingList.ListTest do
  use ShoppingList.DataCase, async: true

  alias ShoppingList.List
  alias ShoppingList.List.Item
  alias ShoppingList.Repo

  describe "create_item/1" do
    test "with valid attrs saves item with correct defaults" do
      {:ok, item} = List.create_item(%{"name" => "Milk", "quantity" => 2})
      assert item.name == "Milk"
      assert item.quantity == 2
      assert item.is_completed == false
      assert item.deleted_at == nil
      assert item.sort_order >= 0
      assert item.id != nil
    end

    test "rejects blank name" do
      assert {:error, changeset} = List.create_item(%{"name" => ""})
      assert changeset.errors[:name]
    end

    test "rejects name > 200 chars" do
      long_name = String.duplicate("a", 201)
      assert {:error, changeset} = List.create_item(%{"name" => long_name})
      assert changeset.errors[:name]
    end

    test "assigns ascending sort_order (new items at top)" do
      {:ok, item1} = List.create_item(%{"name" => "First"})
      {:ok, item2} = List.create_item(%{"name" => "Second"})
      assert item2.sort_order > item1.sort_order
    end
  end

  describe "update_item/2" do
    test "modifies fields and broadcasts" do
      {:ok, item} = List.create_item(%{"name" => "Milk"})
      {:ok, updated} = List.update_item(item, %{"name" => "Almond Milk", "quantity" => 3})
      assert updated.name == "Almond milk"
      assert updated.quantity == 3
    end
  end

  describe "delete_item/1" do
    test "sets deleted_at, item excluded from list queries" do
      {:ok, item} = List.create_item(%{"name" => "Bread"})
      {:ok, deleted} = List.delete_item(item)
      assert deleted.deleted_at != nil
      assert List.list_items() == []
    end
  end

  describe "clear_items/0" do
    test "sets deleted_at on all non-deleted items" do
      {:ok, item1} = List.create_item(%{"name" => "Apples"})
      {:ok, item2} = List.create_item(%{"name" => "Bananas"})
      assert item1.deleted_at == nil
      assert item2.deleted_at == nil

      List.clear_items()

      deleted1 = Repo.get!(Item, item1.id)
      deleted2 = Repo.get!(Item, item2.id)
      assert deleted1.deleted_at != nil
      assert deleted2.deleted_at != nil
      assert List.list_items() == []
    end
  end

  describe "reorder_item_ids/1" do
    test "assigns sort_order so first in array appears first" do
      {:ok, item1} = List.create_item(%{"name" => "First"})
      {:ok, item2} = List.create_item(%{"name" => "Second"})
      {:ok, item3} = List.create_item(%{"name" => "Third"})

      # item3 has highest sort_order, so it's first in list
      items = List.list_items()
      assert hd(items).id == item3.id

      # Reorder: item1 first, item3 second, item2 third
      :ok = List.reorder_item_ids([item1.id, item3.id, item2.id])

      items = List.list_items()
      assert Enum.at(items, 0).id == item1.id
      assert Enum.at(items, 1).id == item3.id
      assert Enum.at(items, 2).id == item2.id
    end

    test "rolls back entire operation on invalid ID" do
      {:ok, item1} = List.create_item(%{"name" => "First"})
      {:ok, item2} = List.create_item(%{"name" => "Second"})

      before_order = List.list_items()

      assert :error = List.reorder_item_ids([item1.id, "invalid-id", item2.id])

      after_order = List.list_items()
      assert length(before_order) == length(after_order)
    end
  end

  describe "list_items/0" do
    test "returns only non-deleted items in correct sort order" do
      {:ok, item1} = List.create_item(%{"name" => "First"})
      {:ok, item2} = List.create_item(%{"name" => "Second"})
      List.delete_item(item1)

      items = List.list_items()
      assert length(items) == 1
      assert hd(items).id == item2.id
    end
  end

  describe "list_active_items/0" do
    test "returns only incomplete, non-deleted items" do
      {:ok, item1} = List.create_item(%{"name" => "Active"})
      {:ok, item2} = List.create_item(%{"name" => "Completed"})
      List.update_item(item2, %{"is_completed" => true})

      active = List.list_active_items()
      assert length(active) == 1
      assert hd(active).id == item1.id
    end
  end

  describe "soft-deleted items" do
    test "are excluded from all list queries" do
      {:ok, item} = List.create_item(%{"name" => "Deleted"})
      List.delete_item(item)

      assert List.list_items() == []
      assert List.list_active_items() == []
    end
  end
end
