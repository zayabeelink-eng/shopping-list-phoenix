defmodule ShoppingListWeb.PageControllerTest do
  use ShoppingListWeb.ConnCase

  test "GET / redirects to live view", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Shopping List"
  end
end
