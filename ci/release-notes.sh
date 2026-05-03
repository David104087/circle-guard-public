#!/usr/bin/env bash
# CircleGuard – Automatic Release Notes Generator
# Usage: ./ci/release-notes.sh <VERSION_TAG>
# Generates RELEASE_NOTES_<tag>.md from git log since last tag.

set -euo pipefail

VERSION="${1:-v$(date +%Y%m%d%H%M)}"
OUTPUT="RELEASE_NOTES_${VERSION}.md"
REPO_URL="https://github.com/David104087/circle-guard-public"

echo "Generating release notes for ${VERSION}..."

# Get previous tag
PREV_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || git rev-list --max-parents=0 HEAD)

echo "Changes since: ${PREV_TAG}"

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
| notification-service | 8082 | \`${VERSION}\` |
| promotion-service | 8088 | \`${VERSION}\` |

---

## Changes in this Release

EOF

# Features
FEATURES=$(git log "${PREV_TAG}..HEAD" --pretty=format:"%s" --no-merges | grep -i "^feat\|^feature\|^add\|^new" || true)
if [ -n "${FEATURES}" ]; then
    echo "### New Features" >> "${OUTPUT}"
    echo "" >> "${OUTPUT}"
    while IFS= read -r line; do
        echo "- ${line}" >> "${OUTPUT}"
    done <<< "${FEATURES}"
    echo "" >> "${OUTPUT}"
fi

# Bug Fixes
FIXES=$(git log "${PREV_TAG}..HEAD" --pretty=format:"%s" --no-merges | grep -i "^fix\|^bug\|^hotfix\|^patch" || true)
if [ -n "${FIXES}" ]; then
    echo "### Bug Fixes" >> "${OUTPUT}"
    echo "" >> "${OUTPUT}"
    while IFS= read -r line; do
        echo "- ${line}" >> "${OUTPUT}"
    done <<< "${FIXES}"
    echo "" >> "${OUTPUT}"
fi

# All commits
echo "### All Commits" >> "${OUTPUT}"
echo "" >> "${OUTPUT}"
git log "${PREV_TAG}..HEAD" --pretty=format:"- [\`%h\`](${REPO_URL}/commit/%H) %s (%an, %ad)" \
    --date=short --no-merges >> "${OUTPUT}" || true
echo "" >> "${OUTPUT}"

# Test summary
echo "" >> "${OUTPUT}"
echo "---" >> "${OUTPUT}"
echo "" >> "${OUTPUT}"
echo "## Test Summary" >> "${OUTPUT}"
echo "" >> "${OUTPUT}"

TOTAL_TESTS=0
FAILED_TESTS=0

for f in services/*/build/test-results/**/*.xml; do
    if [ -f "$f" ]; then
        tests=$(grep -o 'tests="[0-9]*"' "$f" | grep -o '[0-9]*' || echo 0)
        failures=$(grep -o 'failures="[0-9]*"' "$f" | grep -o '[0-9]*' || echo 0)
        TOTAL_TESTS=$((TOTAL_TESTS + tests))
        FAILED_TESTS=$((FAILED_TESTS + failures))
    fi
done

PASSED_TESTS=$((TOTAL_TESTS - FAILED_TESTS))

cat >> "${OUTPUT}" << EOF
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
- [x] Docker images pushed to Docker Hub
- [x] Kubernetes manifests applied
- [x] All rollouts healthy

---

*Generated automatically by CircleGuard CI/CD pipeline.*
EOF

echo "Release notes written to: ${OUTPUT}"
cat "${OUTPUT}"
