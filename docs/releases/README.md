# CircleGuard — Release Notes Index

All production releases are versioned with `vMAJOR.MINOR.PATCH` (see [versioning convention](../operations/versioning.md)) and auto-published as GitHub Releases by the master pipeline.

---

## Release History

| Version | Date | Highlights | GitHub Release |
|---------|------|-----------|---------------|
| [v0.1.0](../../RELEASE_NOTES_v0.1.0.md) | 2026-05-30 | First production release — complete Proyecto Final implementation (Phases 0–10): Terraform IaC, GKE migration, Istio mesh, CI/CD with canary, full test suite, observability stack, security, change management | [v0.1.0](https://github.com/David104087/circle-guard-public/releases/tag/v0.1.0) |

> Release notes are generated automatically by `ci/release-notes.sh` when the master pipeline runs end-to-end. Each release note is committed to the repo root as `RELEASE_NOTES_vX.Y.Z.md`.

---

## How to View Release Notes

```bash
# List all release note files
ls RELEASE_NOTES_*.md

# View on GitHub
gh release list --repo David104087/circle-guard-public
gh release view v0.1.0 --repo David104087/circle-guard-public
```

---

## How to Create a Release

The master pipeline handles this automatically. For a manual release:

```bash
# 1. Compute new version
NEW_VERSION=$(./ci/semver.sh --dry-run)

# 2. Generate release notes
./ci/release-notes.sh "${NEW_VERSION}"

# 3. Create tag via GitHub API
./ci/semver.sh

# 4. Publish GitHub Release
NEW_TAG=$(git describe --tags --abbrev=0)
gh release create "${NEW_TAG}" \
  --title "Release ${NEW_TAG}" \
  --notes-file "RELEASE_NOTES_${NEW_TAG}.md" \
  --repo David104087/circle-guard-public
```
