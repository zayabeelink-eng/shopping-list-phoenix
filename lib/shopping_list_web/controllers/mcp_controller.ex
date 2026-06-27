defmodule ShoppingListWeb.McpController do
  use ShoppingListWeb, :controller

  alias ShoppingList.List

  @jsonrpc_invalid_request -32_600
  @jsonrpc_method_not_found -32_601
  @jsonrpc_invalid_params -32_602

  @impl true
  def call(conn, _params) do
    with {:ok, body} <- fetch_body(conn),
         {:ok, request} <- parse_jsonrpc_request(body) do
      request_id = Map.get(request, "id")
      method = request["method"]
      params = request["params"] || %{}

      response =
        if valid_method?(method) do
          execute_method(method, params)
        else
          {:error, :method_not_found, method}
        end

      send_response(conn, response, request_id)
    else
      {:error, :invalid_request} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          :bad_request,
          jsonrpc_error(@jsonrpc_invalid_request, "Invalid Request", nil)
        )
    end
  end

  defp send_response(conn, {:ok, result}, request_id) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(:ok, jsonrpc_success(result, request_id))
  end

  defp send_response(conn, {:error, :method_not_found, method}, request_id) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(
      :ok,
      jsonrpc_error(@jsonrpc_method_not_found, "Method \"#{method}\" not found", request_id)
    )
  end

  defp send_response(conn, {:error, :param_error, reason}, request_id) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(:ok, jsonrpc_error(@jsonrpc_invalid_params, reason, request_id))
  end

  defp execute_method("list_items", _params) do
    items = List.list_items()
    {:ok, Enum.map(items, &item_to_map/1)}
  end

  defp execute_method("add_item", params) do
    name = Map.get(params, "name")

    if is_nil(name) or (is_binary(name) and String.trim(name) == "") do
      {:error, :param_error, "name is required"}
    else
      quantity = Map.get(params, "quantity", 1)
      attrs = %{"name" => name, "quantity" => quantity}

      case List.create_item(attrs) do
        {:ok, item} -> {:ok, item_to_map(item)}
        {:error, changeset} -> {:error, :param_error, format_changeset_error(changeset)}
      end
    end
  end

  defp execute_method("update_item", params) do
    id = Map.get(params, "id")

    if is_nil(id) do
      {:error, :param_error, "id is required"}
    else
      attrs = Map.get(params, "attrs", %{})

      with %{} = item <- fetch_item(id),
           {:ok, item} <- List.update_item(item, attrs) do
        {:ok, item_to_map(item)}
      else
        :not_found -> {:error, :param_error, "Item not found"}
        {:error, changeset} -> {:error, :param_error, format_changeset_error(changeset)}
      end
    end
  end

  defp execute_method("remove_item", params) do
    id = Map.get(params, "id")

    if is_nil(id) do
      {:error, :param_error, "id is required"}
    else
      with %{} = item <- fetch_item(id),
           {:ok, _item} <- List.delete_item(item) do
        :ok
      else
        :not_found -> {:error, :param_error, "Item not found"}
        {:error, _changeset} -> {:error, :param_error, "Failed to delete item"}
      end
    end
  end

  defp execute_method("reorder_items", params) do
    item_ids = Map.get(params, "item_ids")

    if is_nil(item_ids) or not is_list(item_ids) do
      {:error, :param_error, "item_ids must be a list"}
    else
      case List.reorder_item_ids(item_ids) do
        :ok -> :ok
        :error -> {:error, :param_error, "Invalid item IDs"}
      end
    end
  end

  defp execute_method("clear_items", _params) do
    :ok = List.clear_items()
    :ok
  end

  defp valid_method?(method) do
    method in [
      "list_items",
      "add_item",
      "update_item",
      "remove_item",
      "reorder_items",
      "clear_items"
    ]
  end

  defp fetch_body(conn) do
    case Plug.Conn.read_body(conn) do
      {:ok, body, _conn} when byte_size(body) > 0 ->
        {:ok, body}

      {:ok, "", _conn} ->
        {:error, :invalid_request}

      {:error, _reason} ->
        {:error, :invalid_request}
    end
  end

  defp parse_jsonrpc_request(body) do
    case Jason.decode(body) do
      {:ok, %{"jsonrpc" => "2.0", "method" => _method} = request} ->
        {:ok, request}

      {:ok, %{"jsonrpc" => _version}} ->
        {:error, :invalid_request}

      {:ok, _} ->
        {:error, :invalid_request}

      {:error, _} ->
        {:error, :invalid_request}
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

  defp jsonrpc_success(result, request_id) do
    %{
      "jsonrpc" => "2.0",
      "result" => result,
      "id" => request_id
    }
    |> Jason.encode!()
  end

  defp jsonrpc_error(code, message, request_id) do
    %{
      "jsonrpc" => "2.0",
      "error" => %{"code" => code, "message" => message},
      "id" => request_id
    }
    |> Jason.encode!()
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
