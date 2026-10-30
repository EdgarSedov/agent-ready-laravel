#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

remove_worktree=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --remove-worktree)
            remove_worktree=1
            shift
            ;;
        *)
            fail "unknown argument: $1"
            ;;
    esac
done

compose down --remove-orphans || true

if [[ ${remove_worktree} -eq 1 ]]; then
    if is_main_checkout; then
        fail "refusing to remove the primary checkout"
    fi

    common_git_dir="$(git -C "${REPO_ROOT}" rev-parse --git-common-dir)"
    git --git-dir="${common_git_dir}" worktree remove --force "${REPO_ROOT}"
    log "removed worktree ${REPO_ROOT}"
fi
