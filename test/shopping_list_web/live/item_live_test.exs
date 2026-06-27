defmodule ShoppingListWeb.ItemLiveTest do
  use ShoppingListWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "index" do
    test "renders page with empty state", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/")

      assert html =~ "Shopping List"
      assert has_element?(view, "#add-item-form")
      assert has_element?(view, "#items")
      assert html =~ "No items yet"
    end

    test "adding an item shows it in the list", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#add-item-form", %{"name" => "pasta", "quantity" => "2"})
      |> render_submit()

      assert render(view) =~ "Pasta"
    end

    test "toggling completion marks item as complete", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#add-item-form", %{"name" => "pasta", "quantity" => "2"})
      |> render_submit()

      view
      |> element("input[type=checkbox]")
      |> render_click()

      assert has_element?(view, "span.line-through")
    end

    test "toggling again marks item as incomplete", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#add-item-form", %{"name" => "pasta", "quantity" => "2"})
      |> render_submit()

      view
      |> element("input[type=checkbox]")
      |> render_click()

      assert has_element?(view, "span.line-through")

      view
      |> element("input[type=checkbox]")
      |> render_click()

      refute has_element?(view, "span.line-through")
    end

    test "deleting an item removes it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#add-item-form", %{"name" => "pasta", "quantity" => "2"})
      |> render_submit()

      assert has_element?(view, "[phx-click=delete]")

      view
      |> element("[phx-click=delete]")
      |> render_click(confirm: fn _ -> true end)

      assert render(view) =~ "No items yet"
    end

    test "updating quantity changes the quantity display", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#add-item-form", %{"name" => "pasta", "quantity" => "2"})
      |> render_submit()

      html = render(view)
      [_, id] = Regex.run(~r/id="items-([^"]+)"/, html)

      view
      |> element("#qty-inc-#{id}")
      |> render_click()

      assert render(view) =~ "3"
    end

    test "two live sessions sync in real-time via PubSub", %{conn: _conn} do
      conn1 = Phoenix.ConnTest.build_conn()
      conn2 = Phoenix.ConnTest.build_conn()

      {:ok, view1, _html} = live(conn1, ~p"/")
      {:ok, view2, _html} = live(conn2, ~p"/")

      view1
      |> form("#add-item-form", %{"name" => "pasta", "quantity" => "2"})
      |> render_submit()

      assert has_element?(view1, "[phx-click=delete]")
      assert has_element?(view2, "[phx-click=delete]")
    end
  end
end
