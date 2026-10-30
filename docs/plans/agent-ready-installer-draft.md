# Agent-Ready Laravel Installer Draft

## Purpose

Build a Laravel local-development installer that combines Sail-like command ergonomics, configurable Docker runtimes, worktree-safe local environments, and useful AI-agent project scaffolding.

The first target is a Composer dev package that installs into a Laravel app. A prebuilt starter template can follow after the installer is stable.

## Review Pass Decisions

Two review passes flagged the same core issues: existing-app safety must not be deferred, V1 must be smaller, and cleanup identity must not be re-derived from mutable paths or `.env`.

Decisions from review:

- V1 is fresh-app-first. Existing-app install may be offered only after dry-run, conflict detection, and non-clobber file handling exist.
- Persisted `.agent-ready/worktree.json` is the canonical identity source for managed checkouts. `.env` is a projection of that state, not the source of truth.
- Traefik and a local worktree index are V1 requirements for managed worktrees. Direct exposed ports remain a fallback and diagnostic mode.
- V1 supports FrankenPHP + PostgreSQL + Valkey first. nginx/php-fpm and MySQL are staged next, not dropped.
- JavaScript mode remains explicit, but V1 avoids Docker pnpm named-volume complexity unless validated separately.
- Wrapper command names must avoid collisions between Docker image builds and frontend asset builds.
- OpenCode examples stay disabled by default and should not double-register skill directories.

## Non-Goals

- Do not depend on Laravel Sail.
- Do not support MSSQL in the first version.
- Do not include Typesense in the first version.
- Do not include Azurite.
- Do not include app-specific setup such as Passport keys, seeders, or Nexus-specific services.
- Do not create active per-user agent config with secrets or OAuth data.

## Distribution Model

Reference packages for repo shape and installer behavior:

- `laravel/sail` for dev-dependency installation, generated Docker/wrapper assets, and Laravel package auto-discovery.
- `laravel/boost` for agent-facing install/update flows, selected-feature prompts, persisted generated guidance config, and careful local/debug gating.
- `laravel/installer` for fresh-app creation ergonomics, package-manager detection, and agent-aware non-interactive behavior.
- Testbench-based Laravel packages for package test structure and CI matrices across supported Laravel/PHP versions.

### Primary: Composer Dev Package

Install inside a Laravel project:

```sh
composer require --dev edgarsedov/agent-ready-installer
php artisan agent-ready:install
```

Why Composer first:

- Laravel projects always have Composer.
- The installer can inspect `composer.json`, `composer.lock`, PHP requirements, Laravel version, and existing app files.
- The installer can expose Artisan commands and publish stubs.
- This matches the broad shape of Sail: a dev dependency with an install command.

### Secondary: Starter Template

Later provide:

```sh
composer create-project edgarsedov/agent-ready-laravel my-app
```

The starter should be generated from the same installer output, not maintained as a divergent hand-edited template.

## Install Modes

### Fresh Laravel App

The user creates a Laravel app first, then runs the installer.

```sh
composer create-project laravel/laravel my-app
cd my-app
composer require --dev edgarsedov/agent-ready-installer
php artisan agent-ready:install
```

Defaults can be opinionated because there is little existing local setup to preserve.

### Existing Laravel App

The user runs the installer in an existing app.

```sh
cd existing-app
composer require --dev edgarsedov/agent-ready-installer
php artisan agent-ready:install
```

This mode must avoid clobbering existing files. When a target file exists, prefer one of:

- refuse and print the file path;
- write a `.agent-ready.new` candidate;
- support explicit `--force` only for generated files the user accepts replacing.

Existing-app mode is more complex and should follow the fresh-app path after the initial implementation.

Before existing-app mode is advertised, the installer must support:

- `--dry-run` with the exact file operations it would perform;
- conflict detection for every target file;
- refusal by default when a target exists;
- candidate output such as `.agent-ready.new` for conflicting files;
- explicit `--force` only for files generated and owned by the installer;
- no automatic overwrite of existing `AGENTS.md`, Compose files, `.env`, or tool config.

