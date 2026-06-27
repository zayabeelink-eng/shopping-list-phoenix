defmodule ShoppingListWeb.PageController do
  use ShoppingListWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
