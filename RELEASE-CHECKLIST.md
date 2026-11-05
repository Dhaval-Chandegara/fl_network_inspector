# Release Checklist — `fl_network_inspector` v1.0.0

This checklist guides package maintainers through the complete, end-to-end release process for publishing `fl_network_inspector` v1.0.0 to [pub.dev](https://pub.dev/packages/fl_network_inspector).

---

## 1. Pre-Flight Quality Gates

Before initiating any release tag or publication, run all automated quality gates from the repository root. Every gate must pass with zero errors, warnings, or unformatted files.

### 1.1 Static Analysis
Verify that all source and test files satisfy strict analyzer rules without hints or lints:
```bash
flutter analyze
```
*Expected Result:* `No issues found!`

### 1.2 Test Suite Execution
Execute the entire unit, widget, and integration test suite (213 automated tests across storage, interceptors, models, UI, shake detection, and redaction):
```bash
flutter test
```
*Expected Result:* `All tests passed!` (213/213 passed)

### 1.3 Code Formatting
Assert that all 104 Dart source and test files adhere strictly to standard Dart format rules:
```bash
dart format --output=none --set-exit-if-changed .
```
*Expected Result:* `Formatted 104 files (0 changed)` with exit code `0`.

### 1.4 API Documentation Validation
Generate dry-run documentation to ensure 100% public API doc coverage without broken links or unresolved doc references:
```bash
dart doc --dry-run
```
*Expected Result:* `Found 0 warnings and 0 errors.`

### 1.5 Package Publish Dry Run
Execute the official Flutter package manager dry run to validate package archive integrity, `.pubignore` exclusions, and metadata syntax:
```bash
flutter pub publish --dry-run
```
*Expected Result:*
- `Total compressed archive size: ~118 KB.`
- Excludes `.planning/`, `.agents/`, `.gemini/`, `.cursor/`, `.codex/`, `.opencode/`, `GEMINI.md`, `build/`, `doc/api/`.
- `Package has 0 warnings.`

---

## 2. Pana 140/140 Audit Checklist

Verify that the package satisfies every scoring dimension of the official pub.dev `pana` package analyzer:

| Dimension | Points | Status | Verification Criteria |
| :--- | :---: | :---: | :--- |
| **Follow Dart file conventions** | **10 / 10** | ✅ Passed | Valid `pubspec.yaml` with concise description (119 chars), homepage, repository, issue tracker, topics. Well-formatted `README.md` (>10 KB) with quick start, setup, and platform support matrix. `CHANGELOG.md` following [Keep a Changelog](https://keepachangelog.com/) with `[1.0.0]`. Standard OSI-approved `LICENSE` (MIT). |
| **Provide documentation** | **10 / 10** | ✅ Passed | 100% doc comment coverage across all public symbols exported via `lib/fl_network_inspector.dart`. Zero warnings or broken doc links (`dart doc --dry-run`). |
| **Platform support** | **20 / 20** | ✅ Passed | Recognized cross-platform compatibility across all 6 targets: **Android**, **iOS**, **macOS**, **Windows**, **Linux**, and **Web** with proper FFI and web in-memory fallback handling. |
| **Pass static analysis** | **50 / 50** | ✅ Passed | Zero errors, warnings, or lint violations under `flutter_lints` and `analysis_options.yaml`. |
| **Support up-to-date dependencies** | **40 / 40** | ✅ Passed | SDK environment constraints `sdk: ">=3.0.0 <4.0.0"` and `flutter: ">=3.10.0"`. Modern, non-conflicting dependency bounds (`uuid`, `sqflite`, `sqflite_common_ffi`, `dio`, `http`, `intl`, `share_plus`, `sensors_plus`). |
| **Support sound null safety** | **10 / 10** | ✅ Passed | Fully sound null-safe codebase on Dart 3.x. |
| **Total Target Score** | **140 / 140** | ✅ Passed | Maximum possible score on pub.dev. |

---

## 3. Git Release Tagging

Once all pre-flight quality gates pass cleanly and git working tree is clean:

### 3.1 Verify Working Tree Status
Confirm that there are no uncommitted changes or untracked temporary files:
```bash
git status
```
*Expected Result:* `nothing to commit, working tree clean` on branch `main`.

### 3.2 Create Annotated Release Tag
Create an annotated git tag matching the version specified in `pubspec.yaml` (`1.0.0`). If tag `v1.0.0` already exists locally, update or replace it:
```bash
# If tag v1.0.0 already exists locally, update or replace it:
git tag -fa v1.0.0 -m "Release fl_network_inspector v1.0.0"
```

### 3.3 Push Release to Remote
Push both the main branch commit and the annotated release tag to GitHub:
```bash
git push origin main
git push origin v1.0.0
```

*(Optional)* Create a GitHub Release corresponding to `v1.0.0` with release notes copied from `CHANGELOG.md ## [1.0.0]`.

---

## 4. Live Publication to pub.dev

> [!IMPORTANT]
> Live publication is irreversible on pub.dev. Once published, version `1.0.0` cannot be overwritten or deleted (only retracted or superseded by a subsequent release).

### 4.1 Run the Publish Command
Execute the live publication command from the package root:
```bash
flutter pub publish
```

### 4.2 Interactive Authentication
1. The Flutter tool will display the archive contents and prompt:
   ```
   Do you want to publish fl_network_inspector 1.0.0 to https://pub.dev (y/N)?
   ```
2. Type `y` and press `Enter`.
3. If publishing for the first time or if the local token is expired, the tool will output a Google OAuth URL:
   - Open the URL in your browser.
   - Log in with the authorized maintainer Google account.
   - Authorize `pub.dev`.
4. The tool will upload the package archive and confirm:
   ```
   Successfully published fl_network_inspector 1.0.0 to https://pub.dev.
   ```

---

## 5. Post-Publication Validation

After publication completes, perform the following validation checks:

- [ ] **Package Listing Page**: Visit `https://pub.dev/packages/fl_network_inspector` and confirm version `1.0.0` is live.
- [ ] **Pana Score Report**: Wait 5–15 minutes for the pub.dev analysis worker to complete. Check the **Scores** tab and confirm **140 / 140 points** and platform badges (**Android**, **iOS**, **Linux**, **macOS**, **Web**, **Windows**).
- [ ] **API Documentation**: Navigate to `https://pub.dev/documentation/fl_network_inspector/latest/` and verify that the API reference documentation rendered without defects.
- [ ] **Consumer Smoke Test**: Create a clean test Flutter project and verify dependency installation:
  ```bash
  cd /tmp
  flutter create test_consumer_app
  cd test_consumer_app
  flutter pub add fl_network_inspector
  flutter analyze
  ```
- [ ] **GitHub Milestone**: Close Milestone `v1.1` in the GitHub repository.