## Default Choices

Initial defaults:

- Runtime: FrankenPHP.
- Database: PostgreSQL.
- Cache: Valkey enabled by default, Redis-compatible and configurable/off if the user chooses.
- Mailpit: off unless selected.
- Networking: Traefik by default for worktree-friendly hostnames, with direct ports as fallback/diagnostics.
- Agent toolkit: on.
- Worktree lifecycle: on.
- JavaScript tooling: auto.
- Package manager: ask in fresh mode, detect in existing mode.
- PHP version: auto from `composer.json`; prompt when ambiguous.
- Laravel version: current app version in existing mode, Composer default/latest in fresh mode.

## Runtime Matrix

### Version 1

- `frankenphp`
- `pgsql`
- `valkey` by default, Redis-compatible and configurable
- `traefik`
- local worktree index

### Version 1.1

- `nginx-fpm`
- `mysql`

### Future

- optional `mailpit`
- optional S3-compatible local storage, likely MinIO or RustFS;
- optional Octane/FrankenPHP worker mode after the classic mode is proven.

## Stage Overview

### Stage 0: Installer Foundation

- Composer package skeleton.
- `agent-ready:install` command.
- Dry-run and conflict-safe file writer.
- Version pinning policy.
- Project slug and local index writer.

### Stage 1: V1 Runtime And Wrapper

- FrankenPHP classic mode.
- Shared PostgreSQL infrastructure with per-checkout databases.
- Shared Valkey default cache service with per-checkout prefixes.
- Sail-like `./local` wrapper.
- JavaScript host/docker selection.
- Exact Docker image tags pinned to patch-level versions.

### Stage 2: V1 Worktree And Traefik Layer

- Shared Traefik local stack.
- Hashless worktree IDs backed by a local index.
- Worktree `create/up/down/status/remove`.
- Worktree index page listing routes and state.
- Cleanup from persisted state only.

### Stage 3: V1 Agent Toolkit

- `AGENTS.md`.
- `AGENTS.local.example.md`.
- `.ai/skills`.
- `opencode.jsonc.example`.
- decision notes starter.

### Stage 4: V1.1 Runtime Matrix

- nginx/php-fpm runtime.
- MySQL database engine.
- Engine-specific readiness, grants, test DBs, identifier limits, and cleanup.

### Stage 5: Optional Services And Starter

- Optional Mailpit.
- Optional shared S3-compatible local storage with per-checkout buckets/prefixes.
- Starter template generated from installer output.

## PHP And Laravel Version Strategy

The installer should not hardcode Laravel 13 or PHP 8.4 forever.

### PHP Detection

Read PHP requirements from `composer.json`:

- `config.platform.php` if present;
- otherwise `require.php`;
- otherwise prompt.

Supported initial PHP image targets:

- `8.3`
- `8.4`
- `8.5`

Version resolution must map constraints to image tags deterministically. Examples:

- `^8.3` selects the highest supported installed target satisfying the constraint.
- `>=8.2` should not blindly select an unsupported future version.
- `8.3.0` normalizes to image target `8.3`.
- If `config.platform.php` conflicts with `require.php`, stop and ask rather than guessing.

If the app requests an unsupported PHP version, stop with a clear message or generate only generic non-runtime agent files.

### Laravel Detection

Read Laravel version from:

- `composer.lock` package `laravel/framework`, if present;
- otherwise `composer.json` requirement;
- otherwise `php artisan --version` when dependencies are installed.

Avoid Laravel-version-specific app code in generated stubs where possible. Runtime config should mostly be Docker, env, and wrapper scripts.

## Version Pinning

Generated runtime files should pin versions to patch-level tags wherever the upstream image or package supports it.

Rules:

