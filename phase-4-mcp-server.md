# Phase 4: MCP Server Integration

## Goal
Implement a JSON-RPC 2.0 MCP (Model Context Protocol) server endpoint at `/api/mcp` for AI agent integration. The MCP endpoint maps to the same `ShoppingList.List` context as the REST API.

## Prerequisites
- Phase 2 complete (List context with all operations)

## Steps & Commits

### Step 1: Create MCP controller
Implement a JSON-RPC 2.0 endpoint that accepts POST requests with JSON-RPC method calls and dispatches to the appropriate context function.

**Files**: `lib/shopping_list_web/controllers/mcp_controller.ex`
**Request format**:
```json
{"jsonrpc": "2.0", "method": "add_item", "params": {"name": "Milk", "quantity": 2}, "id": 1}
```

**Response format**:
```json
{"jsonrpc": "2.0", "result": {"id": "...", "name": "Milk", ...}, "id": 1}
```

**Error format**:
```json
{"jsonrpc": "2.0", "error": {"code": -32602, "message": "Invalid params"}, "id": 1}
```

**Supported methods**:
| Method | Params | Maps to |
|--------|--------|---------|
| `list_items` | `{}` | `List.list_items/0` |
| `add_item` | `{"name": "...", "quantity": N}` | `List.create_item/1` |
| `update_item` | `{"id": "...", "attrs": {...}}` | `List.update_item/2` |
| `remove_item` | `{"id": "..."}` | `List.delete_item/1` |
| `reorder_items` | `{"item_ids": [...]}` | `List.reorder_item_ids/1` |
| `clear_items` | `{}` | `List.clear_items/0` |

**JSON-RPC error codes**:
- `-32600` — Invalid Request (missing jsonrpc field, wrong version)
- `-32601` — Method not found
- `-32602` — Invalid params
- `-32603` — Internal error

**Commit**: `implement mcp json-rpc 2.0 controller`

### Step 2: Add MCP route
**Files**: `lib/shopping_list_web/router.ex`
**Route**:
```elixir
scope "/api", ShoppingListWeb do
  pipe_through :api

  post "/mcp", McpController, :call
end
```

**Commit**: `add mcp route`

### Step 3: Add MCP integration tests

**Files**: `test/shopping_list_web/controllers/mcp_controller_test.exs`
**Tests**:
- `list_items` returns empty array initially
- `add_item` creates item and returns it
- `add_item` with missing name returns error
- `update_item` modifies item fields
- `update_item` with invalid ID returns error
- `remove_item` deletes item
- `remove_item` with invalid ID returns error
- `reorder_items` updates sort_order correctly
- `reorder_items` with invalid IDs returns error
- `clear_items` removes all items
- Unknown method returns `-32601` error
- Missing `jsonrpc` field returns `-32600` error

**Commit**: `add mcp integration tests`

## Verification
```bash
mix test  # All MCP tests pass
mix credo --strict  # Zero issues
```
