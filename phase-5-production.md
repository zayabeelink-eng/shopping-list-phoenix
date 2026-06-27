# Phase 5: Production Hardening, QA & Handover

## Goal
Finalize the production deployment pipeline: Docker image, CI/CD workflow, Docker Compose for the host, static analysis, and documentation. Ensure everything passes quality gates.

## Prerequisites
- Phases 1–4 complete (all features implemented and tested)

## Steps & Commits

### Step 1: Create Dockerfile
Multi-stage build for a minimal production image.

**Files**: `Dockerfile`
**Stages**:
1. **Builder** — `hexpm/elixir:1.18.1-erlang-27.2-alpine-3.21.2`
   - Install build-base, git, nodejs, npm
   - Install Hex + Rebar
   - Fetch deps (cached via layer ordering)
   - Copy config, lib, priv, assets
   - Run `npm ci && mix assets.build && mix compile`
   - Build release: `mix release --overwrite`
2. **Runtime** — `alpine:3.21.2`
   - Install libstdc++, openssl, ncurses-libs, timezone, sqlite-dev
   - Copy release artifact from builder
   - Run as `nobody:nobody`
   - Expose port 4000

**Verification**: `docker build -t shopping_list .` succeeds.

**Commit**: `add production dockerfile`

### Step 2: Create GitHub Actions CI/CD workflow
Automated verification and Docker image build/push on pushes to `main`.

**Files**: `.github/workflows/deploy.yml`
**Pipeline**:
1. **Checkout** — `actions/checkout@v4`
2. **Setup Elixir** — `erlef/setup-beam@v1` (Elixir 1.18.1, OTP 27.2)
3. **Cache** — `actions/cache@v4` for deps + _build
4. **Deps** — `mix deps.get && mix deps.compile`
5. **Quality** — `mix format --check-formatted && mix credo --strict && mix test`
6. **Docker Buildx** — `docker/setup-buildx-action@v3`
7. **Login to GHCR** — `docker/login-action@v3`
8. **Build & Push** — `docker/build-push-action@v5` with `ghcr.io/${{ env.REPO_LOWER }}/shopping_list:latest`

**Commit**: `add ci-cd github actions workflow`

### Step 3: Create Docker Compose for host deployment
Deployment configuration for the mini PC.

**Files**: `docker-compose.yml`
**Services**:
- `shopping_list_app` — pulls from GHCR, port 4000, persistent data volume
- `watchtower` — polls for new images and auto-updates

**Commit**: `add docker-compose for host deployment`

### Step 4: Create environment variable example

**Files**: `.env.example`
**Variables**:
```
GITHUB_USER_LOWER=your_github_username_lowercase
SECRET_KEY_BASE=generate_with_mix_phx_gen_secret_value
WATCHTOWER_INTERVAL=300
```

**Commit**: `add env example`

### Step 5: Run full static analysis suite
Run all analysis tools and fix any issues.

```bash
mix format --check-formatted
mix credo --strict
mix dialyzer
mix sobelow --config
```

**Commit**: `fix static analysis warnings`

### Step 6: Final test pass and documentation update
```bash
mix test  # Full suite passes
mix precommit  # Entire quality gate
```

Update `PLAN.md` completion status and verify `README.md` matches final state.

**Commit**: `final qa pass and documentation update`

## Verification
```bash
mix test  # All pass
mix credo --strict  # Zero issues
mix format --check-formatted  # Clean
docker build -t shopping_list .  # Builds successfully
```
