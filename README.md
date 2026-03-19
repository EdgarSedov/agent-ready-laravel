# agent-ready-laravel

Normal Laravel app scaffold with worktree-safe bootstrap scripts, shared project services, portable agent assets, and room for optional Laravel Boost later.

This repo keeps the app repo normal while making room for:

- one idempotent checkout bootstrap command
- sibling Git worktrees with generated hostnames and databases
- shared Postgres, Redis, and Mailpit across worktrees
- `.localhost` HTTPS via a separate `shared-traefik` repo
- tracked repo instructions plus ignored local AI overlays

## Repo Layout

```text
agent-ready-laravel/
  AGENTS.md
  AGENTS.local.md.example
  CLAUDE.md -> AGENTS.md
  opencode.jsonc.example
  .ai/
  scripts/
  docker/
  docker-compose.yml
  docker-compose.traefik.yml
```

## Requirements

- Docker with the Compose plugin
- sibling `shared-traefik/` repo, or `SHARED_TRAEFIK_PATH` set to it
- `mkcert` if you want trusted local certs in the shared Traefik repo

PHP and Composer are optional on the host. When host Composer is not available, bootstrap falls back to the `composer:2` Docker image. Node is also optional; standard Laravel tasks can stay containerized through Sail.

## Companion Repo

This setup expects the shared local HTTPS and reverse-proxy repo here:

- `shared-traefik`: https://github.com/EdgarSedov/shared-traefik

Clone it as a sibling directory, or point `SHARED_TRAEFIK_PATH` to an existing checkout.

## Bootstrap

Bootstrap the current checkout:

```bash
./scripts/bootstrap.sh
```

That flow will:

- create `.env` from local state or `.env.example`
- derive checkout identity values and write them into `.env`
- install Composer dependencies when needed
- start shared Postgres, Redis, and Mailpit
- ensure shared Traefik is up
- start the current checkout's app container behind Traefik on `traefik-public`
- create the checkout's app and test databases
- run safe Laravel bootstrap tasks such as key generation and migrations
- expose the current checkout's Vite hostname through Traefik labels on the app container

Bootstrap is HTTPS-first. The checkout gets stable local hostnames:

- main app: `https://app.localhost`
- main Vite: `https://vite.app.localhost`
- worktree app: `https://<checkout>.app.localhost`
- worktree Vite: `https://<checkout>-vite.app.localhost`

Useful follow-up commands:

```bash
make up
./vendor/bin/sail composer dev
./vendor/bin/sail artisan test
```

`./vendor/bin/sail composer dev` is fine for queue/log/Vite tasks, and both the app and Vite are served from the Sail container behind Traefik.

If you do not have Node on the host, use `./vendor/bin/sail composer dev`. It keeps queue, logs, and Vite inside Sail, and you can stop it with `Ctrl+C` when you are done.

`./vendor/bin/sail artisan test` stays on Laravel's stock `sqlite` in-memory test config from `phpunit.xml` so the example repo keeps the default low-friction testing path. Bootstrap still provisions a checkout-local `DB_TEST_DATABASE` in shared Postgres for teams that later opt into DB-backed tests such as `RefreshDatabase` against Postgres.

Quick smoke checks:

```bash
curl -I https://app.localhost
./vendor/bin/sail composer dev
curl -I https://vite.app.localhost/@vite/client
```

## Workspace Layout

Expected sibling layout:

```text
~/projects/
  shared-traefik/
  agent-ready-laravel/
  agent-ready-laravel-wt/
    feature-auth/
```

Bring up the shared proxy once:

```bash
../shared-traefik/bin/ensure
```

Then bootstrap this checkout:

```bash
./scripts/bootstrap.sh
```

The app container is attached to `traefik-public` through `docker-compose.traefik.yml`, both the app and Vite are routed through Docker labels by default, and Laravel trusts local forwarded proxy headers so scheme-aware URLs and cookies stay correct behind Traefik.

