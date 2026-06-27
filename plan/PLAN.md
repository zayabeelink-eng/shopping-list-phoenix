# Combined Implementation Plan: Real-Time Phoenix Shopping List & MCP Server

This specification merges the architectural blueprint from Gemini with the functional requirements document into a single, unified plan. It serves as the authoritative context blueprint for building the Elixir/Phoenix shopping list application with MCP server capabilities.

---

## 1. Project Specifications & Architectural Safeguards

### Tech Stack Constraints
- **Runtime**: Elixir 1.18+ (OTP 26+), Phoenix 1.8.5+, LiveView 1.1+, Bandit (HTTP server)
- **Database**: SQLite 3 via ecto_sqlite3. No PostgreSQL dependencies allowed.
- **UI Framework**: Tailwind CSS v4 + DaisyUI v5 component library.
- **Code Quality & Linting**: Strict Credo, Dialyxir (Dialyzer typespecs), and Sobelow (Static security analysis).
- **Deployment Target**: Single Docker container running an Elixir Release, deployed onto a self-hosted mini PC on a private Tailscale network.

### LLM Context & Execution Boundaries
- **Deterministic Sandboxing**: All operations must execute exclusively within the project directory workspace. No host binaries, Docker sockets, or elevated privileges.
- **Stateless Compilation**: Execute `mix compile`, `mix assets.build`, and `mix test && mix credo --strict` inside the sandbox prior to committing any file.
- **Defensive Code Structure**: Prioritize small, pipeline-oriented functions (`|>`), pattern matching in function heads, and strict module boundaries. Avoid monolithic files.

### Pre-Commit Enforcement (lefthook)
- Every commit runs `mix format --check-formatted`, `mix credo --strict`, `mix compile --warnings-as-errors`, and `mix test --warnings-as-errors`
- Halt on any failure — no bypassing quality gates
- Config stored in `lefthook.yml` (checked into version control)

---

## 2. Functional Requirements

### Item Management
- **Add item** — user can add an item by name (plain text, 1–200 characters)
- **List items** — view all items with ID, name, quantity, completion status, and creation timestamp
- **Remove item** — delete a single item by its ID
- **Clear all** — remove every item from the list at once
- **Toggle completion** — mark an item as completed or incomplete

### Ordering
- **Reorder items** — user or AI can set a custom order by submitting the full sequence of item IDs. New items appear at the top by default (highest sort_order value).
- **Display order** — items are sorted by `sort_order` (descending), then creation date (descending).

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
| PUT | `/api/items/reorder` | Reorder items (body: `{"item_ids": ["id1", "id2", ...]}`) |
| PUT | `/api/items/{id}` | Update an item (e.g., toggle completion, change quantity) |
| DELETE | `/api/items/clear` | Remove all items |
| DELETE | `/api/items/{id}` | Remove an item by ID |
| GET | `/health` | Health check — returns status, item count, db connection |

> **Route ordering**: `PUT /api/items/reorder` and `DELETE /api/items/clear` must be defined **above** their parameterized counterparts (`/api/items/:id`) in the router, otherwise Phoenix will match `"reorder"` and `"clear"` as `:id` values.

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
- **Name normalization**: trimmed + capitalized on write (milk → Milk, MILK → Milk) so analytics group correctly
  - `sort_order` (INTEGER, for custom ordering)
  - `deleted_at` (TIMESTAMP, nullable — soft delete marker)
  - `inserted_at` (TIMESTAMP)
  - `updated_at` (TIMESTAMP)
