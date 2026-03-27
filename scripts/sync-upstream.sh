#!/usr/bin/env bash
# sync-upstream.sh — Sync fork with upstream superpowers repository
#
# Fetches the latest upstream changes and merges them into the fork branch,
# then re-applies fork-specific manifest overrides.
#
# Usage: scripts/sync-upstream.sh [--dry-run]
#
# With --dry-run, shows what would happen without making changes.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$SCRIPT_DIR/fork-config.json"

if [[ ! -f "$CONFIG" ]]; then
  echo "Error: fork-config.json not found" >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install with: brew install jq" >&2
  exit 1
fi

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

UPSTREAM_REMOTE=$(jq -r '.upstream_remote' "$CONFIG")
UPSTREAM_BRANCH=$(jq -r '.upstream_branch' "$CONFIG")
FORK_BRANCH=$(jq -r '.fork_branch' "$CONFIG")

# Verify we're on the fork branch
CURRENT_BRANCH=$(git -C "$REPO_DIR" branch --show-current)
if [[ "$CURRENT_BRANCH" != "$FORK_BRANCH" ]]; then
  echo "Error: Expected to be on '$FORK_BRANCH' but on '$CURRENT_BRANCH'" >&2
  exit 1
fi

# Verify clean working tree
if ! git -C "$REPO_DIR" diff --quiet || ! git -C "$REPO_DIR" diff --cached --quiet; then
  echo "Error: Working tree is not clean. Commit or stash changes first." >&2
  exit 1
fi

echo "=== Upstream Sync ==="
echo "  upstream: $UPSTREAM_REMOTE/$UPSTREAM_BRANCH"
echo "  fork:     $FORK_BRANCH"
echo ""

# Fetch upstream
echo "Fetching $UPSTREAM_REMOTE..."
git -C "$REPO_DIR" fetch "$UPSTREAM_REMOTE" "$UPSTREAM_BRANCH" --tags

# Show what's new
MERGE_BASE=$(git -C "$REPO_DIR" merge-base HEAD "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH")
NEW_COMMITS=$(git -C "$REPO_DIR" rev-list --count "$MERGE_BASE..$UPSTREAM_REMOTE/$UPSTREAM_BRANCH")
UPSTREAM_VERSION=$(git -C "$REPO_DIR" show "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH:.claude-plugin/plugin.json" | jq -r '.version')
LOCAL_VERSION=$(jq -r '.version' "$REPO_DIR/.claude-plugin/plugin.json")

echo ""
echo "  Local version:    $LOCAL_VERSION"
echo "  Upstream version: $UPSTREAM_VERSION"
echo "  New commits:      $NEW_COMMITS"

if [[ "$NEW_COMMITS" -eq 0 ]]; then
  echo ""
  echo "Already up to date."
  exit 0
fi

echo ""
echo "New upstream commits:"
git -C "$REPO_DIR" log --oneline "$MERGE_BASE..$UPSTREAM_REMOTE/$UPSTREAM_BRANCH"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[dry-run] Would merge $NEW_COMMITS commits and re-apply fork overrides."

  # Check for potential conflicts
  echo ""
  echo "Files modified in both branches (potential conflicts):"
  LOCAL_CHANGES=$(git -C "$REPO_DIR" diff --name-only "$MERGE_BASE..HEAD" | sort)
  UPSTREAM_CHANGES=$(git -C "$REPO_DIR" diff --name-only "$MERGE_BASE..$UPSTREAM_REMOTE/$UPSTREAM_BRANCH" | sort)
  comm -12 <(echo "$LOCAL_CHANGES") <(echo "$UPSTREAM_CHANGES") | while read -r f; do
    echo "  $f"
  done
  exit 0
fi

# Merge upstream
echo "Merging $UPSTREAM_REMOTE/$UPSTREAM_BRANCH..."
if ! git -C "$REPO_DIR" merge "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH" --no-edit 2>&1; then
  echo ""
  echo "=== Merge conflicts detected ==="
  echo ""
  echo "Conflicting files:"
  git -C "$REPO_DIR" diff --name-only --diff-filter=U
  echo ""
  echo "Resolve conflicts, then run:"
  echo "  git add <resolved files>"
  echo "  git commit"
  echo "  scripts/apply-fork-overrides.sh --version $UPSTREAM_VERSION"
  echo "  git add -u && git commit -m 'apply fork overrides after upstream sync'"
  exit 1
fi

echo ""
echo "Merge successful. Applying fork overrides..."

# Re-apply fork overrides with the upstream version
"$SCRIPT_DIR/apply-fork-overrides.sh" --version "$UPSTREAM_VERSION"

# Check if overrides changed anything
if ! git -C "$REPO_DIR" diff --quiet; then
  git -C "$REPO_DIR" add \
    .claude-plugin/plugin.json \
    .claude-plugin/marketplace.json \
    .cursor-plugin/plugin.json \
    gemini-extension.json \
    package.json 2>/dev/null || true
  git -C "$REPO_DIR" commit -m "apply fork overrides after upstream sync to v${UPSTREAM_VERSION}"
  echo ""
  echo "Fork overrides committed."
fi

# Update submodules
echo ""
echo "Updating submodules..."
git -C "$REPO_DIR" submodule update --init --recursive

echo ""
echo "=== Sync complete ==="
echo "  Version: $UPSTREAM_VERSION"
echo "  Branch:  $FORK_BRANCH"
echo ""
echo "Next steps:"
echo "  1. Review changes: git log --oneline -20"
echo "  2. Push to fork:   git push internal $FORK_BRANCH"