- Docker images use exact patch tags, not floating major/minor tags.
- If an exact patch tag is unavailable for an image, prefer digest pinning or stop and ask.
- PHP runtime image tags should include exact PHP/runtime versions when available.
- Node images should pin exact patch versions.
- PostgreSQL, Valkey, Traefik, nginx, and MySQL images should pin exact patch versions.
- Composer/npm/pnpm package versions generated by the installer should be explicit.
- Provide an update command or documented Renovate/Dependabot config later so pinned versions do not silently rot.

Example shape, not final versions:

```yaml
image: postgres:17.6-bookworm
image: valkey/valkey:8.1.3-bookworm
image: traefik:v3.5.3
```

The installer package itself may ship a compatibility manifest that maps Laravel/PHP selections to tested image tags.

## Command Wrapper

Generate a project-local wrapper named `./local`.

This is Sail-inspired command forwarding without Sail branding or Sail dependency.

Examples:

```sh
./local up -d
./local down
./local restart
./local ps
./local logs
./local php -v
./local artisan migrate
./local a tinker
./local composer install
./local test
./local pest
./local shell
./local root-shell
./local node --version
./local npm install
./local pnpm install
./local dev
./local build
./local assets build
./local mcp boost
./local worktree create ../my-app-feature --branch feature/foo
./local worktree status
./local worktree remove --force
```

### Command Mapping

- `up|down|stop|restart|ps|logs`: Docker Compose app stack commands.
- `build`: Sail-like Docker image build.
- `image build`: optional explicit alias for Docker image build.
- `assets build`: build frontend assets through the chosen JavaScript mode.
- `php`: app container PHP.
- `artisan|a`: `php artisan` in the app container.
- `composer`: Composer in the app container.
- `test`: `php artisan test` in the app container.
- `pest`: `vendor/bin/pest` in the app container.
- `shell`: shell as the app user.
- `root-shell`: shell as root.
- `node|npm|pnpm`: host or Docker depending on JavaScript mode.
- `dev`: start Vite through the chosen JavaScript mode.
- `mcp boost`: no-TTY Laravel Boost MCP command.
- `worktree`: delegate to worktree lifecycle script.

Unknown commands should not be blindly forwarded. Prefer explicit mappings and a documented escape hatch:

```sh
./local exec app -- php -i
./local compose -- config
./local build --no-cache
```

### MCP Requirements

`./local mcp boost` must avoid TTY allocation. Shape:

```sh
docker compose run --rm -T --no-deps app php artisan boost:mcp
```

If the app container must be running, document that. Prefer `run --rm --no-deps` when possible so OpenCode can spawn the MCP process without depending on a long-running shell session.

The wrapper command is optional sugar. The generated `opencode.jsonc.example` may use an explicit Compose invocation instead if that is more reliable for the selected runtime.

## JavaScript Tooling Strategy

The installer should separate package-manager choice from execution location.

### Package Manager

Fresh-app mode:

- Ask: `npm` or `pnpm`.
- Default: `npm` for maximum Laravel ecosystem familiarity unless we intentionally choose pnpm-first for agent workflows.

Existing-app mode:

- Detect `pnpm-lock.yaml` or `packageManager` containing `pnpm`.
- Detect `package-lock.json` or `packageManager` containing `npm`.
- Detect `yarn.lock`, `bun.lock`, or `bun.lockb` and stop with a clear unsupported-package-manager message unless support has been added.
- If multiple lockfiles exist, stop and ask instead of guessing.
- Respect `packageManager` when present because Corepack uses it as the project-level tool version contract.
- Refuse to silently convert between npm and pnpm.

### Execution Location

Prompt:

```txt
Where should JavaScript tooling run?
1. Auto
2. Host
3. Docker
```

Auto behavior:

- If selected package manager and a compatible Node runtime are available on host, use host.
- Otherwise use Docker.

Reasoning:

- Host pnpm is fastest for multi-worktree agent workflows because pnpm can use a host-level global virtual store.
- Docker is more reproducible and does not require host Node.
- Docker Desktop bind-mounted file I/O can be slower on macOS/Windows.

### pnpm In Docker

