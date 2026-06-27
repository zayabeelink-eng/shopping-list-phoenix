# Phase 1: Foundation & Environment Bootstrapping

## Goal
Set up the Phoenix project with SQLite, code quality tooling, pre-commit hooks, database schema, and item model.

## Prerequisites
- Elixir 1.20+, Erlang 29+, Node.js 26+
- Homebrew (for lefthook)
- Phoenix 1.8.8 archive installed (`mix archive.install hex phx_new`)

## Steps & Commits

### Step 1: Scaffold Phoenix app
Generate the project with SQLite and binary IDs.

```bash
mix phx.new . --app shopping_list --database sqlite3 --binary-id --force
```

**Commit**: `scaffold phoenix app with sqlite and binary-id`
**Files**: All generated scaffold files
**Tests**: 5 default Phoenix tests pass

### Step 2: Install lefthook and configure pre-commit hooks
Install lefthook, create config to run `mix precommit` on every commit.

```bash
brew install lefthook
```

**Files**: `lefthook.yml`
**Config**:
```yaml
pre-commit:
  commands:
    precommit:
      run: mix precommit
      env:
        MIX_ENV: test
```

```bash
lefthook install
```

**Verification**: Running `git commit` triggers lefthook which runs `mix format --check-formatted`, `mix credo --strict`, `mix compile --warnings-as-errors`, `mix test`.

### Step 3: Add Credo, Dialyxir, Sobelow to deps
Add QA tooling to the project dependencies.

**Files**: `mix.exs`
**Changes**:
- Add `{:credo, "~> 1.7", only: [:dev, :test], runtime: false}`
- Add `{:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}`
- Add `{:sobelow, "~> 0.13", only: [:dev, :test], runtime: false}`
- Update `precommit` alias to: `["compile --warnings-as-errors", "credo --strict", "format --check-formatted", "test"]`

**Verification**: `mix credo --strict` passes with zero issues.

### Step 4: Fix Credo warnings in generated code
Address any code style issues from the scaffold.

**Files**: `lib/shopping_list/application.ex`, `test/support/data_case.ex`, `lib/shopping_list_web/components/core_components.ex`
**Changes**:
- Remove parens from `skip_migrations?()`
- Add `alias Ecto.Adapters.SQL.Sandbox` in data_case.ex
- Add `alias Phoenix.HTML.Form` in core_components.ex

**Verification**: `mix credo --strict` exits 0.

### Step 5: Add README
**Commit**: `add readme`
**Files**: `README.md`

### Step 6: Configure SQLite WAL mode
Enable WAL mode for concurrent access safety.

**Files**: `config/runtime.exs`
**Changes**: Set SQLite pool size and WAL journal mode.

**Commit**: `configure sqlite wal mode`

### Step 7: Install Tailwind CSS v4 and DaisyUI v5
Phoenix 1.8.8 ships with DaisyUI assets in `assets/vendor/`. Verify Tailwind CSS v4 is configured correctly.

**Files**: `assets/css/app.css`, `assets/js/app.js`, `assets/vendor/daisyui.js`, `assets/vendor/daisyui-theme.js`
**Changes**: Update Tailwind config to use v4 import syntax, wire up DaisyUI plugin.

**Verification**: `mix assets.build` completes without error.

**Commit**: `setup tailwind v4 and daisyui v5`

### Step 8: Create items migration
Generate the database migration for the `items` table.

```bash
mix ecto.gen.migration create_items
```

**Files**: `priv/repo/migrations/{{timestamp}}_create_items.exs`
**Schema**:
- `id` (binary_id, primary key)
- `name` (:string, not null)
- `quantity` (:integer, default 1, not null)
- `is_completed` (:boolean, default false, not null)
- `sort_order` (:integer, default 0)
- `deleted_at` (:naive_datetime, nullable — soft delete marker)
- `inserted_at` (auto from timestamps)
- `updated_at` (auto from timestamps)
- Index on `is_completed`
- Index on `sort_order`
- Index on `deleted_at`

**Commit**: `create items migration`

### Step 9: Generate Item schema and changeset with validations

**Files**: `lib/shopping_list/list/item.ex`
**Validations**:
- `name`: required, 1-200 characters; normalized via trim + capitalize (milk → Milk, " Milk " → "Milk")
- `quantity`: required, must be a positive integer (default 1)
- `is_completed`: default false

**Commit**: `add item schema and changeset`

### Step 10: Add schema unit tests

**Files**: `test/shopping_list/list/item_test.exs`
**Tests**:
- Valid attributes create a valid changeset
- Blank name is rejected
- Name exceeding 200 chars is rejected
- Quantity defaults to 1
- Negative quantity is rejected
- Zero quantity is rejected
- `is_completed` defaults to false
- `deleted_at` is nil for a valid changeset (not set via user input)
- Name normalization: "milk" → "Milk", " MILK " → "Milk", "  hello  " → "Hello"

**Commit**: `add item schema unit tests`

## Verification
```bash
mix test  # All tests pass
mix credo --strict  # Zero issues
lefthook run pre-commit  # Hooks pass
```
