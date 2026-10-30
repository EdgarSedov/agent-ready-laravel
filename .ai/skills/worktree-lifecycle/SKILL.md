---
name: worktree-lifecycle
description: Create, bootstrap, clean up, and remove sibling worktrees for this repo using the checked-in scripts.
---

# Worktree Lifecycle

## When to use this skill

Use this skill when working with sibling worktrees for this repo.

## Workflow

1. Create a checkout with `./scripts/worktree-create.sh <branch>`.
2. Check state with `./scripts/status.sh`.
3. Clean up a checkout with `./scripts/worktree-cleanup.sh` before removing it.
4. Keep the repo's sibling layout convention instead of inventing ad-hoc worktree locations.

## Important repo facts

- Worktree setup is repo-owned automation, not manual shell choreography.
- Cleanup should preserve shared Traefik and shared services unless the user explicitly asks for a full teardown.
- Worktree bootstrap may symlink ignored local files from the source checkout.
- If local environment drift is the problem, bootstrap the affected checkout again instead of patching generated state by hand.
