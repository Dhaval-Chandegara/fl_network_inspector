# Phase 13: Multi-Version Resolution & CI Test Matrix - Pattern Map

**Mapped:** 2026-11-23  
**Files analyzed:** 3 new files  
**Analogs found:** 2 / 3 (2 exact bash utility analogs; 1 CI config with no prior in-repo workflow analog)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `tool/verify_consumer_resolution.sh` | utility | batch / file-I/O | `tool/verify_lowest_bounds.sh` | exact |
| `tool/verify_pana.sh` | utility | batch / file-I/O | `tool/verify_lowest_bounds.sh` | exact |
| `.github/workflows/ci.yml` | config | event-driven | None (Reference: `13-RESEARCH.md`) | no-analog |

---

## Pattern Assignments

### `tool/verify_consumer_resolution.sh` (utility, batch / file-I/O)

**Primary Analog:** `tool/verify_lowest_bounds.sh` (exact shell verification pipeline match)  
**Secondary Analogs:** `example/pubspec.yaml` & `example/lib/main.dart` (consumer project and entry point reference)

**Script Safety & Canonical Path Resolution** (`tool/verify_lowest_bounds.sh` lines 1-7):
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
cd "$REPO_ROOT"
```

**Signal Trap & Ephemeral Workspace Cleanup** (`tool/verify_lowest_bounds.sh` lines 11-24 adapted for `mktemp -d`):
```bash
TEMP_DIR="$(mktemp -d)"
echo "[verify_consumer] Created ephemeral workspace: $TEMP_DIR"

cleanup() {
  local exit_code=$?
  echo "[verify_consumer] Cleaning up ephemeral workspace..."
  rm -rf "$TEMP_DIR"
  echo "[verify_consumer] Exiting with status $exit_code"
  exit "$exit_code"
}

trap cleanup EXIT INT TERM
```

**Consumer Archetype Generation & Verification Pattern** (synthesized from `example/pubspec.yaml` lines 1-17 and `example/lib/main.dart` lines 1-19):
```bash
run_archetype() {
  local name="$1"
  local extra_deps="$2"
  local dir="$TEMP_DIR/$name"
  mkdir -p "$dir/lib"

  echo "=========================================================="
  echo " Verifying Archetype: $name"
  echo "=========================================================="

  cat << EOF > "$dir/pubspec.yaml"
name: consumer_$name
description: Ephemeral consumer resolution simulation for $name
publish_to: 'none'
environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: ">=3.10.0"

dependencies:
  flutter:
    sdk: flutter
  fl_network_inspector:
    path: $REPO_ROOT
$extra_deps
EOF

  cat << 'EOF' > "$dir/lib/main.dart"
import 'package:flutter/widgets.dart';
import 'package:fl_network_inspector/fl_network_inspector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NetworkInspector.initialize();
  assert(NetworkInspector.isInitialized);
}
EOF

  (
    cd "$dir"
    echo "[verify_consumer][$name] Resolving dependencies with flutter pub get..."
    flutter pub get
    echo "[verify_consumer][$name] Verifying compile-time compatibility with dart analyze..."
    dart analyze --fatal-infos lib/main.dart
  )

  echo "[verify_consumer][$name] PASS: Resolved and analyzed successfully!"
}
```

**Archetype Matrix Definition** (fulfilling D-06 & MATRIX-01):
```bash
# 1. Modern Consumer (contemporary default app)
run_archetype "modern" ""

# 2. Legacy Floor Consumer (pinned lowest dependency floors)
run_archetype "legacy_floor" "  dio: 5.2.0
  share_plus: 11.0.0
  intl: 0.18.0
  sqflite: 2.2.0"

# 3. Mid-Tier Consumer (realistic mix of Dio 5.x and Http 1.x)
run_archetype "mid_tier" "  dio: ^5.4.0
  http: ^1.2.0
  sqflite: ^2.3.0"

# 4. Strict Localization Consumer (flutter_localizations SDK bounds)
run_archetype "strict_localization" "  flutter_localizations:
    sdk: flutter"
```

**Status Logging Pattern** (`tool/verify_lowest_bounds.sh` lines 26-28, 44):
```bash
echo "=========================================================="
echo " SUCCESS: All 4 consumer archetypes resolved cleanly!"
echo "=========================================================="
```

---

### `tool/verify_pana.sh` (utility, batch / file-I/O)

**Analog:** `tool/verify_lowest_bounds.sh` (exact shell pipeline and error exit pattern)

**Script Header & Root Path Setup** (`tool/verify_lowest_bounds.sh` lines 1-7):
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
cd "$REPO_ROOT"
```

**Packaging Gate Pattern** (`tool/verify_lowest_bounds.sh` execution flow):
```bash
echo "=========================================================="
echo " Packaging & Quality Verification Pipeline"
echo "=========================================================="

# 1. Verify publishing packaging boundary
echo "[verify_pana] Step 1: Running flutter pub publish --dry-run..."
flutter pub publish --dry-run
echo "[verify_pana] Dry run passed with 0 warnings!"

# 2. Ensure pana CLI is available
if ! command -v pana >/dev/null 2>&1; then
  echo "[verify_pana] Activating pana CLI from pub.dev..."
  dart pub global activate pana >/dev/null
  export PATH="$HOME/.pub-cache/bin:$PATH"
fi
```

