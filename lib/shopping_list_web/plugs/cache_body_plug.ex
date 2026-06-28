defmodule ShoppingListWeb.Plugs.CacheBodyPlug do
  @moduledoc """
  Caches the raw request body in `conn.assigns.raw_body` before Plug.Parsers can consume it.

  Required by ExMCP.HttpPlug which reads the body via `read_or_cached_body/2` and
  checks for a pre-cached `raw_body` assign first.
  """
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:raw_body] do
      conn
    else
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      Plug.Conn.assign(conn, :raw_body, body)
    end
  end
end
