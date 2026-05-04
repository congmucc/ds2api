#!/usr/bin/env bash
set -euo pipefail

upstream_url="${UPSTREAM_URL:-https://github.com/CJackHwang/ds2api.git}"
upstream_branch="${UPSTREAM_BRANCH:-main}"
upstream_remote="${UPSTREAM_REMOTE_NAME:-upstream}"
target_branch="${TARGET_BRANCH:-$(git branch --show-current 2>/dev/null || true)}"

write_output() {
  local key="$1"
  local value="$2"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf '%s=%s\n' "$key" "$value" >>"$GITHUB_OUTPUT"
  fi
}

if [[ -z "$target_branch" ]]; then
  echo "Cannot determine target branch. Set TARGET_BRANCH explicitly." >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree must be clean before syncing upstream." >&2
  git status --short >&2
  exit 1
fi

if git remote get-url "$upstream_remote" >/dev/null 2>&1; then
  git remote set-url "$upstream_remote" "$upstream_url"
else
  git remote add "$upstream_remote" "$upstream_url"
fi

git fetch --prune "$upstream_remote" "$upstream_branch"

upstream_ref="$upstream_remote/$upstream_branch"
before_sha="$(git rev-parse HEAD)"
upstream_sha="$(git rev-parse "$upstream_ref")"

write_output before_sha "$before_sha"
write_output upstream_sha "$upstream_sha"

if [[ "$before_sha" == "$upstream_sha" ]] || git merge-base --is-ancestor "$upstream_sha" HEAD; then
  echo "Already up to date with $upstream_ref."
  write_output changed false
  write_output status up_to_date
  write_output after_sha "$before_sha"
  exit 0
fi

echo "Merging $upstream_ref into $target_branch..."
if ! git merge --no-edit --log "$upstream_ref"; then
  echo "Upstream sync has conflicts. Resolve them manually, then rerun the workflow." >&2
  git merge --abort >/dev/null 2>&1 || true
  write_output changed false
  write_output status conflict
  exit 1
fi

after_sha="$(git rev-parse HEAD)"
write_output changed true
write_output status merged
write_output after_sha "$after_sha"

echo "Synced $target_branch: $before_sha -> $after_sha"
