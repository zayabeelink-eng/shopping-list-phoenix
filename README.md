# Shopping List

A real-time shopping list application built with Phoenix LiveView. Runs on a private Tailscale network with an MCP JSON-RPC 2.0 API for AI agent integration.

## Tech Stack

- **Runtime**: Elixir 1.20+, Erlang 29+, Phoenix 1.8.8
- **Database**: SQLite via ecto_sqlite3
- **UI**: Tailwind CSS v4 + DaisyUI v5
- **Real-Time**: Phoenix LiveView + PubSub

## Getting Started

```bash
git clone git@github.com:zayabeelink-eng/shopping-list-phoenix.git
cd shopping-list-phoenix

# Install dependencies and set up database
mix setup

# Start the server
mix phx.server
```

Visit [http://localhost:4000](http://localhost:4000).

## Development

```bash
mix compile --warnings-as-errors   # Compile with strict warnings
mix format                         # Auto-format all files
mix credo --strict                 # Static analysis
mix test                           # Run tests
mix precommit                      # Run the full quality gate

# Pre-commit hooks (lefthook) run mix precommit automatically on every commit
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/items` | List all items |
| POST | `/api/items` | Add an item |
| PUT | `/api/items/:id` | Update an item |
| DELETE | `/api/items/:id` | Remove an item |
| PUT | `/api/items/reorder` | Reorder items |
| DELETE | `/api/items/clear` | Clear all items |
| GET | `/health` | Health check |

## Deployment

Deployed as a Docker container on a self-hosted mini PC behind Tailscale. CI/CD via GitHub Actions pushes to GHCR, with Watchtower handling automatic updates.

## License

MIT