- **Index**: on `is_completed` for efficient filtering; on `deleted_at` for soft-delete queries
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
      add :deleted_at, :naive_datetime
      timestamps()
    end
    create index(:items, [:is_completed])
    create index(:items, [:sort_order])
    create index(:items, [:deleted_at])
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
    |> where([i], is_nil(i.deleted_at))
    |> order_by([i], desc: i.sort_order, desc: i.inserted_at)
    |> Repo.all()
  end

  def list_active_items do
    Item
    |> where([i], is_completed: false)
    |> where([i], is_nil(i.deleted_at))
    |> order_by([i], desc: i.sort_order, desc: i.inserted_at)
    |> Repo.all()
  end

  def create_item(attrs \\ %{}) do
    max_order = Repo.aggregate(Item, :max, :sort_order) || 0
    next_order = max_order + 1
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
    now = DateTime.utc_now()
    item
    |> Item.changeset(%{deleted_at: now})
    |> Repo.update()
    |> broadcast(:item_deleted)
  end

  def clear_items do
    now = DateTime.utc_now()
    {count, _} =
      Item
      |> where([i], is_nil(i.deleted_at))
      |> Repo.update_all(set: [deleted_at: now])

    Phoenix.PubSub.broadcast(ShoppingList.PubSub, @topic, {:items_cleared, count})
    {:ok, count}
  end

  def reorder_item_ids(item_ids) do
    total = length(item_ids)

    result =
      Repo.transaction(fn ->
        Enum.with_index(item_ids)
        |> Enum.map(fn {id, index} ->
          case Repo.get(Item, id) do
            nil -> Repo.rollback("Item #{id} not found")
            item ->
              item
              |> Item.changeset(%{"sort_order" => total - index - 1})
              |> Repo.update!()
          end
        end)
      end)

    case result do
      {:ok, items} ->
        Phoenix.PubSub.broadcast(ShoppingList.PubSub, @topic, {:items_reordered, items})
        {:ok, items}

      {:error, reason} ->
        {:error, reason}
    end
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
- Empty state message when no items exist
- Auto-focus on input after adding an item
- Real-time synchronization across multiple connected clients (no manual refresh needed)

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

Each phase must be completed and tested before progressing to the next. Detailed step-by-step instructions, file changes, and test requirements are in each phase file.

| Phase | File | Status |
|-------|------|--------|
| 1: Foundation & Environment Bootstrapping | [`plan/phase-1-foundation.md`](phase-1-foundation.md) | In progress |
| 2: Context, API & Real-Time Sync | [`plan/phase-2-context-api.md`](phase-2-context-api.md) | Pending |
| 3: LiveView UI & Real-Time Synchronization | [`plan/phase-3-liveview-ui.md`](phase-3-liveview-ui.md) | Pending |
| 4: MCP Server Integration | [`plan/phase-4-mcp-server.md`](phase-4-mcp-server.md) | Pending |
| 5: Production Hardening, QA & Handover | [`plan/phase-5-production.md`](phase-5-production.md) | Complete |

---

## 8. Quality Testing Standards

Detailed test code and test plans are in each phase file:

| Tests | Phase File |
|-------|------------|
| Schema unit tests (`item_test.exs`) | [`plan/phase-1-foundation.md`](phase-1-foundation.md) |
| Context unit tests (`list_test.exs`) | [`plan/phase-2-context-api.md`](phase-2-context-api.md) |
| REST API integration tests (`item_controller_test.exs`, `health_controller_test.exs`) | [`plan/phase-2-context-api.md`](phase-2-context-api.md) |
| LiveView integration tests (`item_live_test.exs`) | [`plan/phase-3-liveview-ui.md`](phase-3-liveview-ui.md) |
| MCP integration tests (`mcp_controller_test.exs`) | [`plan/phase-4-mcp-server.md`](phase-4-mcp-server.md) |

### Coverage Requirements
- All changeset validations must have unit tests
- All context functions must have happy-path and error-path tests
- All REST endpoints must have at least one success and one failure case
- MCP methods must test valid calls, error codes, and unknown methods
- LiveView tests must verify real-time sync across two concurrent sessions

---

## 9. Quality of Service
- Health endpoint (`/health`) for monitoring with status, item count, and DB connection verification
- Container runs with `restart: unless-stopped`
- Watchtower polls every 300s (configurable) for zero-downtime updates
- All data persisted to mounted volume, surviving container restarts
