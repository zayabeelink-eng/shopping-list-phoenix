# Phase 2: Context, API & Real-Time Sync

## Goal
Implement the business logic context (`ShoppingList.List`) with full CRUD, reorder, and clear operations. Expose via REST API with PubSub broadcasting for real-time updates.

## Prerequisites
- Phase 1 complete (migration run, schema exists)
- `lib/shopping_list/list/item.ex` with changeset validations

## Steps & Commits

### Step 1: Implement List context module
Create the business logic layer with all operations and PubSub broadcasting.

**Files**: `lib/shopping_list/list.ex`
**Functions**:
- `subscribe/0` — subscribe to PubSub topic
- `list_items/0` — all items ordered by `sort_order DESC, inserted_at DESC`
- `list_active_items/0` — incomplete items only
- `create_item/1` — create with `max(sort_order) + 1`, broadcast `:item_created`
- `update_item/2` — update attrs, broadcast `:item_updated`
- `delete_item/1` — delete item, broadcast `:item_deleted`
- `clear_items/0` — delete all, broadcast `:items_cleared`
- `reorder_item_ids/1` — transactional reorder with `total - index - 1` sort_order assignment, broadcast `:items_reordered` after commit
- `get_item!/1` — fetch by ID or raise

**Broadcasts**: All mutations broadcast to `"shopping_list_mutations"` PubSub topic.

**Commit**: `implement list context with crud reorder and pubsub`

### Step 2: Add context unit tests

**Files**: `test/shopping_list/list_test.exs`
**Tests**:
- `create_item/1` with valid attrs saves item with correct defaults
- `create_item/1` rejects blank name
- `create_item/1` rejects name > 200 chars
- `create_item/1` assigns ascending sort_order (new items at top)
- `update_item/2` modifies fields and broadcasts
- `delete_item/1` removes item
- `clear_items/0` removes all items
- `reorder_item_ids/1` assigns sort_order so first in array appears first
- `reorder_item_ids/1` rolls back entire operation on invalid ID
- `list_items/0` returns items in correct sort order
- `list_active_items/0` returns only incomplete items

**Commit**: `add context unit tests`

### Step 3: Create REST API controllers
Build JSON API controllers for all item endpoints and health check.

**Files**:
- `lib/shopping_list_web/controllers/item_json.ex` — JSON view helpers
- `lib/shopping_list_web/controllers/item_controller.ex` — CRUD actions
- `lib/shopping_list_web/controllers/health_controller.ex` — health endpoint

**ItemController actions**:
- `index` — GET `/api/items` → list all items
- `create` — POST `/api/items` → create item from params
- `update` — PUT `/api/items/:id` → update item
- `delete` — DELETE `/api/items/:id` → delete item
- `reorder` — PUT `/api/items/reorder` → reorder items
- `clear` — DELETE `/api/items/clear` → clear all items

**HealthController**:
- `index` — GET `/health` → returns `%{status: "ok", item_count: N, database: "connected"}`

**Commit**: `add rest api controllers for items and health`

### Step 4: Configure router
Wire up API routes and LiveView routes in the router, respecting route ordering.

**Files**: `lib/shopping_list_web/router.ex`
**Routes**:
```elixir
scope "/api", ShoppingListWeb do
  pipe_through :api

  get "/items", ItemController, :index
  post "/items", ItemController, :create
  put "/items/reorder", ItemController, :reorder      # before :id route
  put "/items/:id", ItemController, :update
  delete "/items/clear", ItemController, :clear        # before :id route
  delete "/items/:id", ItemController, :delete
end

scope "/", ShoppingListWeb do
  pipe_through :browser

  get "/health", HealthController, :index
  live "/items", ItemLive.Index, :index
end
```

> **Route ordering**: `PUT /api/items/reorder` and `DELETE /api/items/clear` must be defined **above** their parameterized counterparts (`/api/items/:id`), otherwise Phoenix will match `"reorder"` and `"clear"` as `:id` values.

**Commit**: `configure router with api scope and liveview routes`

### Step 5: Add REST API integration tests

**Files**: `test/shopping_list_web/controllers/item_controller_test.exs`, `test/shopping_list_web/controllers/health_controller_test.exs`
**Tests**:
- GET `/api/items` returns empty list initially
- POST `/api/items` creates an item and returns it with ID
- POST `/api/items` with blank name returns 422
- POST `/api/items` with missing name returns 422
- PUT `/api/items/:id` updates item fields
- PUT `/api/items/:id` with invalid ID returns 404
- DELETE `/api/items/:id` removes item
- DELETE `/api/items/:id` with invalid ID returns 404
- PUT `/api/items/reorder` sets correct sort_order
- PUT `/api/items/reorder` with invalid ID returns 422
- DELETE `/api/items/clear` removes all items
- GET `/health` returns status, item_count, database connection

**Commit**: `add api integration tests`

## Verification
```bash
mix test  # All context + API tests pass
MIX_ENV=test mix credo --strict  # Zero issues
```
