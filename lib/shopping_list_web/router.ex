defmodule ShoppingListWeb.Router do
  use ShoppingListWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ShoppingListWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", ShoppingListWeb do
    pipe_through :api

    get "/items", ItemController, :index
    post "/items", ItemController, :create
    put "/items/reorder", ItemController, :reorder
    put "/items/:id", ItemController, :update
    delete "/items/clear", ItemController, :clear
    delete "/items/:id", ItemController, :delete
  end

  scope "/api" do
    forward "/mcp", ExMCP.HttpPlug,
      handler: ShoppingListWeb.MCPHandler,
      server_info: %{name: "shopping-list-phoenix", version: "0.1.0"},
      sse_enabled: true,
      cors_enabled: false
  end

  scope "/", ShoppingListWeb do
    pipe_through :browser

    get "/health", HealthController, :index
    live "/", ItemLive.Index, :index
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:shopping_list, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ShoppingListWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
