# Shopping List — Functional Requirements

## Core Features

### Item Management
- **Add item** — user can add an item by name (plain text, 1–200 characters)
- **List items** — view all items in the list with their ID, name, and creation timestamp
- **Remove item** — delete a single item by its ID
- **Clear all** — remove every item from the list at once

### Ordering
- **Reorder items** — user can set a custom order by submitting the full sequence of item IDs. New items appear at the top by default.
- **Display order** — items are sorted by sort_order (ascending), then creation date (descending).

### Validation & Constraints
- Item name is required (cannot be empty or whitespace-only)
- Item name max length: 200 characters
- Removing a non-existent item returns a 404 error

## API Surface

### REST Endpoints
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/items` | List all items |
| POST | `/api/items` | Add an item (body: `{"name": "..."}`) |
| DELETE | `/api/items/{id}` | Remove an item by ID |
| PUT | `/api/items/reorder` | Reorder items (body: `{"item_ids": [1, 2, 3]}`) |
| GET | `/health` | Health check — returns status, item count, db connection |

### MCP Tools (Model Context Protocol)
- `list_items` — returns all items as JSON
- `add_item(name)` — adds an item
- `remove_item(id)` — removes an item by ID
- `reorder_items(item_ids)` — sets display order
- `clear_items` — deletes all items

## Data Layer
- **Database**: SQLite (persistent, file-based)
- **Schema**: `shopping_list` table with columns `id` (INTEGER PK), `name` (TEXT), `created_at` (TEXT), `sort_order` (INTEGER)
- **Persistence**: Data volume mounted at `/data`, survives container restarts

## UI (Web)
- Single-page HTML interface
- Text input with "Add" button
- Item list with per-item delete (×) button
- Refresh (↻) button to reload the list
- Empty state message when no items exist
- Auto-focus on input after adding an item

## Quality of Service
- Health endpoint for monitoring
- Container runs with `restart: unless-stopped`

