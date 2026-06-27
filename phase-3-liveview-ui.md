# Phase 3: LiveView UI & Real-Time Synchronization

## Goal
Build a single-page LiveView UI with real-time synchronization across multiple connected clients. Users can add, delete, toggle completion, adjust quantity, and reorder items.

## Prerequisites
- Phase 2 complete (List context, API, PubSub broadcasting)
- Router configured with `live "/items", ItemLive.Index, :index`

## Steps & Commits

### Step 1: Create LiveView module with PubSub subscription

**Files**: `lib/shopping_list_web/live/item_live/index.ex`
**Structure**:
```elixir
defmodule ShoppingListWeb.ItemLive.Index do
  use ShoppingListWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      ShoppingList.List.subscribe()
    end

    socket =
      socket
      |> assign(:form, to_form(%{"name" => "", "quantity" => 1}))
      |> stream(:items, ShoppingList.List.list_items(), reset: true)

    {:ok, socket}
  end
end
```

**Handle all PubSub broadcasts** with pattern matching:
- `:item_created` → stream_insert at -1 (prepend)
- `:item_updated` → stream_insert (replace in place)
- `:item_deleted` → stream_delete
- `:items_reordered` → stream with reset
- `:items_cleared` → stream with reset

**Handle events**:
- `"save"` — create item from form
- `"toggle"` — toggle is_completed
- `"delete"` — delete item
- `"clear"` — clear all items
- `"update-quantity"` — change quantity
- `"reorder"` — reorder (via API or drag)

**Commit**: `create item liveview with pubsub subscription`

### Step 2: Build the LiveView template

**Files**: `lib/shopping_list_web/live/item_live/index.html.heex`
**UI Elements**:
- Add item form (text input + quantity + Add button)
- Item list with phx-update="stream"
- Per-item: name, quantity, completion checkbox, delete button
- Empty state (hidden only:block)
- Auto-focus input after adding

**Template structure**:
```heex
<Layouts.app flash={@flash} current_scope={@current_scope}>
  <div class="max-w-2xl mx-auto p-4">
    <h1>Shopping List</h1>

    <.form for={@form} id="add-item-form" phx-submit="save">
      <.input field={@form[:name]} type="text" placeholder="Add item..." />
      <.input field={@form[:quantity]} type="number" min="1" value={1} />
      <.button>Add</.button>
    </.form>

    <div id="items" phx-update="stream" class="space-y-2 mt-6">
      <div class="hidden only:block text-center text-gray-500">
        No items yet. Add one above!
      </div>

      <div :for={{id, item} <- @streams.items} id={id} class="flex items-center gap-2 p-2">
        <input type="checkbox" checked={item.is_completed}
               phx-click="toggle" phx-value-id={item.id} />

        <span class={["flex-1", item.is_completed && "line-through text-gray-400"]}>
          {item.name}
        </span>

        <span class="text-sm text-gray-500">x{item.quantity}</span>

        <.button phx-click="delete" phx-value-id={item.id} class="text-red-500">
          <.icon name="hero-x-mark" class="w-5 h-5" />
        </.button>
      </div>
    </div>
  </div>
</Layouts.app>
```

**Commit**: `build item list ui template with stream and controls`

### Step 3: Add LiveView integration tests

**Files**: `test/shopping_list_web/live/item_live_test.exs`
**Tests**:
- Renders page with empty state
- Adding an item shows it in the list
- Toggling completion marks item as complete/incomplete
- Deleting an item removes it
- Clear all removes all items
- Two live sessions sync in real-time via PubSub

**Commit**: `add liveview integration tests`

## Verification
```bash
mix test  # All LiveView tests pass
mix credo --strict  # Zero issues
```
