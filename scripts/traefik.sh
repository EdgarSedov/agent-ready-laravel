#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

command_name="${1:-}"

if [[ -z "${command_name}" ]]; then
    fail "usage: ./scripts/traefik.sh <ensure|prune|register-vite|unregister-vite>"
fi

shift || true

shared_root="$(shared_traefik_root)"

if [[ ! -d "${shared_root}" ]]; then
    fail "shared-traefik repo not found at ${shared_root}; set SHARED_TRAEFIK_PATH if needed"
fi

env_file="${REPO_ROOT}/.env"
resolved_checkout_slug="$(resolve_env_var "${env_file}" "CHECKOUT_SLUG" "$(checkout_slug)")"
resolved_vite_domain="$(resolve_env_var "${env_file}" "VITE_DOMAIN" "$(vite_domain)")"
resolved_vite_port="$(resolve_env_var "${env_file}" "VITE_PORT" "$(default_vite_port)")"
resolved_route_id="$(vite_route_id)"
repo_path="$(detect_primary_checkout_root)"

case "${command_name}" in
    ensure)
        "${shared_root}/bin/ensure" "$@"
        ;;
    register-vite)
        # AGENT_READY_OPTIONAL_HOST_VITE:
        # This host-route flow is optional and only needed when Vite runs on the
        # host instead of being routed directly to the container with Docker labels.
        "${shared_root}/bin/register-host-route" \
            --id "${resolved_route_id}" \
            --hostname "${resolved_vite_domain}" \
            --target-port "${resolved_vite_port}" \
            --owner-path "${REPO_ROOT}" \
            --repo-path "${repo_path}" \
            --checkout-slug "${resolved_checkout_slug}" \
            "$@"
        ;;
    unregister-vite)
        # AGENT_READY_OPTIONAL_HOST_VITE: paired cleanup for the optional
        # host-run Vite workflow.
        "${shared_root}/bin/unregister" --id "${resolved_route_id}" "$@"
        ;;
    prune)
        "${shared_root}/bin/prune" "$@"
        ;;
    *)
        fail "unknown traefik subcommand: ${command_name}"
        ;;
esac
