defmodule ShoppingList.PurchaseEventTest do
  use ShoppingList.DataCase, async: false

  alias ShoppingList.List
  alias ShoppingList.PurchaseEvent
  alias ShoppingList.Repo

  describe "purchase event on completion" do
    test "is created when is_completed transitions from false to true" do
      {:ok, item} = List.create_item(%{"name" => "Milk", "quantity" => 2})
      assert item.is_completed == false

      {:ok, updated} = List.update_item(item, %{"is_completed" => true})
      assert updated.is_completed == true

      events = Repo.all(PurchaseEvent)
      assert length(events) == 1

      event = hd(events)
      assert event.item_name == "Milk"
      assert event.quantity == 2
      assert event.purchased_at != nil
    end

    test "is NOT created when unchecking (true to false)" do
      {:ok, item} = List.create_item(%{"name" => "Bread"})
      List.update_item(item, %{"is_completed" => true})
      assert length(Repo.all(PurchaseEvent)) == 1

      List.update_item(item, %{"is_completed" => false})
      assert length(Repo.all(PurchaseEvent)) == 1
    end

    test "stores correct normalized item_name" do
      {:ok, item} = List.create_item(%{"name" => "  organic eggs  "})
      List.update_item(item, %{"is_completed" => true})

      event = hd(Repo.all(PurchaseEvent))
      assert event.item_name == "Organic eggs"
    end

    test "stores correct quantity" do
      {:ok, item} = List.create_item(%{"name" => "Apples", "quantity" => 5})
      List.update_item(item, %{"is_completed" => true})

      event = hd(Repo.all(PurchaseEvent))
      assert event.quantity == 5
    end

    test "purchased_at is within reasonable window of now" do
      before_time = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      {:ok, item} = List.create_item(%{"name" => "Cheese"})
      List.update_item(item, %{"is_completed" => true})

      after_time = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      event = hd(Repo.all(PurchaseEvent))
      assert event.purchased_at >= before_time or event.purchased_at == before_time
      assert event.purchased_at <= after_time or event.purchased_at == after_time
    end

    test "multiple completions create multiple events" do
      {:ok, item} = List.create_item(%{"name" => "Water"})

      List.update_item(item, %{"is_completed" => true})
      assert length(Repo.all(PurchaseEvent)) == 1

      List.update_item(item, %{"is_completed" => false})
      assert length(Repo.all(PurchaseEvent)) == 1

      List.update_item(item, %{"is_completed" => true})
      assert length(Repo.all(PurchaseEvent)) == 2
    end

    test "no event created when updating other fields without completion" do
      {:ok, item} = List.create_item(%{"name" => "Milk", "quantity" => 1})

      List.update_item(item, %{"name" => "Almond Milk", "quantity" => 3})
      assert Repo.all(PurchaseEvent) == []
    end
  end
end
