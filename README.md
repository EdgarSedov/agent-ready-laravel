# agent-ready-laravel

Fresh Laravel 13 template with FrankenPHP, shared local services, Traefik HTTPS, worktree-safe bootstrap, and portable agent guidance.

## Requirements

- Docker with Compose plugin
- sibling `shared-traefik/` repo, or `SHARED_TRAEFIK_PATH` pointing to it
- `mkcert` in `shared-traefik` if you want trusted local certificates

Host PHP, Composer, and Node are optional. Bootstrap runs Composer inside the FrankenPHP `app` service and npm inside the `vite` service.

## Bootstrap

```bash
./scripts/bootstrap.sh
```

Bootstrap will:

- create `.env` from `.env.example` or source checkout state
- derive checkout slug, compose project, domains, and database names
- link ignored local files from the source checkout when present
- install Composer and npm dependencies in containers
- start shared Postgres, Redis, Mailpit, and Traefik
- create app and test databases
- run key generation and migrations
- start FrankenPHP `app` and Vite `vite` behind Traefik

Default URLs:

- app: `https://app.localhost`
- Vite: `https://vite.app.localhost`
- worktree app: `https://<checkout>.app.localhost`
- worktree Vite: `https://<checkout>-vite.app.localhost`
- Mailpit: `http://localhost:8025`

## Daily Commands

```bash
./scripts/status.sh
docker compose run --rm --no-deps app php artisan test
docker compose run --rm --no-deps app php artisan migrate
docker compose logs -f app vite
```

## Worktrees

Create a sibling worktree:

```bash
./scripts/worktree-create.sh feature-auth
```

Clean the current checkout runtime state:

```bash
./scripts/worktree-cleanup.sh
```

Remove a non-primary worktree after cleanup:

```bash
./scripts/worktree-cleanup.sh --remove-worktree
```

Shared Postgres, Redis, Mailpit, and Traefik are intentionally preserved for other checkouts.

## Runtime

- `app` uses FrankenPHP classic request mode, not Octane workers.
- `vite` is a separate Node container and is routed through Traefik Docker labels.
- Postgres, Redis, and Mailpit run under a shared Compose profile and are reused across worktrees.
- `.env` is per checkout; ignored local files such as `auth.json`, `AGENTS.local.md`, `opencode.jsonc`, and `.mcp.json` can be symlinked from the source checkout.

Octane/FrankenPHP worker mode can be added later, but it is intentionally not the default because long-lived workers change local development behavior.

## Agent Assets

Tracked shared guidance:

- `AGENTS.md`
- `AGENTS.local.md.example`
- `.ai/skills/*`
- `opencode.jsonc.example`

Ignored local overlays:

- `AGENTS.local.md`
- `auth.json`
- `opencode.jsonc`
- `.mcp.json`
- `.agents/skills/*`

Bootstrap installs local `.agents/skills/*` symlinks from tracked `.ai/skills/*` when possible.
