# Phase 7: Packaging & Identity - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-11-04
**Phase:** 07-Packaging & Identity
**Areas discussed:** Entry point file naming, .pubignore exclusion rules, pubspec.yaml metadata polish, Example app configuration & dependency linking

---

## Entry Point File Naming & Backward Compatibility

| Option | Description | Selected |
|--------|-------------|----------|
| Clean rename to lib/fl_network_inspector.dart | Standard Dart convention for new package name | ✓ |
| Retain deprecated forwarder | Keep lib/flutter_network_inspector.dart exporting the new entry point | |

**User's choice:** Clean rename to `lib/fl_network_inspector.dart`
**Notes:** Package has never been published under `fl_network_inspector` on pub.dev, so a clean rename represents the best idiomatic approach for a v1.0.0 release.

---

## Import Style

| Option | Description | Selected |
|--------|-------------|----------|
| Hybrid (package: for public & tests, relative for lib/src/) | Standard Flutter and Dart team recommended style | ✓ |
| package: everywhere | Use package:fl_network_inspector/... in all internal files | |

**User's choice:** Hybrid (package: for public barrel & tests, relative for `lib/src/`)

---

## .pubignore Exclusion Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Strict ignore list | Exclude .planning/, .agents/, .gemini/, .cursor/, GEMINI.md, .idea/, .vscode/, coverage/ | ✓ |
| Exclude only hidden directories | Exclude only hidden dot directories | |

**User's choice:** Strict ignore list
**Notes:** Ensures clean pub.dev package tarball with zero development or planning clutter.

---

## Automated Test Suite Inclusion in Pub Bundle

| Option | Description | Selected |
|--------|-------------|----------|
| Include test/ directory in pub.dev bundle | Standard Flutter practice for verifiable open source packages | ✓ |
| Exclude test/ directory | Minimizes download size | |

**User's choice:** Include `test/` directory in pub.dev bundle

---

## pubspec.yaml Description & Metadata

| Option | Description | Selected |
|--------|-------------|----------|
| Keep current description (119 chars) | Concise, clear, and within pub.dev 60-180 character recommendation | ✓ |
| Refine description | Add extra text | |

**User's choice:** Keep current description (119 characters)
**Notes:** GitHub URL `https://github.com/Dhaval-Chandegara/fl_network_inspector` confirmed for homepage, repository, and issue tracker.

---

## Example App Dependency

| Option | Description | Selected |
|--------|-------------|----------|
| Path dependency | fl_network_inspector: path: ../ | ✓ |
| Git dependency | Remote git reference | |

**User's choice:** Path dependency (`path: ../`)

---

## the agent's Discretion

- Syntax and structure of `.pubignore` sections.
- Batch replace strategy across the 125 internal import declarations.

## Deferred Ideas

- None — discussion stayed within Phase 7 scope.
