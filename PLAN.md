# Combined Implementation Plan: Real-Time Phoenix Shopping List & MCP Server

This specification merges the architectural blueprint from Gemini with the functional requirements document into a single, unified plan. It serves as the authoritative context blueprint for building the Elixir/Phoenix shopping list application with MCP server capabilities.

---

## 1. Project Specifications & Architectural Safeguards

### Tech Stack Constraints
- **Runtime**: Elixir 1.18+ (OTP 26+), Phoenix 1.8.5+, LiveView 1.1+, Bandit (HTTP server)
- **Database**: SQLite 3 via ecto_sqlite3. No PostgreSQL dependencies allowed.
- **UI Framework**: Tailwind CSS v4 + DaisyUI component libraries.
- **Code Quality & Linting**: Strict Credo, Dialyxir (Dialyzer typespecs), and Sobelow (Static security analysis).
- **Deployment Target**: Single Docker container running an Elixir Release, deployed onto a self-hosted mini PC on a private Tailscale network.

### LLM Context & Execution Boundaries
- **Deterministic Sandboxing**: All operations must execute exclusively within the project directory workspace. No host binaries, Docker sockets, or elevated privileges.
- **Stateless Compilation**: Execute `mix compile`, `mix assets.build`, and `mix test && mix credo --strict` inside the sandbox prior to committing any file.
- **Defensive Code Structure**: Prioritize small, pipeline-oriented functions (`|>`), pattern matching in function heads, and strict module boundaries. Avoid monolithic files.

---

## 2. Functional Requirements

### Item Management
- **Add item** — user can add an item by name (plain text, 1–200 characters)
- **List items** — view all items with ID, name, quantity, completion status, and creation timestamp
- **Remove item** — delete a single item by its ID
- **Clear all** — remove every item from the list at once
- **Toggle completion** — mark an item as completed or incomplete

### Ordering
- **Reorder items** — user or AI can set a custom order by submitting the full sequence of item IDs. New items appear at the top by default (lowest sort_order value).
- **Display order** — items are sorted by `sort_order` (ascending), then creation date (descending).

### Validation & Constraints
- Item name is required (cannot be empty or whitespace-only)
- Item name max length: 200 characters
- Quantity defaults to 1, must be a positive integer
- Removing a non-existent item returns a 404 error

---

## 3. API Surface