Do not default to npm just because JavaScript tooling runs in Docker. Use the selected package manager.

For pnpm in Docker:

- use a dedicated Node/Vite service;
- enable Corepack;
- mount source code into the container;
- keep `node_modules` in a named Docker volume;
- put pnpm's store inside the same volume, such as `/var/www/html/node_modules/.pnpm-store`, to avoid cross-filesystem hardlink/copy penalties.

Tradeoff: host editors may not see `node_modules` when it lives in a Docker volume. Document this and recommend host JS mode for editor-heavy TypeScript projects.

Because this has editor and worktree bootstrap tradeoffs, V1 should either:

- default Docker pnpm to bind-mounted `node_modules` and accept slower installs; or
- mark Docker pnpm volume mode experimental until validated.

Do not combine Docker volume `node_modules` with a host copy-forward optimization. Those are incompatible.

### pnpm On Host

For trusted local worktrees, optionally document `enableGlobalVirtualStore: true` in `pnpm-workspace.yaml`.

Do not enable it automatically in existing projects without asking because it changes repository configuration and assumes one trust boundary across local worktrees and agents.

Do not copy `node_modules` for host pnpm worktrees by default. With pnpm, the useful reuse point is the content-addressable/global virtual store; copying `node_modules` mostly copies symlink forests and can be slower or misleading.

### npm Warm Starts

For npm, copying `node_modules` from the source checkout can be a useful local bootstrap optimization even when the lockfile changed. `npm install` reconciles the target checkout after the copy by adding, removing, or updating packages as needed.

Rules:

- copy only between npm-managed checkouts;
- copy when source `node_modules` exists and the target does not, unless the user opts out;
- never symlink `node_modules` between worktrees;
- after copying, run `npm install` so the target checkout reconciles its own install metadata;
- skip copy when running JS tooling entirely in a Docker named volume, because host `node_modules` is not the same target filesystem.

Do not use `npm ci` as the local worktree default after copying because it removes `node_modules` first. `npm ci` remains useful for CI/CD and explicit reproducibility checks, not for the speed-oriented local warm-start path.

## Generated Files

Likely generated structure:

```txt
./local
scripts/local.sh
scripts/lib.sh
scripts/bootstrap.sh
scripts/status.sh
scripts/worktree.sh
docker-compose.yml
docker-compose.traefik.yml
docker/
  frankenphp/
    Dockerfile
    Caddyfile
  traefik/
    docker-compose.yml
    dynamic/
    index/
AGENTS.md
AGENTS.local.example.md
opencode.jsonc.example
.ai/README.md
.ai/skills/local-development/SKILL.md
.ai/skills/worktree-lifecycle/SKILL.md
docs/decision-notes/README.md
docs/decision-notes/local-development-stack.md
```

Future runtime files such as `docker/nginx/` and `docker/php-fpm/` should be generated only when the corresponding feature is selected and implemented.

Generated ignored/local paths:

```txt
.env
AGENTS.local.md
opencode.jsonc
.mcp.json
.agent-ready/
.agents/skills/
auth.json
vendor/
node_modules/
```

## Agent Guidance

### AGENTS.md

Tracked shared guidance. Keep it concise and operational:

- use `./local` as the command source of truth;
- inspect `AGENTS.local.md` when present;
- use generated worktree commands instead of plain `git worktree`;
- do not hand-delete Docker resources;
- do not edit generated identity values in `.env`; rerun the wrapper/bootstrap so `.env` is regenerated from `.agent-ready/worktree.json`;
- after infra changes run `./local bootstrap`, `./local status`, and relevant smoke checks.

### AGENTS.local.example.md

Tracked template for local machine notes:

- selected JS mode;
- package manager;
- enabled services;
- local URLs;
- local command preferences;
- editor/tooling caveats.

`AGENTS.local.md` is ignored and can be symlinked from the main checkout into managed worktrees.

### .ai/skills

Tracked team-owned skill source:

