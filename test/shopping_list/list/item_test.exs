defmodule ShoppingList.List.ItemTest do
  use ExUnit.Case, async: true

  alias ShoppingList.List.Item

  describe "changeset" do
    test "valid attributes create a valid changeset" do
      changeset = Item.changeset(%Item{}, %{"name" => "Milk", "quantity" => 2})
      assert changeset.valid?
    end

    test "blank name is rejected" do
      changeset = Item.changeset(%Item{}, %{"name" => ""})
      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:name]
    end

    test "whitespace-only name is rejected after trimming" do
      changeset = Item.changeset(%Item{}, %{"name" => "   "})
      refute changeset.valid?
    end

    test "name exceeding 200 chars is rejected" do
      long_name = String.duplicate("a", 201)
      changeset = Item.changeset(%Item{}, %{"name" => long_name})
      refute changeset.valid?
      assert {"should be at most %{count} character(s)", _} = changeset.errors[:name]
    end

    test "quantity defaults to 1" do
      changeset = Item.changeset(%Item{}, %{"name" => "Milk"})
      assert %Item{quantity: 1} = Ecto.Changeset.apply_action!(changeset, :insert)
    end

    test "negative quantity is rejected" do
      changeset = Item.changeset(%Item{}, %{"name" => "Milk", "quantity" => -1})
      refute changeset.valid?
      assert {"must be greater than %{number}", _} = changeset.errors[:quantity]
    end

    test "zero quantity is rejected" do
      changeset = Item.changeset(%Item{}, %{"name" => "Milk", "quantity" => 0})
      refute changeset.valid?
      assert {"must be greater than %{number}", _} = changeset.errors[:quantity]
    end

    test "is_completed defaults to false" do
      item = %Item{}
      assert item.is_completed == false
    end

    test "deleted_at is nil for a valid changeset" do
      changeset = Item.changeset(%Item{}, %{"name" => "Milk"})
      assert changeset.changes[:deleted_at] == nil
    end

    test "name normalization: lowercase to title case" do
      changeset = Item.changeset(%Item{}, %{"name" => "milk"})
      assert changeset.changes.name == "Milk"
    end

    test "name normalization: uppercase with whitespace" do
      changeset = Item.changeset(%Item{}, %{"name" => " MILK "})
      assert changeset.changes.name == "Milk"
    end

    test "name normalization: lowercase with whitespace" do
      changeset = Item.changeset(%Item{}, %{"name" => "  hello  "})
      assert changeset.changes.name == "Hello"
    end
  end
end
