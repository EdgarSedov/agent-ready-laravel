# Agent Instructions

Use the checked-in scripts as the source of truth for local environment workflows.

## Working Rules

- Bootstrap the current checkout with `./scripts/bootstrap.sh`.
- Use `./scripts/worktree-create.sh <branch>` for sibling worktrees.
- Use `./scripts/worktree-cleanup.sh` before removing a worktree.
- Use `./scripts/traefik.sh` to talk to the shared Traefik repo. Do not write route files directly.
- Keep shared guidance in tracked files. Keep personal preferences in ignored `AGENTS.local.md`.
- When env generation or local infra behavior changes, update `README.md`, `.env.example`, and the relevant script together.
- This repo is prepared for Laravel Boost later, but the default workflow should stay usable without it.

## AI Asset Layout

- tracked shared source: `AGENTS.md`, `AGENTS.local.md.example`, `.ai/skills/*/SKILL.md`, optional `.ai/agents/`, `opencode.jsonc.example`
- ignored local overlays: `AGENTS.local.md`, `opencode.jsonc`
- optional ignored client outputs when the team later enables Boost or other client automation: `opencode.json`, `.mcp.json`, `.agents/skills/`, `.codex/`, `.claude/`, `.copilot/`

## Expected Flow

1. Make or verify the code change.
2. Run the smallest relevant verification step.
3. If local environment drift is the problem, rerun `./scripts/bootstrap.sh` instead of hand-editing generated `.env` values.
4. If local OpenCode config drifts, compare ignored `opencode.jsonc` with `opencode.jsonc.example` before changing tracked instructions.
5. If the team later installs Laravel Boost, review any generated local client files before relying on them.