**Score Verification Pattern & Error Handling** (avoids `--exit-code-threshold` inversion pitfall from `13-RESEARCH.md §Pitfall 1`):
```bash
# 3. Execute pana scoring analysis
echo "[verify_pana] Step 2: Running pana package analysis..."
PANA_JSON="$(pana --json . 2>/dev/null || true)"

if [ -z "$PANA_JSON" ]; then
  echo "[verify_pana] WARNING: Pana analysis failed to produce JSON output. Checking human output..."
  pana .
  exit 1
fi

# Extract granted points and max points
GRANTED_POINTS=$(echo "$PANA_JSON" | grep -o '"grantedPoints":[0-9]*' | head -1 | cut -d: -f2 || echo "0")
MAX_POINTS=$(echo "$PANA_JSON" | grep -o '"maxPoints":[0-9]*' | head -1 | cut -d: -f2 || echo "0")

echo "[verify_pana] Pana Score: $GRANTED_POINTS / $MAX_POINTS points"

if [ "$GRANTED_POINTS" -lt 140 ]; then
  echo "[verify_pana] ERROR: Pana score ($GRANTED_POINTS) fell below required 140 point floor!"
  pana .
  exit 1
fi

echo "[verify_pana] SUCCESS: Packaging and quality verification passed (Score: $GRANTED_POINTS / $MAX_POINTS)!"
```

---

## Shared Patterns

### 1. Script Safety & POSIX Signal Traps
**Source:** `tool/verify_lowest_bounds.sh` lines 2, 11-24  
**Apply to:** All verification scripts in `tool/` (`tool/verify_lowest_bounds.sh`, `tool/verify_consumer_resolution.sh`, `tool/verify_pana.sh`)
```bash
set -euo pipefail

cleanup() {
  local exit_code=$?
  # perform cleanup / resource release
  exit "$exit_code"
}
trap cleanup EXIT INT TERM
```

### 2. Relative Root Path Anchoring
**Source:** `tool/verify_lowest_bounds.sh` lines 4-6  
**Apply to:** All standalone tools executing from arbitrary terminal working directories
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
cd "$REPO_ROOT"
```

### 3. Delimited Milestone Console Logging
**Source:** `tool/verify_lowest_bounds.sh` lines 26-28, 44  
**Apply to:** All verification pipeline scripts for clear CI/local output parsing
```bash
echo "=========================================================="
echo " Starting <Operation Name>"
echo "=========================================================="
...
echo "=========================================================="
echo " SUCCESS: <Operation Name> passed!"
echo "=========================================================="
```

### 4. Consumer App Facade Initialization
**Source:** `lib/src/core/network_inspector.dart` lines 56-62, 215-217 & `example/lib/main.dart` lines 11-19  
**Apply to:** Ephemeral consumer `main.dart` fixtures in `tool/verify_consumer_resolution.sh`
```dart
import 'package:flutter/widgets.dart';
import 'package:fl_network_inspector/fl_network_inspector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NetworkInspector.initialize();
  assert(NetworkInspector.isInitialized);
}
```

---

## No Analog Found

Files with no existing in-repo analog (planner must reference `13-RESEARCH.md` specifications directly):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `.github/workflows/ci.yml` | config | event-driven | No prior GitHub Actions workflow files exist in the repository (`.github/workflows/` directory is new in Phase 13). |

### Guidance for `.github/workflows/ci.yml`

The planner and implementer should copy patterns directly from `13-RESEARCH.md §Architecture Patterns` and `§Code Examples #3`:

1. **Triggers & Concurrency Controls** (D-13, D-14):
   ```yaml
   name: CI
   on:
     push:
       branches: [main]
     pull_request:
       branches: [main]
     workflow_dispatch:

   concurrency:
     group: ${{ github.workflow }}-${{ github.ref }}
     cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}
   ```

2. **Action Dependencies & Caching** (D-15):
   - Standardize on `actions/checkout@v4`.
   - Standardize on `subosito/flutter-action@v2` with `cache: true`.

3. **Fast Fail-Fast Quality Gate** (D-11):
   - Job `lint-and-quality` on `ubuntu-latest`.
   - Runs `dart format --output=none --set-exit-if-changed .`, `flutter analyze --no-fatal-infos`, and `bash tool/verify_pana.sh`.

4. **Multi-Track Parallel Matrix Fan-Out** (D-01, D-02, D-03, D-04, D-05):
   - `consumer-resolution` (needs `lint-and-quality`): runs `bash tool/verify_consumer_resolution.sh`.
   - `lowest-bounds` (needs `lint-and-quality`): runs `bash tool/verify_lowest_bounds.sh`.
   - `test-matrix` (needs `lint-and-quality`): matrix channel `['stable', 'beta']`, with `continue-on-error: ${{ matrix.channel == 'beta' }}`.
   - `multi-os-smoke` (needs `lint-and-quality`): matrix os `[macos-latest, windows-latest]`, running SQLite FFI headless tests (`flutter test test/storage/ test/core/`).

5. **Aggregate Status Check for Branch Protection** (D-16):
   - Single gate job `all-checks-passed` on `ubuntu-latest`.
   - Specifies `needs: [lint-and-quality, consumer-resolution, lowest-bounds, test-matrix, multi-os-smoke]`.
   - Uses `if: always()` and validates that all upstream results equal `'success'`.

---

## Metadata

**Analog search scope:** `tool/`, `example/`, `lib/`, `test/`, root configuration files  
**Files scanned:** 48  
**Pattern extraction date:** 2026-11-23  