For sibling worktrees, shared services and `shared-traefik/` are resolved relative to the primary checkout so the documented workspace layout stays stable. If you set `SHARED_TRAEFIK_PATH`, relative paths are also interpreted from that primary checkout.

Bootstrap keeps a deterministic Vite port per checkout, but that port now stays inside the container by default, so worktree setup no longer depends on host port publishing or shared Traefik route registration. Dependency snapshots are reused only when the current lockfile still matches; otherwise bootstrap falls back to a fresh install.

Search for `AGENT_READY_OPTIONAL_HOST_VITE` if you want to switch back to a host-run Vite workflow and re-enable the related port publishing and Traefik file-provider hooks.

## Worktrees

Create a sibling worktree under `../agent-ready-laravel-wt/`:

```bash
./scripts/worktree-create.sh feature-auth
```

Clean up only the current checkout's runtime state:

```bash
./scripts/worktree-cleanup.sh
```

That cleanup intentionally leaves shared Postgres, Redis, Mailpit, and shared Traefik running for the other checkouts.

## Optional Boost Later

This repo is prepared for Laravel Boost, but does not install it by default.

Why keep Boost off by default:

- a fresh clone stays closer to stock Laravel
- the default demo path keeps fewer moving parts
- teams can review the dependency and generated local files before opting in

If a team later wants Boost, the usual path is:

1. add `laravel/boost` as a dev dependency
2. create and review a tracked `boost.json`
3. run `./vendor/bin/sail artisan boost:install --no-interaction`
4. review generated local files such as `opencode.json` and any optional client folders
5. rerun `./vendor/bin/sail artisan boost:update --no-interaction` later when refreshing synced guidance

The default repo contract still works without Boost: shared instructions live in `AGENTS.md`, personal reminders live in ignored `AGENTS.local.md`, and reusable workflows live in `.ai/skills/`.

## AI Asset Pattern

Tracked shared source lives in the repo:

- `AGENTS.md`
- `AGENTS.local.md.example`
- `opencode.jsonc.example`
- `.ai/skills/`
- optional `.ai/agents/`

Ignored local overlays stay local:

- `AGENTS.local.md`
- `opencode.jsonc`

Optional ignored client outputs also stay local when a team later enables Boost or other client automation:

- `opencode.json`
- `.mcp.json`
- `.agents/skills/*`
- `.claude/`
- `.codex/`
- `.copilot/`

Typical local OpenCode flow:

```bash
cp opencode.jsonc.example opencode.jsonc
mkdir -p .agents/skills
ln -sfn ../../.ai/skills/bootstrap-current-checkout .agents/skills/bootstrap-current-checkout
ln -sfn ../../.ai/skills/worktree-lifecycle .agents/skills/worktree-lifecycle
```

Workflow asset notes:

- `.ai/skills/` is the tracked source of truth for repo-owned skills.
- `.agents/skills/` is just a local discovery surface for OpenCode when you want it.
- `AGENTS.md` carries the shared repo contract, while `AGENTS.local.md` keeps personal reminders local.
- If the team later installs Boost, it can publish or sync local client files from these tracked sources, but that is an explicit opt-in step.

If you want a manual OpenCode config with local instructions, copy `opencode.jsonc.example` to ignored `opencode.jsonc`. The commented example also shows where a future Laravel Boost MCP block would go if the team chooses to enable it later.

The rule stays simple: scripts do the work; repo instructions and skills tell the client when to call them.

## Next Steps

Once the main checkout is healthy, the next useful checks are:

1. Keep `./vendor/bin/sail composer dev` running and verify HMR at `https://app.localhost`.
2. Create a sibling worktree with `./scripts/worktree-create.sh feature-auth` and confirm `https://feature-auth.app.localhost` plus `https://feature-auth-vite.app.localhost`.
3. Capture the working state in a git commit when you are happy with the docs and runtime behavior.
