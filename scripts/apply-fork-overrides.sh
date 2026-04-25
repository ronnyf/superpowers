#!/usr/bin/env bash
# apply-fork-overrides.sh — Applies fork-specific manifest overrides
#
# Reads fork-config.json and patches plugin.json, marketplace.json,
# cursor plugin.json, and gemini-extension.json with fork-specific
# author, source, and extra plugin entries.
#
# Usage: scripts/apply-fork-overrides.sh [--version <ver>]
#
# If --version is given, also updates version fields across all manifests.
# Otherwise, preserves whatever version is already in the files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$SCRIPT_DIR/fork-config.json"

if [[ ! -f "$CONFIG" ]]; then
  echo "Error: fork-config.json not found at $CONFIG" >&2
  exit 1
fi

# Check for jq
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install with: brew install jq" >&2
  exit 1
fi

# Parse optional --version argument
VERSION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# Read config values
AUTHOR=$(jq -c '.plugin_overrides.author' "$CONFIG")
HOMEPAGE=$(jq -r '.plugin_overrides.homepage' "$CONFIG")
REPOSITORY=$(jq -r '.plugin_overrides.repository' "$CONFIG")
MKT_OWNER=$(jq -c '.marketplace_overrides.owner' "$CONFIG")
MKT_SOURCE=$(jq -c '.marketplace_overrides.superpowers_source' "$CONFIG")
EXTRA_PLUGINS=$(jq -c '.marketplace_overrides.extra_plugins' "$CONFIG")

echo "Applying fork overrides..."

# --- .claude-plugin/plugin.json ---
PLUGIN="$REPO_DIR/.claude-plugin/plugin.json"
if [[ -f "$PLUGIN" ]]; then
  jq --argjson author "$AUTHOR" \
     --arg homepage "$HOMEPAGE" \
     --arg repository "$REPOSITORY" \
     '.author = $author | .homepage = $homepage | .repository = $repository' \
     "$PLUGIN" > "$PLUGIN.tmp" && mv "$PLUGIN.tmp" "$PLUGIN"
  echo "  patched .claude-plugin/plugin.json"
fi

# --- .claude-plugin/marketplace.json ---
MARKETPLACE="$REPO_DIR/.claude-plugin/marketplace.json"
if [[ -f "$MARKETPLACE" ]]; then
  # Get current version from plugin.json for the ref
  CURRENT_VERSION=$(jq -r '.version' "$PLUGIN")
  REF_VERSION="${VERSION:-$CURRENT_VERSION}"

  # Build source object with version ref
  SOURCE_WITH_REF=$(echo "$MKT_SOURCE" | jq --arg ref "v${REF_VERSION}" '. + {ref: $ref}')

  jq --argjson owner "$MKT_OWNER" \
     --argjson source "$SOURCE_WITH_REF" \
     --argjson extras "$EXTRA_PLUGINS" \
     '
     .owner = $owner |
     .plugins[0].source = $source |
     # Merge extra plugins (by name, upsert)
     .plugins as $existing |
     reduce $extras[] as $ep (
       $existing;
       if any(.[]; .name == $ep.name)
       then map(if .name == $ep.name then $ep else . end)
       else . + [$ep]
       end
     ) as $merged |
     .plugins = $merged
     ' "$MARKETPLACE" > "$MARKETPLACE.tmp" && mv "$MARKETPLACE.tmp" "$MARKETPLACE"
  echo "  patched .claude-plugin/marketplace.json"
fi

# --- Version updates (if --version given) ---
if [[ -n "$VERSION" ]]; then
  echo "  updating version to $VERSION..."

  for f in .claude-plugin/plugin.json .codex-plugin/plugin.json .cursor-plugin/plugin.json gemini-extension.json package.json; do
    FILEPATH="$REPO_DIR/$f"
    if [[ -f "$FILEPATH" ]]; then
      jq --arg v "$VERSION" '.version = $v' "$FILEPATH" > "$FILEPATH.tmp" && mv "$FILEPATH.tmp" "$FILEPATH"
      echo "    $f -> $VERSION"
    fi
  done

  # Also update marketplace plugin version
  if [[ -f "$MARKETPLACE" ]]; then
    jq --arg v "$VERSION" '.plugins[0].version = $v' "$MARKETPLACE" > "$MARKETPLACE.tmp" && mv "$MARKETPLACE.tmp" "$MARKETPLACE"
  fi
fi

echo "Done. Fork overrides applied."
