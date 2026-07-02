defmodule ShoppingListWeb.MCPHandler do
  @moduledoc """
  MCP server handler for the shopping list application.

  Implements the ExMCP.Server.Handler behaviour to expose shopping list
  operations as MCP tools.
  """

  @behaviour ExMCP.Server.Handler
  use GenServer

  alias ShoppingList.List

  @impl GenServer
  def init(_args), do: {:ok, %{}}

  @impl GenServer
  def terminate(_reason, _state), do: :ok

  @dialyzer {:no_match, handle_call: 3}

  defp __widen_type__(result), do: result

  @impl GenServer
  def handle_call({:initialize, params}, _from, state) do
    case __widen_type__(handle_initialize(params, state)) do
      {:ok, result, new_state} -> {:reply, {:ok, result}, new_state}
      {:error, reason, new_state} -> {:reply, {:error, reason}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:list_tools, cursor}, _from, state) do
    case __widen_type__(handle_list_tools(cursor, state)) do
      {:ok, tools, next_cursor, new_state} ->
        {:reply, {:ok, tools, next_cursor, new_state}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:call_tool, name, args}, _from, state) do
    case __widen_type__(handle_call_tool(name, args, state)) do
      {:ok, result, new_state} -> {:reply, {:ok, result}, new_state}
      {:error, reason, new_state} -> {:reply, {:error, reason}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:list_resources, cursor}, _from, state) do
    case __widen_type__(handle_list_resources(cursor, state)) do
      {:ok, resources, next_cursor, new_state} ->
        {:reply, {:ok, resources, next_cursor, new_state}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:read_resource, uri}, _from, state) do
    case __widen_type__(handle_read_resource(uri, state)) do
      {:ok, content, new_state} -> {:reply, {:ok, content}, new_state}
      {:error, reason, new_state} -> {:reply, {:error, reason}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:list_prompts, cursor}, _from, state) do
    case __widen_type__(handle_list_prompts(cursor, state)) do
      {:ok, prompts, next_cursor, new_state} ->
        {:reply, {:ok, prompts, next_cursor, new_state}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:get_prompt, name, args}, _from, state) do
    case __widen_type__(handle_get_prompt(name, args, state)) do
      {:ok, result, new_state} -> {:reply, {:ok, result}, new_state}
      {:error, reason, new_state} -> {:reply, {:error, reason}, new_state}
    end
  end

  @impl GenServer
  def handle_call(_msg, _from, state) do
    {:reply, {:error, "Unknown message"}, state}
  end

  @impl true
  def handle_initialize(_params, state) do
    {:ok,
     %{
       protocolVersion: "2025-03-26",
       serverInfo: %{name: "shopping-list-phoenix", version: "0.1.0"},
       capabilities: %{tools: %{}}
     }, state}
  end

  @impl true
  def handle_list_tools(_cursor, state) do
    tools = [
      %{
        name: "list_items",
        description: "List all items in the shopping list",
        inputSchema: %{type: "object", properties: %{}, required: []}
      },
      %{
        name: "add_item",
        description: "Add a new item to the shopping list",
        inputSchema: %{
          type: "object",
          properties: %{
            name: %{type: "string", description: "Name of the item"},
            quantity: %{type: "integer", description: "Quantity of the item", default: 1}
          },
          required: ["name"]
        }
      },
      %{
        name: "update_item",
        description: "Update an existing item in the shopping list",
        inputSchema: %{
          type: "object",
          properties: %{
            id: %{type: "string", description: "ID of the item to update"},
            attrs: %{
              type: "object",
              description: "Attributes to update",
              properties: %{
                name: %{type: "string"},
                quantity: %{type: "integer"},
                is_completed: %{type: "boolean"}
              }
            }
          },
          required: ["id", "attrs"]
        }
      },
      %{
        name: "remove_item",
        description: "Remove an item from the shopping list",
        inputSchema: %{
          type: "object",
          properties: %{
            id: %{type: "string", description: "ID of the item to remove"}
          },
          required: ["id"]
        }
      },
      %{
        name: "reorder_items",
        description: "Reorder items in the shopping list",
        inputSchema: %{
          type: "object",
          properties: %{
            item_ids: %{
              type: "array",
              items: %{type: "string"},
              description: "Ordered list of item IDs (first is highest priority)"
            },
            confirmed: %{
              type: "boolean",
              description: "Must be set to true to confirm the reorder operation"
            }
          },
          required: ["item_ids", "confirmed"]
        }
      }
    ]

    {:ok, tools, nil, state}
  end

  @impl true
  def handle_call_tool(name, arguments, state) do
    case name do
      "list_items" -> handle_list_items(arguments, state)
      "add_item" -> handle_add_item(arguments, state)
      "update_item" -> handle_update_item(arguments, state)
      "remove_item" -> handle_remove_item(arguments, state)
      "reorder_items" -> handle_reorder_items(arguments, state)
      _ -> {:error, "Tool not found", state}
    end
  end

  @impl true
  def handle_list_resources(_cursor, state) do
    {:ok, [], nil, state}
  end

  @impl true
  def handle_read_resource(_uri, state) do
    {:error, "Resource reading not implemented", state}
  end

  @impl true
  def handle_list_prompts(_cursor, state) do
    {:ok, [], nil, state}
  end

  @impl true
  def handle_get_prompt(_name, _arguments, state) do
    {:error, "Prompt retrieval not implemented", state}
  end

  defp handle_list_items(_arguments, state) do
    items = List.list_items()
    result = Enum.map(items, &item_to_map/1)
    {:ok, [%{type: "text", text: Jason.encode!(result)}], state}
  end

  defp handle_add_item(arguments, state) do
    name = Map.get(arguments, "name")

    if is_nil(name) or (is_binary(name) and String.trim(name) == "") do
      {:ok,
       %{
         content: [%{type: "text", text: "name is required"}],
         isError: true
       }, state}
    else
      quantity = Map.get(arguments, "quantity", 1)
      attrs = %{"name" => name, "quantity" => quantity}

      case List.create_item(attrs) do
        {:ok, item} ->
          {:ok, [%{type: "text", text: Jason.encode!(item_to_map(item))}], state}

        {:error, changeset} ->
          {:ok,
           %{
             content: [%{type: "text", text: format_changeset_error(changeset)}],
             isError: true
           }, state}
      end
    end
  end

  defp handle_update_item(arguments, state) do
    id = Map.get(arguments, "id")

    if is_nil(id) do
      {:ok,
       %{
         content: [%{type: "text", text: "id is required"}],
         isError: true
       }, state}
    else
      attrs = Map.get(arguments, "attrs", %{})

      with %{} = item <- fetch_item(id),
           {:ok, item} <- List.update_item(item, attrs) do
        {:ok, [%{type: "text", text: Jason.encode!(item_to_map(item))}], state}
      else
        :not_found ->
          {:ok,
           %{
             content: [%{type: "text", text: "Item not found"}],
             isError: true
           }, state}

        {:error, changeset} ->
          {:ok,
           %{
             content: [%{type: "text", text: format_changeset_error(changeset)}],
             isError: true
           }, state}
      end
    end
  end

  defp handle_remove_item(arguments, state) do
    id = Map.get(arguments, "id")

    if is_nil(id) do
      {:ok,
       %{
         content: [%{type: "text", text: "id is required"}],
         isError: true
       }, state}
    else
      with %{} = item <- fetch_item(id),
           {:ok, _item} <- List.delete_item(item) do
        {:ok, [%{type: "text", text: Jason.encode!(%{"status" => "ok"})}], state}
      else
        :not_found ->
          {:ok,
           %{
             content: [%{type: "text", text: "Item not found"}],
             isError: true
           }, state}

        {:error, _changeset} ->
          {:ok,
           %{
             content: [%{type: "text", text: "Failed to delete item"}],
             isError: true
           }, state}
      end
    end
  end

  defp handle_reorder_items(arguments, state) do
    item_ids = Map.get(arguments, "item_ids")
    confirmed = Map.get(arguments, "confirmed", false)

    if confirmed do
      validate_and_reorder(item_ids, state)
    else
      {:ok,
       %{
         content: [
           %{
             type: "text",
             text: ~s(Confirmation required. Set "confirmed" to true to proceed with reorder.)
           }
         ],
         isError: true
       }, state}
    end
  end

  defp validate_and_reorder(item_ids, state) do
    if is_nil(item_ids) or not is_list(item_ids) do
      {:ok,
       %{
         content: [%{type: "text", text: "item_ids must be a list"}],
         isError: true
       }, state}
    else
      case List.reorder_item_ids(item_ids) do
        :ok ->
          {:ok, [%{type: "text", text: Jason.encode!(%{"status" => "ok"})}], state}

        :error ->
          {:ok,
           %{
             content: [%{type: "text", text: "Invalid item IDs"}],
             isError: true
           }, state}
      end
    end
  end

  defp fetch_item(id) do
    case List.get_item!(id) do
      %{} = item -> item
      _ -> :not_found
    end
  rescue
    Ecto.NoResultsError -> :not_found
  end

  defp item_to_map(item) do
    %{
      "id" => item.id,
      "name" => item.name,
      "quantity" => item.quantity,
      "is_completed" => item.is_completed,
      "sort_order" => item.sort_order,
      "inserted_at" => item.inserted_at,
      "updated_at" => item.updated_at
    }
  end

  defp format_changeset_error(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Map.new()
    |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end)
  end
end
