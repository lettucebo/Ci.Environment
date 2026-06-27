---
description: Changelog format and the release / tag process.
applyTo: "**/CHANGELOG.md"
---

# Changelog & release conventions

- Follows **[Keep a Changelog](https://keepachangelog.com/)**. New work goes under `## [Unreleased]`, grouped into `### Added` / `### Fixed` / `### Changed` (a `### Documentation` group is also used). Reference the PR number in each entry, e.g. `... (#46)`.
- **Tags are lightweight and carry no `v` prefix** — `1.0.0`, `1.1.1`, `1.2.0`. The compare-link footer at the bottom of `CHANGELOG.md` also uses bare versions.

## Release flow (established by #42 and #48)

1. On a `release/<x.y.z>` branch, promote `## [Unreleased]` to `## [x.y.z] - YYYY-MM-DD` and update the compare-link footer (add the new `[x.y.z]` link and repoint `[Unreleased]` to `x.y.z...HEAD`).
2. Open and squash-merge a `docs: update CHANGELOG for release <x.y.z>` PR into `master`.
3. On the resulting `master` commit, create the GitHub release — this creates the lightweight tag for you, so **do not** pre-create an annotated tag:
   ```
   gh release create <x.y.z> --target master --title "<x.y.z>" --notes-file <notes>.md --latest
   ```
