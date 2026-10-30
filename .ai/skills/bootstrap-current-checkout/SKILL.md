---
name: bootstrap-current-checkout
description: Bootstrap the current FrankenPHP checkout and shared local services. Use when the environment is missing, stale, or after changing infra files.
---

# Bootstrap Current Checkout

## When to use this skill

Use this skill when the repo needs a ready local environment for the current checkout.

## Workflow

1. Run `./scripts/bootstrap.sh` from the repo root.
2. Prefer rerunning the script over hand-editing generated `.env` values.
3. If bootstrap behavior changes, update `README.md`, `.env.example`, and the relevant script in the same change.

## Important repo facts

- The bootstrap flow expects the sibling `shared-traefik` repo and keeps the checkout on `.localhost` HTTPS.
- The main checkout uses `app.localhost` and `vite.app.localhost`.
- Worktrees use `<checkout>.app.localhost` and `<checkout>-vite.app.localhost`.
- Runtime services are Docker Compose `app` for FrankenPHP and `vite` for Vite; do not use Sail.
- Use `./scripts/traefik.sh` as the only bridge to the shared Traefik repo.

## Do not do this

- Do not write dynamic Traefik files directly from this repo.
- Do not hand-edit generated checkout-specific env values unless the user explicitly asks for it.