### REST Endpoints
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/items` | List all items |
| POST | `/api/items` | Add an item (body: `{"name": "...", "quantity": 1}`) |
| PUT | `/api/items/{id}` | Update an item (e.g., toggle completion, change quantity) |
| DELETE | `/api/items/{id}` | Remove an item by ID |
| PUT | `/api/items/reorder` | Reorder items (body: `{"item_ids": ["id1", "id2", ...]}`) |
| DELETE | `/api/items/clear` | Remove all items |
| GET | `/health` | Health check — returns status, item count, db connection |

### MCP Tools (Model Context Protocol)
- `list_items` — returns all items as JSON
- `add_item(name, quantity)` — adds an item
- `update_item(id, attrs)` — updates an item (completion, quantity, etc.)
- `remove_item(id)` — removes an item by ID
- `reorder_items(item_ids)` — sets display order
- `clear_items` — deletes all items

### Real-Time Events (Phoenix PubSub)
- `item_created` — broadcast when a new item is added
- `item_updated` — broadcast when an item is modified
- `item_deleted` — broadcast when an item is removed
- `items_reordered` — broadcast when order changes
- `items_cleared` — broadcast when all items are deleted

---

## 4. Data Layer

### Database Schema
- **Database**: SQLite (persistent, file-based)
- **Table**: `items` with columns:
  - `id` (binary_id, primary key)
  - `name` (TEXT, not null, 1-200 chars)
  - `quantity` (INTEGER, default 1, not null)
  - `is_completed` (BOOLEAN, default false, not null)
  - `sort_order` (INTEGER, for custom ordering)
  - `inserted_at` (TIMESTAMP)
  - `updated_at` (TIMESTAMP)
- **Index**: on `is_completed` for efficient filtering
- **Persistence**: Data volume mounted at `/app/data`, survives container restarts
- **WAL Mode**: SQLite Write-Ahead Logging enabled for concurrent access safety

### Migration (priv/repo/migrations/20260627000001_create_items.exs)
```elixir
defmodule ShoppingList.Repo.Migrations.CreateItems do
  use Ecto.Migration
  def change do
    create table(:items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :quantity, :integer, default: 1, null: false
      add :is_completed, :boolean, default: false, null: false
      add :sort_order, :integer, default: 0
      timestamps()
    end
    create index(:items, [:is_completed])
    create index(:items, [:sort_order])
  end
end
```

### Context: Business Logic API (lib/shopping_list/list.ex)
```elixir
defmodule ShoppingList.List do
  @moduledoc "Handles CRUD transactions and ordering for shopping list items."
  import Ecto.Query, warn: false
  alias ShoppingList.Repo
  alias ShoppingList.List.Item
  @topic "shopping_list_mutations"

  def subscribe do
    Phoenix.PubSub.subscribe(ShoppingList.PubSub, @topic)
  end

  def list_items do
    Item
    |> order_by([i], asc: i.sort_order, desc: i.inserted_at)
    |> Repo.all()
  end

  def list_active_items do
    Item
    |> where([i], is_completed: false)
    |> order_by([i], asc: i.sort_order, desc: i.inserted_at)
    |> Repo.all()
  end

  def create_item(attrs \\ %{}) do
    min_order = Repo.aggregate(Item, :min, :sort_order)
    next_order = if is_nil(min_order), do: 0, else: min_order - 1
    attrs
    |> Map.put("sort_order", next_order)
    |> Item.changeset()
    |> Repo.insert()
    |> broadcast(:item_created)
  end

  def update_item(%Item{} = item, attrs) do
    item
    |> Item.changeset(attrs)
    |> Repo.update()
    |> broadcast(:item_updated)
  end

  def delete_item(%Item{} = item) do
    item
    |> Repo.delete()
    |> broadcast(:item_deleted)
  end

  def clear_items do
    {:ok, _} = Repo.delete_all(from(Item))
    Phoenix.PubSub.broadcast(ShoppingList.PubSub, @topic, {:items_cleared, :ok})
    {:ok, :cleared}
  end

  def reorder_item_ids(item_ids) do
    Repo.transaction(fn ->
      Enum.with_index(item_ids)
      |> Enum.reduce(:ok, fn {id, order}, :ok ->
        case Repo.get(Item, id) do
          nil -> {:error, "Item #{id} not found"}
          item -> update_item(item, %{"sort_order" => order})
        end
      end)
      |> case do
        :ok ->
          items = Enum.map(item_ids, &Repo.get!(Item, &1))
          Phoenix.PubSub.broadcast(ShoppingList.PubSub, @topic, {:items_reordered, items})
          {:ok, items}
        error -> error
      end
    end)
  end

  def get_item!(id), do: Repo.get!(Item, id)

  defp broadcast({:ok, item}, event) do
    Phoenix.PubSub.broadcast(ShoppingList.PubSub, @topic, {event, item})
    {:ok, item}
  end
  defp broadcast({:error, _} = error, _event), do: error
end
```

---

## 5. UI (Web LiveView)

### Single-Page HTML Interface
- Text input with "Add" button
- Item list with per-item delete (x) button
- Toggle completion checkbox per item
- Quantity adjustment controls per item
- Refresh button to reload the list
- Empty state message when no items exist
- Auto-focus on input after adding an item
- Real-time synchronization across multiple connected clients

### LiveView Component (lib/shopping_list_web/live/item_live/index.ex)
- Pure functional pipeline approach
- `mount/3` subscribes to PubSub topic
- Explicit pattern matching for `:item_created`, `:item_updated`, `:item_deleted`, `:items_reordered`, `:items_cleared` broadcasts
- Handles form submission, deletion, reordering, and clear-all operations

---

## 6. Infrastructure Setup & Secure Deployment Architecture

The application uses an asymmetrical, outbound-only "pull-based" deployment engine. The hosting mini PC remains invisible to the public internet while updating automatically on user-approved merges.

### Production Dockerfile (/Dockerfile)
```dockerfile
FROM hexpm/elixir:1.18.1-erlang-27.2-alpine-3.21.2 AS builder
RUN apk add --no-cache build-base git nodejs npm
WORKDIR /app
RUN mix local.hex --force && mix local.rebar --force
ENV MIX_ENV="prod"
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mix deps.compile
COPY config config
COPY lib lib
COPY priv priv
COPY assets assets
RUN cd assets && npm ci
RUN mix assets.build
RUN mix compile
RUN mix release --overwrite

FROM alpine:3.21.2
RUN apk add --no-cache libstdc++ openssl ncurses-libs timezone sqlite-dev
WORKDIR /app
RUN chown nobody:nobody /app
USER nobody:nobody
COPY --from=builder --chown=nobody:nobody /app/_build/prod/rel/shopping_list ./
ENV HOME=/app
ENV MIX_ENV="prod"
ENV PORT=4000
EXPOSE 4000
CMD ["/app/bin/shopping_list", "start"]
```

### GitHub Actions CI/CD (/.github/workflows/deploy.yml)
```yaml
name: Production CI/CD Pipeline
on:
  push:
    branches: [ main ]
jobs:
  verify-and-build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4
      - name: Set up Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.18.1'
          otp-version: '27.2'
      - name: Cache Dependencies & Build Artifacts
        uses: actions/cache@v4
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
          restore-keys: ${{ runner.os }}-mix-
      - name: Install & Compile Dependencies
        run: |
          mix deps.get
          mix deps.compile
      - name: Run Quality Verification Suite
        run: |
          mix format --check-formatted
          mix credo --strict
          mix test
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      - name: Authenticate to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: Convert Repository Name to Lowercase
        run: echo "REPO_LOWER=$(echo '${{ github.repository }}' | tr '[:upper:]' '[:lower:]')" >> $GITHUB_ENV
      - name: Build and Push Docker Image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ghcr.io/${{ env.REPO_LOWER }}/shopping_list:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

### Host Deployment (docker-compose.yml)
```yaml
version: '3.8'
services:
  shopping_list_app:
    image: ghcr.io/${GITHUB_USER_LOWER}/shopping_list:latest
    container_name: shopping_list_prod
    restart: unless-stopped
    environment:
      - PHX_SERVER=true
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - DATABASE_PATH=/app/data/shopping_list_prod.db
    ports:
      - "4000:4000"
    volumes:
      - ./data:/app/data
  watchtower:
    image: containrrr/watchtower
    container_name: deployment_watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_POLL_INTERVAL=${WATCHTOWER_INTERVAL:-300}
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_TIMEOUT=30s
```

### Environment Variables (/.env.example)
```
GITHUB_USER_LOWER=your_github_username_lowercase
SECRET_KEY_BASE=generate_with_mix_phx_gen_secret_value
WATCHTOWER_INTERVAL=300
```

---

## 7. Phase-by-Phase Development Lifecycle

Each phase must be completed and tested before progressing to the next.

### Phase 1: Foundation & Environment Bootstrapping
1. Scaffold app: `mix phx.new shopping_list --database sqlite3 --binary-id`
2. Configure SQLite WAL mode in `config/runtime.exs`
3. Install Tailwind CSS v4 and DaisyUI in `assets/`
4. Create items migration with full schema (id, name, quantity, is_completed, sort_order, timestamps)
5. Generate Item schema and changeset with validations (name: 1-200 chars, quantity: positive integer)
- **Verification**: `mix test` confirms compilation and basic schema tests pass

### Phase 2: Context, API & Real-Time Sync
1. Implement `ShoppingList.List` context with all CRUD operations, reorder, and clear
2. Create REST API controllers for `/api/items` endpoints (GET, POST, PUT, DELETE, reorder, clear)
3. Implement `/health` endpoint returning status, item count, and db connection status
4. Setup Phoenix PubSub broadcasting for all mutations
5. Configure router with API scope and LiveView routes
- **Verification**: Integration tests for all REST endpoints, including 404 on non-existent items

### Phase 3: LiveView UI & Real-Time Synchronization
1. Create `lib/shopping_list_web/live/item_live/index.ex` with pure functional pipeline approach
2. Implement `mount/3` with PubSub subscription
3. Handle all PubSub broadcasts with explicit pattern matching
4. Build UI: text input + Add button, item list with delete/toggle/quantity controls, refresh button, empty state
5. Implement auto-focus on input after adding item
6. Implement drag-and-drop or API-based reordering UI
- **Verification**: `test/shopping_list_web/live/item_live_test.exs` with dual-socket simulation for real-time cross-client sync

### Phase 4: MCP Server Integration
1. Create dedicated route `/api/mcp` returning SSE protocol payload conforming to MCP schemas
2. Implement MCP tools: `list_items`, `add_item(name, quantity)`, `update_item(id, attrs)`, `remove_item(id)`, `reorder_items(item_ids)`, `clear_items`
3. Map MCP tools to internal `ShoppingList.List` context APIs
- **Verification**: Isolated controller integration tests asserting JSON responses match MCP structural envelopes

### Phase 5: Production Hardening, QA & Handover
- **Static Analysis**:
  - `mix credo --strict`
  - `mix dialyzer`
  - `mix sobelow --config`
- **Docker & CI/CD**: Finalize Dockerfile, GitHub Actions workflow, docker-compose.yml
- **Documentation**: Verify .env.example, deployment instructions
- **Full Test Suite**: `mix test` — all tests pass with 100% coverage of critical paths

---

## 8. Quality Testing Standards

### Context Domain Unit Tests (test/shopping_list/list_test.exs)
```elixir
defmodule ShoppingList.ListTest do
  use ShoppingList.DataCase, async: true
  alias ShoppingList.List

  describe "items context transaction layer" do
    @valid_attrs %{"name" => "Organic Milk", "quantity" => 2}

    test "create_item/1 with valid configurations saves item" do
      assert {:ok, item} = List.create_item(@valid_attrs)
      assert item.name == "Organic Milk"
      assert item.quantity == 2
      assert item.is_completed == false
    end

    test "create_item/1 fails on blank name" do
      assert {:error, changeset} = List.create_item(%{"name" => ""})
      assert {"can't be blank", _} in errors_on(changeset).name
    end

    test "create_item/1 fails on name exceeding 200 characters" do
      long_name = String.duplicate("a", 201)
      assert {:error, changeset} = List.create_item(%{"name" => long_name})
      assert {"should be at most 200 character(s)", _} in errors_on(changeset).name
    end

    test "new items appear at the top (lowest sort_order)" do
      {:ok, first} = List.create_item(%{"name" => "First"})
      {:ok, second} = List.create_item(%{"name" => "Second"})
      assert second.sort_order < first.sort_order
      items = List.list_items()
      assert Enum.at(items, 0).name == "Second"
    end

    test "clear_items removes all items" do
      List.create_item(%{"name" => "Item 1"})
      List.create_item(%{"name" => "Item 2"})
      assert {:ok, :cleared} = List.clear_items()
      assert [] = List.list_items()
    end

    test "reorder_item_ids updates sort order correctly" do
      {:ok, item1} = List.create_item(%{"name" => "First"})
      {:ok, item2} = List.create_item(%{"name" => "Second"})
      assert {:ok, reordered} = List.reorder_item_ids([item2.id, item1.id])
      assert Enum.at(reordered, 0).sort_order == 0
      assert Enum.at(reordered, 1).sort_order == 1
    end
  end
end
```

### Real-Time LiveView Integration Tests (test/shopping_list_web/live/item_live_test.exs)
```elixir
defmodule ShoppingListWeb.ItemLiveTest do
  use ShoppingListWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  test "concurrent UI synchronization across decoupled active sessions", %{conn: conn} do
    {:ok, view_client_a, _html_a} = live(conn, "/items")
    {:ok, view_client_b, _html_b} = live(conn, "/items")
    render_submit(view_client_a, "save", %{"item" => %{"name" => "Sourdough Bread", "quantity" => "1"}})
    assert render(view_client_b) =~ "Sourdough Bread"
  end
end
```

### REST API Integration Tests
- Test all CRUD endpoints (GET, POST, PUT, DELETE, reorder, clear)
- Verify 404 on deleting non-existent items
- Verify health endpoint returns correct status
- Test reorder endpoint with valid and invalid ID sequences

### MCP Integration Tests
- Verify SSE connection establishment
- Assert JSON response envelopes for each MCP tool
- Test error handling for invalid inputs

---

## 9. Quality of Service
- Health endpoint (`/health`) for monitoring with status, item count, and DB connection verification
- Container runs with `restart: unless-stopped`
- Watchtower polls every 300s (configurable) for zero-downtime updates
- All data persisted to mounted volume, surviving container restarts
