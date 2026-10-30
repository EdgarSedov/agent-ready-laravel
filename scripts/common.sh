#!/usr/bin/env bash

set -euo pipefail

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${COMMON_DIR}/.." && pwd)"

readonly COMMON_DIR
readonly REPO_ROOT
readonly APP_SLUG="agent-ready-laravel"
readonly APP_DB_PREFIX="agent_ready_laravel"
readonly LOCAL_DOMAIN_ROOT="app.localhost"
readonly SHARED_SERVICES_PROJECT="agent-ready-laravel-shared"

log() {
    printf '[agent-ready-laravel] %s\n' "$*" >&2
}

warn() {
    printf '[agent-ready-laravel] warning: %s\n' "$*" >&2
}

fail() {
    printf '[agent-ready-laravel] error: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

copy_if_missing() {
    local source_path="$1"
    local target_path="$2"

    if [[ -f "${source_path}" && ! -e "${target_path}" ]]; then
        mkdir -p "$(dirname "${target_path}")"
        cp "${source_path}" "${target_path}"
    fi
}

hash_file() {
    sha256sum "$1" | cut -d' ' -f1
}

normalize_path() {
    local base_path="$1"
    local target_path="$2"

    python3 - "${base_path}" "${target_path}" <<'PY'
from pathlib import Path
import sys

base = Path(sys.argv[1])
target = Path(sys.argv[2])

if not target.is_absolute():
    target = base / target

print(target.resolve())
PY
}

relative_path() {
    local base_path="$1"
    local target_path="$2"

    python3 - "${base_path}" "${target_path}" <<'PY'
from pathlib import Path
import os
import sys

base = Path(sys.argv[1]).resolve()
target = Path(sys.argv[2]).resolve()
print(os.path.relpath(target, base))
PY
}

same_lock() {
    local left="$1"
    local right="$2"

    [[ -f "${left}" && -f "${right}" ]] || return 1
    [[ "$(hash_file "${left}")" == "$(hash_file "${right}")" ]]
}

read_env_var() {
    local env_file="$1"
    local key="$2"

    python3 - "${env_file}" "${key}" <<'PY'
import pathlib
import sys

env_path = pathlib.Path(sys.argv[1])
key = sys.argv[2]

if not env_path.exists():
    sys.exit(0)

for line in env_path.read_text(encoding="utf-8").splitlines():
    stripped = line.strip()
    if not stripped or stripped.startswith("#") or "=" not in line:
        continue
    candidate_key, candidate_value = line.split("=", 1)
    if candidate_key == key:
        if len(candidate_value) >= 2 and candidate_value[0] == '"' and candidate_value[-1] == '"':
            candidate_value = candidate_value[1:-1]
        print(candidate_value)
        break
PY
}

resolve_env_var() {
    local env_file="$1"
    local key="$2"
    local fallback="$3"
    local value

    value="$(read_env_var "${env_file}" "${key}")"
    if [[ -n "${value}" ]]; then
        printf '%s\n' "${value}"
    else
        printf '%s\n' "${fallback}"
    fi
}

upsert_env_var() {
    local env_file="$1"
    local key="$2"
    local value="$3"

    python3 - "${env_file}" "${key}" "${value}" <<'PY'
import pathlib
import sys

env_path = pathlib.Path(sys.argv[1])
key = sys.argv[2]
value = sys.argv[3]
line_value = f'{key}={value}'

lines = []
if env_path.exists():
    lines = env_path.read_text(encoding="utf-8").splitlines()

updated = False
for index, line in enumerate(lines):
    if line.startswith(f"{key}="):
        lines[index] = line_value
        updated = True
        break

if not updated:
    lines.append(line_value)

env_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

remove_env_var() {
    local env_file="$1"
    local key="$2"

    python3 - "${env_file}" "${key}" <<'PY'
import pathlib
import sys

env_path = pathlib.Path(sys.argv[1])
key = sys.argv[2]

if not env_path.exists():
    sys.exit(0)

lines = [line for line in env_path.read_text(encoding="utf-8").splitlines() if not line.startswith(f"{key}=")]
env_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

slugify() {
    python3 - "$1" <<'PY'
import re
import sys

value = sys.argv[1].strip().lower()
value = re.sub(r"[^a-z0-9]+", "-", value)
value = value.strip("-")
print(value or "checkout")
PY
}

path_hash() {
    python3 - "$1" <<'PY'
import hashlib
import os
import sys

value = os.path.realpath(sys.argv[1]).encode("utf-8")
print(hashlib.sha256(value).hexdigest()[:6])
PY
}

is_main_checkout() {
    [[ "$(basename "${REPO_ROOT}")" == "${APP_SLUG}" ]]
}

checkout_slug() {
    if is_main_checkout; then
        printf '%s\n' "${APP_SLUG}"
    else
        slugify "$(basename "${REPO_ROOT}")"
    fi
}

checkout_id() {
    if is_main_checkout; then
        printf 'main\n'
    else
        printf '%s-%s\n' "$(checkout_slug)" "$(path_hash "${REPO_ROOT}")"
    fi
}

compose_project_name() {
    if is_main_checkout; then
        printf '%s\n' "${APP_SLUG}"
    else
        printf '%s-%s-%s\n' "${APP_SLUG}" "$(checkout_slug)" "$(path_hash "${REPO_ROOT}")"
    fi
}

app_domain() {
    if is_main_checkout; then
        printf '%s\n' "${LOCAL_DOMAIN_ROOT}"
    else
        printf '%s.%s\n' "$(checkout_slug)" "${LOCAL_DOMAIN_ROOT}"
    fi
}

vite_domain() {
    if is_main_checkout; then
        printf 'vite.%s\n' "${LOCAL_DOMAIN_ROOT}"
    else
        printf '%s-vite.%s\n' "$(checkout_slug)" "${LOCAL_DOMAIN_ROOT}"
    fi
}

database_name() {
    if is_main_checkout; then
        printf '%s\n' "${APP_DB_PREFIX}"
    else
        printf '%s__%s\n' "${APP_DB_PREFIX}" "$(checkout_slug | tr '-' '_')"
    fi
}

test_database_name() {
    printf '%s_test\n' "$(database_name)"
}

detect_primary_checkout_root() {
    local first_path

    first_path="$(git -C "${REPO_ROOT}" worktree list --porcelain 2>/dev/null | awk '/^worktree / { print $2; exit }')"
    if [[ -n "${first_path}" ]]; then
        printf '%s\n' "${first_path}"
    else
        printf '%s\n' "${REPO_ROOT}"
    fi
}

detect_source_repo_root() {
    if [[ -n "${SOURCE_REPO_ROOT:-}" ]]; then
        printf '%s\n' "${SOURCE_REPO_ROOT}"
        return 0
    fi

    local primary_root
    primary_root="$(detect_primary_checkout_root)"
    if [[ "${primary_root}" != "${REPO_ROOT}" ]]; then
        printf '%s\n' "${primary_root}"
    fi
}

canonical_checkout_root() {
    local source_root

    source_root="$(detect_source_repo_root)"
    if [[ -n "${source_root}" ]]; then
        printf '%s\n' "${source_root}"
    else
        printf '%s\n' "${REPO_ROOT}"
    fi
}

shared_traefik_root() {
    if [[ -n "${SHARED_TRAEFIK_PATH:-}" ]]; then
        normalize_path "$(canonical_checkout_root)" "${SHARED_TRAEFIK_PATH}"
    else
        printf '%s/shared-traefik\n' "$(dirname "$(canonical_checkout_root)")"
    fi
}

bootstrap_state_dir() {
    printf '%s/.bootstrap\n' "${REPO_ROOT}"
}

lock_state_file() {
    printf '%s/%s.sha256\n' "$(bootstrap_state_dir)" "$1"
}

ensure_bootstrap_state_dir() {
    mkdir -p "$(bootstrap_state_dir)"
}

lock_state_matches() {
    local lock_file="$1"
    local state_key="$2"
    local state_file

    state_file="$(lock_state_file "${state_key}")"

    [[ -f "${lock_file}" && -f "${state_file}" ]] || return 1
    [[ "$(hash_file "${lock_file}")" == "$(<"${state_file}")" ]]
}

write_lock_state() {
    local lock_file="$1"
    local state_key="$2"

    ensure_bootstrap_state_dir
    printf '%s\n' "$(hash_file "${lock_file}")" >"$(lock_state_file "${state_key}")"
}

ensure_env_file() {
    local source_root="${1:-}"

    if [[ -f "${REPO_ROOT}/.env" ]]; then
        return 0
    fi

    if [[ -n "${source_root}" && -f "${source_root}/.env" ]]; then
        cp "${source_root}/.env" "${REPO_ROOT}/.env"
        log "seeded .env from ${source_root}"
        return 0
    fi

    cp "${REPO_ROOT}/.env.example" "${REPO_ROOT}/.env"
    log "seeded .env from .env.example"
}

ensure_local_ai_targets() {
    local skill_dir skill_name target_path relative_target

    mkdir -p \
        "${REPO_ROOT}/.agents/skills"

    for skill_dir in "${REPO_ROOT}/.ai/skills"/*; do
        [[ -d "${skill_dir}" ]] || continue

        skill_name="$(basename "${skill_dir}")"
        target_path="${REPO_ROOT}/.agents/skills/${skill_name}"
        relative_target="$(relative_path "$(dirname "${target_path}")" "${skill_dir}")"

        if [[ -L "${target_path}" ]]; then
            ln -sfn "${relative_target}" "${target_path}"
        elif [[ ! -e "${target_path}" ]]; then
            ln -s "${relative_target}" "${target_path}"
        fi
    done
}

link_local_files_from_source() {
    local source_root="$1"
    local file_name source_path target_path relative_target

    [[ -n "${source_root}" && "${source_root}" != "${REPO_ROOT}" ]] || return 0

    for file_name in AGENTS.local.md auth.json opencode.jsonc .mcp.json; do
        source_path="${source_root}/${file_name}"
        target_path="${REPO_ROOT}/${file_name}"

        [[ -e "${source_path}" || -L "${source_path}" ]] || continue
        [[ ! -e "${target_path}" && ! -L "${target_path}" ]] || continue

        relative_target="$(relative_path "$(dirname "${target_path}")" "${source_path}")"
        ln -s "${relative_target}" "${target_path}"
        log "linked ${file_name} from ${source_root}"
    done
}

ensure_shared_services_network() {
    local network_name
    network_name="$(resolve_env_var "${REPO_ROOT}/.env" "SHARED_SERVICES_NETWORK" "agent-ready-laravel-shared")"

    if docker network inspect "${network_name}" >/dev/null 2>&1; then
        return 0
    fi

    docker network create "${network_name}" >/dev/null
    log "created Docker network ${network_name}"
}

compose() {
    (cd "${REPO_ROOT}" && docker compose --file docker-compose.yml --file docker-compose.traefik.yml "$@")
}

run_app() {
    compose run --rm --no-deps app "$@"
}

run_node() {
    compose run --rm --no-deps vite "$@"
}

shared_compose() {
    local shared_root

    shared_root="$(canonical_checkout_root)"
    (cd "${shared_root}" && docker compose --profile shared --project-name "${SHARED_SERVICES_PROJECT}" --file docker-compose.yml "$@")
}

wait_for_shared_postgres() {
    local db_user
    local attempts="${1:-20}"
    local delay_seconds="${2:-3}"
    local try=1

    db_user="$(resolve_env_var "${REPO_ROOT}/.env" "DB_USERNAME" "sail")"

    until shared_compose exec -T pgsql psql -U "${db_user}" -d postgres -c 'select 1' >/dev/null 2>&1; do
        if [[ ${try} -ge ${attempts} ]]; then
            fail "Postgres did not become ready"
        fi

        warn "waiting for shared Postgres (${try}/${attempts})"
        sleep "${delay_seconds}"
        try=$((try + 1))
    done
}

run_composer() {
    run_app composer "$@"
}

ensure_vendor_from_source_or_install() {
    local source_root="${1:-}"

    if [[ -d "${REPO_ROOT}/vendor" ]] && lock_state_matches "${REPO_ROOT}/composer.lock" "composer.lock"; then
        return 0
    fi

    if [[ -d "${REPO_ROOT}/vendor" ]]; then
        rm -rf "${REPO_ROOT}/vendor"
    fi

    if [[ -n "${source_root}" && -d "${source_root}/vendor" ]] && same_lock "${source_root}/composer.lock" "${REPO_ROOT}/composer.lock"; then
        log "copying vendor/ from ${source_root}"
        cp -R "${source_root}/vendor" "${REPO_ROOT}/vendor"
        write_lock_state "${REPO_ROOT}/composer.lock" "composer.lock"
        return 0
    fi

    log "installing Composer dependencies"
    (cd "${REPO_ROOT}" && run_composer install --no-interaction)
    write_lock_state "${REPO_ROOT}/composer.lock" "composer.lock"
}

ensure_node_modules_from_source_or_install() {
    local source_root="${1:-}"

    if [[ -d "${REPO_ROOT}/node_modules" ]] && lock_state_matches "${REPO_ROOT}/package-lock.json" "package-lock.json"; then
        return 0
    fi

    if [[ -d "${REPO_ROOT}/node_modules" ]]; then
        rm -rf "${REPO_ROOT}/node_modules"
    fi

    if [[ -n "${source_root}" && -d "${source_root}/node_modules" ]] && same_lock "${source_root}/package-lock.json" "${REPO_ROOT}/package-lock.json"; then
        log "copying node_modules/ from ${source_root}"
        cp -R "${source_root}/node_modules" "${REPO_ROOT}/node_modules"
        write_lock_state "${REPO_ROOT}/package-lock.json" "package-lock.json"
        return 0
    fi

    log "installing Node dependencies through Vite service"
    run_node npm install
    write_lock_state "${REPO_ROOT}/package-lock.json" "package-lock.json"
}

ensure_database_exists() {
    local database_name="$1"
    local db_user

    db_user="$(resolve_env_var "${REPO_ROOT}/.env" "DB_USERNAME" "sail")"

    if shared_compose exec -T pgsql psql -U "${db_user}" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${database_name}'" | grep -q 1; then
        return 0
    fi

    shared_compose exec -T pgsql psql -U "${db_user}" -d postgres -c "CREATE DATABASE \"${database_name}\";" >/dev/null
    log "created database ${database_name}"
}

retry_app_artisan() {
    local attempts="$1"
    local delay_seconds="$2"
    local try=1
    shift 2

    until run_app php artisan "$@"; do
        if [[ ${try} -ge ${attempts} ]]; then
            return 1
        fi

        warn "retrying artisan $* (${try}/${attempts})"
        sleep "${delay_seconds}"
        try=$((try + 1))
    done
}
