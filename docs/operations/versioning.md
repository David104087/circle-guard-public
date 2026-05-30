# CircleGuard — Release Versioning Convention

## Format

Tags follow **Semantic Versioning**: `vMAJOR.MINOR.PATCH`

| Bump | When | Example commit |
|------|------|----------------|
| `PATCH` | Bug fixes, chores, docs, CI changes | `fix: null pointer in survey`, `chore: update deps` |
| `MINOR` | New features (backward compatible) | `feat: add pdf export to dashboard` |
| `MAJOR` | Breaking changes | `feat!: rename all API endpoints` or `BREAKING CHANGE:` footer |

## How it works in the pipeline

`ci/semver.sh` reads all commits since the last `vX.Y.Z` tag and applies the highest bump found:

```
BREAKING CHANGE or ! in type → major bump (v1.2.3 → v2.0.0)
feat: → minor bump (v1.2.3 → v1.3.0)
fix/perf/refactor/chore/... → patch bump (v1.2.3 → v1.2.4)
```

The master pipeline:
1. Runs `ci/semver.sh --dry-run` to compute the version
2. Generates `RELEASE_NOTES_vX.Y.Z.md` via `ci/release-notes.sh`
3. Creates the git tag via `gh api` (pushes to remote)
4. Creates a GitHub Release with the release notes attached

## Enforced convention

Commit messages MUST follow Conventional Commits format:
```
<type>(<scope>): <description>

Types: feat, fix, perf, refactor, style, test, chore, docs, build, ci
```

PRs with non-conforming titles will have incorrect version bumps — always prefix with a valid type.

## Manual tag creation (emergency only)

```bash
# Must match vX.Y.Z format
git tag -a v1.2.5 -m "Release v1.2.5"
gh api repos/David104087/circle-guard-public/git/refs \
  -X POST -f ref="refs/tags/v1.2.5" -f sha="$(git rev-parse HEAD)"
```

Never create tags with other formats — `ci/semver.sh` ignores non-`v[0-9]` tags.
