defmodule ShoppingListWeb.HealthControllerTest do
  use ShoppingListWeb.ConnCase, async: false

  describe "GET /health" do
    test "returns status, item_count, database connection", %{conn: conn} do
      conn = get(conn, ~p"/health")
      json = json_response(conn, 200)
      assert json["status"] == "ok"
      assert json["item_count"] == 0
      assert json["database"] == "connected"
    end
  end
end
