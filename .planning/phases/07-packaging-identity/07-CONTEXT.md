# Phase 7: Packaging & Identity - Context

**Gathered:** 2026-11-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 7 delivers official package identity and publishing boundary configuration for `fl_network_inspector`:
- Update `pubspec.yaml` name to `fl_network_inspector`, version to `1.0.0`, with verified repository, homepage, and issue tracker links.
- Cleanly rename the root library file from `lib/flutter_network_inspector.dart` to `lib/fl_network_inspector.dart`.
- Update all 125+ package import references across `lib/`, `test/`, and `example/` to `package:fl_network_inspector/`.
- Configure `example/pubspec.yaml` to consume `fl_network_inspector` via local path dependency (`path: ../`).
- Create a strict `.pubignore` file excluding internal planning artifacts, AI configurations, IDE files, and coverage, while retaining package code, tests, and example assets.

</domain>

<decisions>
## Implementation Decisions

### Entry Point & Library Structure
- **D-01:** Rename `lib/flutter_network_inspector.dart` cleanly to `lib/fl_network_inspector.dart` as the root library entry point without retaining deprecated legacy aliases, conforming to standard Dart pub naming conventions for a clean v1.0.0 initial release. — **Reversibility:** costly — changes public entry point import paths for any local consumers.
- **D-02:** Use `package:fl_network_inspector/...` for root barrel re-exports, test suite imports, and example application imports. Use clean relative imports within internal `lib/src/` modules. — **Reversibility:** reversible — find-and-replace across code files.

### .pubignore & Publishing Bundle Rules
- **D-03:** Create a strict `.pubignore` file excluding:
  - Planning and agent directories: `.planning/`, `.agents/`, `.gemini/`, `.cursor/`, `.codex/`, `.opencode/`, `.claude/`
  - Internal instructions and notes: `GEMINI.md`
  - IDE and system metadata: `.idea/`, `.vscode/`, `.DS_Store`, `*.swp`
  - Build and coverage artifacts: `coverage/`, `.dart_tool/`, `build/`
  — **Reversibility:** reversible — configuration file edit.
- **D-04:** Keep the `test/` directory included in the pub.dev published tarball, adhering to standard Flutter open-source package conventions for verifiable code quality. — **Reversibility:** reversible.

### Metadata & Manifest Alignment
- **D-05:** Retain current 119-character package description in `pubspec.yaml`: `"A lightweight, modular in-app HTTP network inspector for Flutter applications with shake-to-open and SQLite persistence"` (optimally within pub.dev's recommended 60–180 character scoring window). — **Reversibility:** reversible.
- **D-06:** Point `repository` and `homepage` in `pubspec.yaml` to `https://github.com/Dhaval-Chandegara/fl_network_inspector` and `issue_tracker` to `https://github.com/Dhaval-Chandegara/fl_network_inspector/issues`. — **Reversibility:** reversible.
- **D-07:** Retain 5 targeted topics in `pubspec.yaml`: `network`, `http`, `inspector`, `logging`, `debugging`. — **Reversibility:** reversible.

### Example Application Integration
- **D-08:** Set `example/pubspec.yaml` dependency to `fl_network_inspector: path: ../` and update `example/lib/main.dart` to import `package:fl_network_inspector/fl_network_inspector.dart`. — **Reversibility:** reversible.

### the agent's Discretion
- Ordering of sections inside `.pubignore` following pub.dev best practices.
- Exact regex or glob syntax in `.pubignore` to prevent accidental inclusion of nested hidden directories.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Package Identity & Requirements
- `.planning/REQUIREMENTS.md` §Packaging & Identity (PKG) — Requirements PKG-01, PKG-02, PKG-03
- `.planning/ROADMAP.md` §Phase 7: Packaging & Identity — Phase goals and success criteria
- `pubspec.yaml` — Root package manifest
- `example/pubspec.yaml` — Example application manifest

### Dart & Pub Publishing Standards
- Official Dart package layout convention: library entry point at `lib/<package_name>.dart`
- Dart pubignore format documentation: rules for excluding files from published archives

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/flutter_network_inspector.dart`: Existing root export barrel containing exports for all core classes (`NetworkInspector`, `NetworkInspectorConfig`, `NetworkInspectorWrapper`, `NetworkRecord`, `PayloadData`, `RecordFilter`, adapters, etc.).
- `pubspec.yaml`: Already contains valid environment SDK bounds (`sdk: ">=3.0.0 <4.0.0"`, `flutter: ">=3.10.0"`), valid plugin dependencies (`sqflite`, `sensors_plus`, `share_plus`), and dev dependencies.

### Established Patterns
- All submodules live cleanly under `lib/src/{config,core,interceptor,logging,models,repository,shake,storage,ui,utils}/`.
- Tests under `test/` mirror the `lib/src/` structure.

### Integration Points
- 125 occurrences of `package:flutter_network_inspector` across `lib/`, `test/`, and `example/`.
- `example/pubspec.yaml` dependency block.

</code_context>

<specifics>
## Specific Ideas

- Ensure `flutter pub publish --dry-run` reports package name `fl_network_inspector` version `1.0.0` with no warnings regarding uncommitted files or excessive archive size.

</specifics>

<deferred>
## Deferred Ideas

- None — discussion stayed strictly within the boundary of Phase 7 (Packaging & Identity).

</deferred>

---

*Phase: 7-Packaging & Identity*
*Context gathered: 2026-11-04*
