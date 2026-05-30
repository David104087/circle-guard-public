# CircleGuard — Coverage Policy

## Threshold

**60% line coverage** per service, enforced in the CI pipeline.

The pipeline fails the build if any service drops below this threshold.

## Rationale

- 60% is achievable with the existing Taller 2 tests without requiring additional test writing.
- It covers all critical business logic paths (survey submission, status propagation, JWT validation).
- The threshold applies to **line coverage** (not branch coverage) to avoid penalizing complex conditionals in graph propagation code (promotion-service Cypher queries).

## How to check coverage locally

```bash
./gradlew test jacocoTestReport
# Per-service HTML report: services/<svc>/build/reports/jacoco/test/html/index.html

./gradlew aggregateCoverageReport
# Aggregate XML: build/reports/jacoco-aggregate/jacocoTestReport.xml
# Aggregate HTML: build/reports/jacoco-aggregate/html/index.html
```

## Pipeline integration

The `Coverage Report` stage in `ci/Jenkinsfile.dev` runs `aggregateCoverageReport` and publishes via the JaCoCo Jenkins plugin. A red build is triggered if `lineCoverage < 0.60`.

## Graduation criteria

When the project reaches Phase 8 (security hardening), the threshold will be raised to **70%** with the addition of security-focused unit tests for JWT validation and input sanitization edge cases.
