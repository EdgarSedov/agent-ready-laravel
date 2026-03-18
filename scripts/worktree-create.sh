#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

branch_name="${1:-}"

if [[ -z "${branch_name}" ]]; then
    fail "usage: ./scripts/worktree-create.sh <branch-name>"
fi

shift || true

if [[ $# -gt 0 ]]; then
    fail "unknown argument: $1"
fi

branch_slug="$(slugify "${branch_name}")"
worktree_parent="$(dirname "${REPO_ROOT}")/${APP_SLUG}-wt"
target_path="${worktree_parent}/${branch_slug}"

mkdir -p "${worktree_parent}"

if [[ -e "${target_path}" ]]; then
    fail "target path already exists: ${target_path}"
fi

if git -C "${REPO_ROOT}" show-ref --verify --quiet "refs/heads/${branch_name}"; then
    git -C "${REPO_ROOT}" worktree add "${target_path}" "${branch_name}"
else
    git -C "${REPO_ROOT}" worktree add -b "${branch_name}" "${target_path}" HEAD
fi

SOURCE_REPO_ROOT="${REPO_ROOT}" "${target_path}/scripts/bootstrap.sh"

printf 'worktree ready: %s\n' "${target_path}"
