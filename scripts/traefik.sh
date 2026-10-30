#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

command_name="${1:-}"

if [[ -z "${command_name}" ]]; then
    fail "usage: ./scripts/traefik.sh <ensure|prune>"
fi

shift || true

shared_root="$(shared_traefik_root)"

if [[ ! -d "${shared_root}" ]]; then
    fail "shared-traefik repo not found at ${shared_root}; set SHARED_TRAEFIK_PATH if needed"
fi

env_file="${REPO_ROOT}/.env"

case "${command_name}" in
    ensure)
        "${shared_root}/bin/ensure" "$@"
        ;;
    prune)
        "${shared_root}/bin/prune" "$@"
        ;;
    *)
        fail "unknown traefik subcommand: ${command_name}"
        ;;
esac
