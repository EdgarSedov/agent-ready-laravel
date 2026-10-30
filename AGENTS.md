# Agent Instructions

Use repo scripts as the source of truth for local environment workflows.

## Core Rules

- Bootstrap the current checkout with `./scripts/bootstrap.sh`.
- Check state with `./scripts/status.sh`.
- Create worktrees with `./scripts/worktree-create.sh <branch>`.
- Clean a checkout with `./scripts/worktree-cleanup.sh`; do not hand-delete Docker resources.
- Do not edit generated checkout identity values in `.env`; rerun bootstrap.
- Use Docker Compose services `app` and `vite`; do not use Sail.
- Use `./scripts/traefik.sh` for shared Traefik; do not write Traefik runtime files directly.

## Local Files

- Shared team guidance lives in tracked files such as `AGENTS.md` and `.ai/skills/*`.
- Personal or machine-local files stay ignored: `AGENTS.local.md`, `auth.json`, `opencode.jsonc`, `.mcp.json`.
- Worktree bootstrap may symlink those ignored local files from the source checkout when present.

## Verification

- After infra changes, run `./scripts/bootstrap.sh` and `./scripts/status.sh`.
- After app changes, run `docker compose run --rm --no-deps app php artisan test`.
- Smoke app URLs through Traefik: `https://app.localhost` and `https://vite.app.localhost/@vite/client`.
