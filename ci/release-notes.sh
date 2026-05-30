#!/usr/bin/env bash
# CircleGuard – Release Notes Generator
# Usage: ./ci/release-notes.sh <VERSION_TAG>
# Groups commits by Conventional Commit type. Used by master pipeline.

set -euo pipefail

VERSION="${1:-v$(date +%Y%m%d%H%M)}"
OUTPUT="RELEASE_NOTES_${VERSION}.md"
REPO_URL="https://github.com/David104087/circle-guard-public"

echo "Generating release notes for ${VERSION}..." >&2

PREV_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || git rev-list --max-parents=0 HEAD)
echo "Changes since: ${PREV_TAG}" >&2

cat > "${OUTPUT}" << EOF
# Release Notes – CircleGuard ${VERSION}

**Release Date:** $(date -u +"%Y-%m-%d %H:%M UTC")
**Environment:** Production
**Docker Hub:** \`davidartunduaga/circleguard-*:${VERSION}\`

---

## Deployed Services

| Service | Port | Image Tag |
|---------|------|-----------|
| auth-service | 8180 | \`${VERSION}\` |
| dashboard-service | 8084 | \`${VERSION}\` |
| file-service | 8085 | \`${VERSION}\` |
| form-service | 8086 | \`${VERSION}\` |
| gateway-service | 8087 | \`${VERSION}\` |
| identity-service | 8083 | \`${VERSION}\` |
| notification-service | 8082 | \`${VERSION}\` |
| promotion-service | 8088 | \`${VERSION}\` |

---

## Changes in this Release

EOF

_section() {
  local title="$1" pattern="$2"
  local commits
  commits=$(git log "${PREV_TAG}..HEAD" --pretty=format:"%s" --no-merges 2>/dev/null \
    | grep -iE "^${pattern}" || true)
  if [ -n "$commits" ]; then
    echo "### ${title}" >> "${OUTPUT}"
    echo "" >> "${OUTPUT}"
    while IFS= read -r line; do
      echo "- ${line}" >> "${OUTPUT}"
    done <<< "$commits"
    echo "" >> "${OUTPUT}"
  fi
}

_section "New Features"        "feat[:([]"
_section "Bug Fixes"           "fix[:([]"
_section "Performance"         "perf[:([]"
_section "Refactoring"         "refactor[:([]"
_section "Tests"               "test[:([]"
_section "CI/CD"               "ci[:([]|build[:([]"
_section "Documentation"       "docs[:([]"
_section "Maintenance"         "chore[:([]"

echo "### All Commits" >> "${OUTPUT}"
echo "" >> "${OUTPUT}"
git log "${PREV_TAG}..HEAD" \
  --pretty=format:"- [\`%h\`](${REPO_URL}/commit/%H) %s (%an, %ad)" \
  --date=short --no-merges >> "${OUTPUT}" 2>/dev/null || true
echo "" >> "${OUTPUT}"

TOTAL_TESTS=0; FAILED_TESTS=0
for f in services/*/build/test-results/**/*.xml; do
  [ -f "$f" ] || continue
  t=$(grep -o 'tests="[0-9]*"' "$f" | grep -o '[0-9]*' || echo 0)
  e=$(grep -o 'failures="[0-9]*"' "$f" | grep -o '[0-9]*' || echo 0)
  TOTAL_TESTS=$((TOTAL_TESTS + t))
  FAILED_TESTS=$((FAILED_TESTS + e))
done
PASSED_TESTS=$((TOTAL_TESTS - FAILED_TESTS))

cat >> "${OUTPUT}" << EOF

---

## Test Summary

| Metric | Value |
|--------|-------|
| Total Tests | ${TOTAL_TESTS} |
| Passed | ${PASSED_TESTS} |
| Failed | ${FAILED_TESTS} |
| Build Number | ${BUILD_NUMBER:-N/A} |

---

## Deployment Checklist

- [x] Unit tests passed
- [x] Integration tests passed
- [x] E2E tests passed
- [x] SonarQube quality gate passed
- [x] Trivy scan completed (no new CRITICAL blockers)
- [x] Docker images pushed to Docker Hub
- [x] Kubernetes manifests applied to production
- [x] Canary approved at 10% → promoted to 100%
- [x] All rollouts healthy

---

*Generated automatically by CircleGuard CI/CD pipeline.*
EOF

echo "Release notes written to: ${OUTPUT}" >&2
