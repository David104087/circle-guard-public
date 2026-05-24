#!/usr/bin/env bash
# semver.sh — Semantic versioning from Conventional Commits
# Usage: ./ci/semver.sh [--dry-run]
# Outputs the new version tag, creates the git tag (unless --dry-run).
# Reads commits since the last vX.Y.Z tag; bumps patch/minor/major based on type.
# Conventional Commit types:
#   feat: → minor bump
#   fix:, perf:, refactor:, style:, test:, chore:, docs:, build:, ci: → patch bump
#   BREAKING CHANGE footer or !: → major bump

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

last_tag=$(git describe --tags --abbrev=0 --match "v[0-9]*" 2>/dev/null || echo "")

if [[ -z "$last_tag" ]]; then
    echo "No existing semver tag found — starting from v0.0.0" >&2
    last_tag="v0.0.0"
    commits=$(git log --pretty=format:"%s" HEAD)
else
    echo "Last tag: $last_tag" >&2
    commits=$(git log --pretty=format:"%s" "${last_tag}..HEAD")
fi

IFS='.' read -r -a parts <<< "${last_tag#v}"
major="${parts[0]:-0}"
minor="${parts[1]:-0}"
patch="${parts[2]:-0}"

bump_major=false
bump_minor=false
bump_patch=false

while IFS= read -r commit; do
    [[ -z "$commit" ]] && continue
    if echo "$commit" | grep -qE "^[a-z]+(\([^)]+\))?!:|BREAKING[ -]CHANGE"; then
        bump_major=true
    elif echo "$commit" | grep -qE "^feat(\([^)]+\))?:"; then
        bump_minor=true
    else
        bump_patch=true
    fi
done <<< "$commits"

if $bump_major; then
    major=$((major + 1))
    minor=0
    patch=0
elif $bump_minor; then
    minor=$((minor + 1))
    patch=0
elif $bump_patch; then
    patch=$((patch + 1))
else
    echo "No commits found since $last_tag — version unchanged" >&2
    echo "$last_tag"
    exit 0
fi

new_tag="v${major}.${minor}.${patch}"
echo "New version: $new_tag" >&2

if $DRY_RUN; then
    echo "$new_tag"
    exit 0
fi

git tag -a "$new_tag" -m "Release $new_tag"
echo "$new_tag"
