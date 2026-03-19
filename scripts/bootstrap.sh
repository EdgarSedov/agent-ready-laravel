#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

skip_deps=0
skip_migrate=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-deps)
            skip_deps=1
            shift
            ;;
        --skip-migrate)
            skip_migrate=1
            shift
            ;;
        --help)
            cat <<'EOF'
Usage: ./scripts/bootstrap.sh [--skip-deps] [--skip-migrate]

Bootstraps the current checkout with shared Traefik and shared services.
EOF
            exit 0
            ;;
        *)
            fail "unknown argument: $1"
            ;;
    esac
done

require_command docker
require_command git

source_root="$(detect_source_repo_root)"
ensure_env_file "${source_root}"
ensure_local_ai_targets
if [[ -n "${source_root}" ]]; then
    copy_if_missing "${source_root}/AGENTS.local.md" "${REPO_ROOT}/AGENTS.local.md"
fi

env_file="${REPO_ROOT}/.env"
hash_value="$(path_hash "${REPO_ROOT}")"
resolved_checkout_slug="$(checkout_slug)"
resolved_checkout_id="$(checkout_id)"
resolved_compose_project_name="$(compose_project_name)"
seed_checkout_slug="$(read_env_var "${env_file}" "CHECKOUT_SLUG")"
seed_checkout_id="$(read_env_var "${env_file}" "CHECKOUT_ID")"
vite_port="$(resolve_env_var "${env_file}" "VITE_PORT" "$(default_vite_port)")"

if [[ "${seed_checkout_slug}" != "${resolved_checkout_slug}" || "${seed_checkout_id}" != "${resolved_checkout_id}" ]]; then
    vite_port="$(default_vite_port)"
fi

upsert_env_var "${env_file}" "APP_SLUG" "${APP_SLUG}"
upsert_env_var "${env_file}" "CHECKOUT_SLUG" "${resolved_checkout_slug}"
upsert_env_var "${env_file}" "CHECKOUT_ID" "${resolved_checkout_id}"
upsert_env_var "${env_file}" "COMPOSE_PROJECT_NAME" "${resolved_compose_project_name}"
upsert_env_var "${env_file}" "APP_DOMAIN" "$(app_domain)"
upsert_env_var "${env_file}" "VITE_DOMAIN" "$(vite_domain)"
upsert_env_var "${env_file}" "APP_URL" "https://$(app_domain)"
upsert_env_var "${env_file}" "VITE_PORT" "${vite_port}"
upsert_env_var "${env_file}" "DB_CONNECTION" "pgsql"
upsert_env_var "${env_file}" "DB_HOST" "pgsql"
upsert_env_var "${env_file}" "DB_PORT" "5432"
upsert_env_var "${env_file}" "DB_DATABASE" "$(database_name)"
upsert_env_var "${env_file}" "DB_TEST_DATABASE" "$(test_database_name)"
upsert_env_var "${env_file}" "DB_USERNAME" "sail"
upsert_env_var "${env_file}" "DB_PASSWORD" "password"
upsert_env_var "${env_file}" "REDIS_HOST" "redis"
upsert_env_var "${env_file}" "REDIS_PORT" "6379"
upsert_env_var "${env_file}" "MAIL_MAILER" "smtp"
upsert_env_var "${env_file}" "MAIL_HOST" "mailpit"
upsert_env_var "${env_file}" "MAIL_PORT" "1025"
upsert_env_var "${env_file}" "SHARED_SERVICES_NETWORK" "agent-ready-laravel-shared"
upsert_env_var "${env_file}" "SHARED_PGSQL_CONTAINER" "agent-ready-laravel-pgsql"
upsert_env_var "${env_file}" "SHARED_REDIS_CONTAINER" "agent-ready-laravel-redis"
upsert_env_var "${env_file}" "SHARED_MAILPIT_CONTAINER" "agent-ready-laravel-mailpit"
upsert_env_var "${env_file}" "FORWARD_DB_PORT" "54320"
upsert_env_var "${env_file}" "FORWARD_REDIS_PORT" "63790"
upsert_env_var "${env_file}" "FORWARD_MAILPIT_SMTP_PORT" "10250"
upsert_env_var "${env_file}" "FORWARD_MAILPIT_DASHBOARD_PORT" "8025"
upsert_env_var "${env_file}" "WWWUSER" "$(id -u)"
upsert_env_var "${env_file}" "WWWGROUP" "$(id -g)"
remove_env_var "${env_file}" "APP_PORT"
remove_env_var "${env_file}" "LOCAL_APP_URL"
remove_env_var "${env_file}" "LOCAL_VITE_URL"
remove_env_var "${env_file}" "VITE_PROXY_HTTPS"

if [[ ${skip_deps} -eq 0 ]]; then
    ensure_vendor_from_source_or_install "${source_root}"
fi

ensure_shared_services_network
shared_compose up -d pgsql redis mailpit
wait_for_shared_postgres
"${REPO_ROOT}/scripts/traefik.sh" ensure
run_sail_with_compose "docker-compose.yml:docker-compose.traefik.yml" up -d laravel.test

if [[ ${skip_deps} -eq 0 ]]; then
    ensure_node_modules_from_source_or_install "${source_root}"
fi

ensure_database_exists "$(database_name)"
ensure_database_exists "$(test_database_name)"

if [[ -z "$(read_env_var "${env_file}" "APP_KEY")" ]]; then
    retry_sail_artisan 5 3 key:generate --force
fi

if [[ ${skip_migrate} -eq 0 ]]; then
    retry_sail_artisan 5 3 migrate --graceful
fi

# AGENT_READY_OPTIONAL_HOST_VITE:
# Re-enable host-run Vite by publishing VITE_PORT in docker-compose.yml and
# calling ./scripts/traefik.sh register-vite here before opening the routed URL.

printf '\nCheckout ready\n'
printf '  checkout:    %s\n' "${REPO_ROOT}"
printf '  checkout id: %s\n' "$(checkout_id)"
printf '  app domain:  https://%s\n' "$(app_domain)"
printf '  vite domain: https://%s\n' "$(vite_domain)"
printf '  vite port:   %s (container)\n' "${vite_port}"
printf '  mailpit:     http://localhost:8025\n'
printf '  database:    %s\n' "$(database_name)"
printf '  test db:     %s\n' "$(test_database_name)"
printf '  path hash:   %s\n' "${hash_value}"
