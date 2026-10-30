#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

require_command docker
require_command git

env_file="${REPO_ROOT}/.env"
project_name="$(resolve_env_var "${env_file}" "COMPOSE_PROJECT_NAME" "$(compose_project_name)")"

printf 'checkout\n'
printf '  path:       %s\n' "${REPO_ROOT}"
printf '  branch:     %s\n' "$(git -C "${REPO_ROOT}" branch --show-current 2>/dev/null || true)"
printf '  dirty:      '
if [[ -n "$(git -C "${REPO_ROOT}" status --short)" ]]; then
    printf 'yes\n'
else
    printf 'no\n'
fi

printf '\nidentity\n'
printf '  checkout:   %s\n' "$(checkout_id)"
printf '  project:    %s\n' "${project_name}"
printf '  app:        https://%s\n' "$(resolve_env_var "${env_file}" "APP_DOMAIN" "$(app_domain)")"
printf '  vite:       https://%s\n' "$(resolve_env_var "${env_file}" "VITE_DOMAIN" "$(vite_domain)")"
printf '  database:   %s\n' "$(resolve_env_var "${env_file}" "DB_DATABASE" "$(database_name)")"
printf '  test db:    %s\n' "$(resolve_env_var "${env_file}" "DB_TEST_DATABASE" "$(test_database_name)")"

printf '\nworktrees\n'
git -C "${REPO_ROOT}" worktree list

printf '\napp compose\n'
compose ps --all || true

printf '\nshared services\n'
shared_compose ps --all || true


printf '\ntraefik\n'
shared_root="$(shared_traefik_root)"
if [[ -x "${shared_root}/bin/status" ]]; then
    "${shared_root}/bin/status" || true
else
    printf '  shared-traefik status unavailable at %s\n' "${shared_root}"
fi

printf '\ndocker resources\n'
printf '  networks:\n'
docker network ls --filter "name=${APP_SLUG}" --format '    {{.Name}}'
printf '  containers:\n'
docker ps --all --filter "label=com.docker.compose.project=${project_name}" --format '    {{.Names}} {{.Status}}'
printf '  volumes:\n'
docker volume ls --filter "name=${APP_SLUG}" --format '    {{.Name}}'
