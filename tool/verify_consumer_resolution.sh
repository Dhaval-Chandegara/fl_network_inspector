#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

TEMP_DIR="$(mktemp -d)"
echo "[verify_consumer] Created ephemeral workspace: $TEMP_DIR"

cleanup() {
  local exit_code=$?
  echo "[verify_consumer] Cleaning up ephemeral workspace: $TEMP_DIR"
  rm -rf "$TEMP_DIR"
  echo "[verify_consumer] Exiting with status $exit_code"
  exit "$exit_code"
}
trap cleanup EXIT INT TERM

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

echo "=========================================================="
echo " Starting Ephemeral Consumer Resolution Verification"
echo "=========================================================="

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

echo "=========================================================="
echo " SUCCESS: All 4 consumer archetypes resolved cleanly!"
echo "=========================================================="
