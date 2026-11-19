# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/) and this project adheres to
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- Gatehouse triage gets `review_result` from the review job, so a pull request
  whose review died before posting anything is held instead of passing.
- The container release runs constitution v1.51.0's `container-release.yml`
  (was v1.46.0) and grants it `issues: write`, so a failed scheduled rebuild
  opens an issue instead of only warning. A `v*` promote now also refuses an
  image whose `version` label names a different release of this repo; this
  image sets no `version` label of its own, so the check is inert here.

## [1.0.1] - 2026-11-11

### Changed

- Constitution is now a v1.18.0 manifest: fleet and profile rules apply by
  reference, and the file keeps only what is specific to this repo.
- Constitution validation is pinned to the inherited release via
  `.github/workflows/constitution.yml`.
- Dependabot auto-merges GitHub Actions minor and patch updates.

## [1.0.0] - 2026-09-20

First tagged release. This image has been running in production since
before it had version control; this release marks the current state as
the baseline going forward.