- `local-development`: using `./local`, selected services, JS mode, validation commands.
- `worktree-lifecycle`: creating, starting, stopping, inspecting, and removing managed worktrees.

Activation/generated directories such as `.agents/skills` stay ignored.

### opencode.jsonc.example

Ship an example, not active config. It must be schema-valid for OpenCode.

Example shape:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "AGENTS.md",
    "AGENTS.local.md"
  ],
  "skills": {
    "paths": [
      ".ai/skills"
    ]
  },
  "mcp": {
    "laravel-boost": {
      "type": "local",
      "enabled": false,
      "command": [
        "./local",
        "mcp",
        "boost"
      ]
    }
  }
}
```

## Worktree Lifecycle

Use Nexus' core idea: persisted lifecycle state is the source of truth. Do not re-derive cleanup identity from the current path once a checkout has been initialized.

## Project Identity

The installer must derive and persist a project slug before generating Docker, database, network, or route names.

Rules:

- default from Composer package name or directory name;
- normalize to lowercase ASCII slug;
- use hashless checkout/worktree IDs by default;
- enforce uniqueness through the local index and refuse collisions rather than silently appending hashes;
- allow an explicit `--id <id>` when the default branch-derived ID collides;
- bound database identifiers to engine limits;
- refuse or prompt on collisions with existing managed state;
- persist final values in `.agent-ready/worktree.json` and project state so later cleanup does not depend on the current folder name.

Do not hardcode template-specific values such as `agent-ready-laravel` in generated packages.

Persist state under:

```txt
.agent-ready/worktree.json
```

Potential state shape:

```json
{
  "version": 1,
  "root": "/path/to/worktree",
  "mainWorktree": "/path/to/main",
  "checkoutId": "feature-foo",
  "composeProject": "my_app_feature_foo",
  "runtime": "frankenphp",
  "databaseEngine": "pgsql",
  "appDatabase": "my_app__feature_foo",
  "testDatabase": "my_app__feature_foo_test",
  "cachePrefix": "my_app_feature_foo:",
  "traefikResourcePrefix": "my-app-feature-foo",
  "packageManager": "pnpm",
  "jsRuntime": "docker",
  "services": ["pgsql", "valkey", "traefik"]
}
```

### Local Index

The main checkout owns a local, ignored index such as:

```txt
.agent-ready/index.json
```

The index maps hashless checkout IDs to paths and routes:

```json
{
  "version": 1,
  "projectSlug": "my-app",
  "domainRoot": "my-app.localhost",
  "checkouts": {
    "main": {
      "path": "/path/to/my-app",
      "branch": "main",
      "appHost": "my-app.localhost",
      "viteHost": "vite.my-app.localhost"
    },
    "feature-foo": {
      "path": "/path/to/my-app-wt/feature-foo",
      "branch": "feature/foo",
      "appHost": "feature-foo.my-app.localhost",
      "viteHost": "vite-feature-foo.my-app.localhost"
    }
  }
}
```

If `feature-foo` already exists, creation must stop and ask for a different ID. Do not add a hash automatically.

The index page should render this registry so a developer can open one local URL and see all managed checkouts, routes, branches, and container status.

### Commands

```sh
./local worktree create ../my-app-feature --branch feature/foo
./local worktree create ../my-app-feature --branch feature/foo --base main
./local worktree up
./local worktree down
./local worktree status
./local worktree remove
./local worktree remove --force
```

### Safety Rules

- Refuse to remove the main checkout.
- Refuse to remove dirty tracked or untracked worktrees unless `--force` is passed.
- Do not remove shared services by default.
- Do not remove volumes by default.
- Use persisted state for cleanup targets.
- Write state atomically and validate the state schema before destructive operations.
- Use a lock file around create/remove so parallel agents do not race on state or port allocation.
- Canonicalize and persist the original root path, but do not recompute Docker/database identity if the directory is moved.
- If state is missing but `.env` looks like a managed worktree, refuse destructive cleanup.
- Roll back branch/worktree creation if provisioning fails.

## Database Strategy

Version 1 supports shared PostgreSQL infrastructure. MySQL follows after the installer has engine-specific readiness checks, database creation, grants, identifier length handling, and cleanup semantics.

For worktrees:

- keep database containers shared across all managed checkouts for resource efficiency;
- generate deterministic app and test database names;
- create both during bootstrap;
- isolate cache prefixes for Valkey/Redis;
- cleanup database namespaces only when explicit remove/cleanup commands are run and persisted state exists.

Shared infrastructure should stay running when an individual worktree is stopped or removed unless the user explicitly asks for shared teardown.

Per-checkout services should include the app runtime and Vite/frontend process. Optional services that are naturally namespaced, such as Mailpit, can be per-checkout until shared cleanup semantics are designed.

Future S3-compatible storage should prefer a shared service with per-checkout buckets or prefixes, but only after bucket cleanup and public URL behavior are specified.

Do not include Mailpit in the default setup. If selected, treat it as an optional service and route it only when present.

## Traefik Strategy

Use shared Traefik by default for managed worktrees:

- app and Vite route labels for Docker-hosted services;
- optional dynamic file-provider routes only for host-run Vite if needed;
- generated hostnames should be one label under the configured local domain because wildcard certificates match one label.
- a local index route should list managed checkouts and links.

Direct exposed ports remain a fallback/diagnostic mode. The main worktree experience should assume Traefik so multiple checkouts can be opened in the browser without port juggling.

## Installer UX

Interactive prompts should have sensible defaults and all choices should have CLI flags for automation.

Example:

```sh
php artisan agent-ready:install \
  --runtime=frankenphp \
  --db=pgsql \
  --cache=valkey \
  --without=mailpit \
  --js=auto \
  --pm=pnpm \
  --php=auto \
  --agents \
  --worktrees
