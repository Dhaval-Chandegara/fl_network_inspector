#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
cd "$REPO_ROOT"

LOCKFILE="pubspec.lock"
BACKUP_LOCKFILE="pubspec.lock.verify_bak"

cleanup() {
  local exit_code=$?
  echo "[verify_lowest_bounds] Cleaning up and restoring lockfile state..."
  if [ -f "$BACKUP_LOCKFILE" ]; then
    cp "$BACKUP_LOCKFILE" "$LOCKFILE"
    rm -f "$BACKUP_LOCKFILE"
    echo "[verify_lowest_bounds] Restored $LOCKFILE from backup."
  fi
  flutter pub get >/dev/null 2>&1 || dart pub get >/dev/null 2>&1 || true
  echo "[verify_lowest_bounds] Lockfile restored. Exiting with code: $exit_code"
  exit "$exit_code"
}

trap cleanup EXIT INT TERM

echo "=========================================================="
echo " Starting Lowest-Bounds Dependency Verification Pipeline"
echo "=========================================================="

if [ -f "$LOCKFILE" ]; then
  cp "$LOCKFILE" "$BACKUP_LOCKFILE"
  echo "[verify_lowest_bounds] Backed up $LOCKFILE to $BACKUP_LOCKFILE"
fi

echo "[verify_lowest_bounds] Downgrading direct dependencies to minimum allowable versions..."
dart pub downgrade share_plus sensors_plus sqflite sqflite_common_ffi intl uuid path dio http

echo "[verify_lowest_bounds] Running all package tests under downgraded dependencies..."
flutter test --no-pub

echo "[verify_lowest_bounds] Running dedicated SQLite storage schema and harness tests..."
flutter test test/storage/ --no-pub

echo "[verify_lowest_bounds] SUCCESS: All lowest-bounds verifications passed!"