```

Potential flags:

- `--runtime=frankenphp`
- `--db=pgsql`
- `--cache=valkey|redis|none`
- `--with=mailpit,minio`
- `--without=mailpit`
- `--js=auto|host|docker`
- `--pm=auto|npm|pnpm`
- `--php=auto|8.3|8.4|8.5`
- `--traefik|--no-traefik`
- `--agents|--no-agents`
- `--worktrees|--no-worktrees`
- `--force`
- `--dry-run`

## Implementation Phases

Use the stage overview above as the implementation order:

- Stage 0: installer safety, dry-run, conflict handling, version pinning, project identity, local index foundation.
- Stage 1: FrankenPHP, PostgreSQL, Valkey, `./local`, JavaScript mode selection, pinned runtime files.
- Stage 2: Traefik, hashless worktree IDs, worktree index page, lifecycle commands, cleanup from persisted state.
- Stage 3: agent toolkit files and OpenCode example.
- Stage 4: nginx/php-fpm and MySQL.
- Stage 5: optional Mailpit, optional S3-compatible storage, starter template, docs and smoke-test matrix.

## Open Questions

- Should fresh projects default to `npm` for Laravel familiarity or `pnpm` for agent/worktree performance?
- Should `./local` be the final wrapper name, or should it be `./dev`, `./agent`, or another name?
- Should generated worktrees live beside the repo, under `.worktrees/`, or be user-selected only?
- Should Docker JS mode use a named `node_modules` volume by default, despite host editor limitations?
- Should MinIO or RustFS be the future S3-compatible service?
- How much should existing-app mode patch `.env` automatically versus write suggested values only?

## Main Risks

- Existing-app installation can clobber user files if conflict handling is not conservative.
- Docker pnpm mode can be slow or editor-hostile if volumes are chosen poorly.
- Host pnpm mode is fast but assumes host Node/pnpm and a shared trust boundary.
- Worktree cleanup can destroy useful local state if dirty-checks and persisted-state guards are weak.
- Supporting too many service combinations too early will delay a usable version.
- OpenCode and Boost config formats can change; examples must stay schema-valid and optional.
