#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
cd "$REPO_ROOT"

echo "=========================================================="
echo " Packaging & Quality Verification Pipeline"
echo "=========================================================="

# 1. Verify publishing packaging boundary
echo "[verify_pana] Step 1: Running flutter pub publish --dry-run..."
flutter pub publish --dry-run
echo "[verify_pana] Dry run passed with 0 warnings!"

# 2. Ensure pana CLI is available
export PATH="$HOME/.pub-cache/bin:$PATH"

if ! command -v pana >/dev/null 2>&1; then
  if ! dart pub global list | grep -q pana; then
    echo "[verify_pana] Activating pana CLI from pub.dev..."
    dart pub global activate pana >/dev/null
  fi
fi

PANA_BIN="pana"
if ! command -v "$PANA_BIN" >/dev/null 2>&1; then
  PANA_BIN="dart pub global run pana:pana"
fi

# 3. Execute pana scoring analysis
echo "[verify_pana] Step 2: Running pana package analysis..."
PANA_JSON="$($PANA_BIN --json . 2>/dev/null || true)"

if [ -z "$PANA_JSON" ]; then
  echo "[verify_pana] WARNING: Pana analysis failed to produce JSON output. Checking human output..."
  $PANA_BIN . || true
  echo "[verify_pana] ERROR: Could not retrieve pana scoring report (check network reachability to pub.dev)."
  exit 1
fi

# Extract granted points and max points directly from JSON
if command -v node >/dev/null 2>&1; then
  GRANTED_POINTS=$(node -e 'try{const d=JSON.parse(process.argv[1]);console.log(d.scores?.grantedPoints ?? d.grantedPoints ?? 0)}catch{console.log(0)}' "$PANA_JSON")
  MAX_POINTS=$(node -e 'try{const d=JSON.parse(process.argv[1]);console.log(d.scores?.maxPoints ?? d.maxPoints ?? 0)}catch{console.log(0)}' "$PANA_JSON")
else
  GRANTED_POINTS=$(echo "$PANA_JSON" | grep -A 3 '"scores":' | grep -o '"grantedPoints":[[:space:]]*[0-9]*' | head -1 | grep -o '[0-9]*' || echo "")
  [ -z "$GRANTED_POINTS" ] && GRANTED_POINTS=$(echo "$PANA_JSON" | grep -o '"grantedPoints":[[:space:]]*[0-9]*' | tail -1 | grep -o '[0-9]*' || echo "0")
  MAX_POINTS=$(echo "$PANA_JSON" | grep -A 3 '"scores":' | grep -o '"maxPoints":[[:space:]]*[0-9]*' | head -1 | grep -o '[0-9]*' || echo "")
  [ -z "$MAX_POINTS" ] && MAX_POINTS=$(echo "$PANA_JSON" | grep -o '"maxPoints":[[:space:]]*[0-9]*' | tail -1 | grep -o '[0-9]*' || echo "0")
fi

echo "[verify_pana] Pana Score: $GRANTED_POINTS / $MAX_POINTS points"

if [ "$GRANTED_POINTS" -lt 140 ]; then
  echo "[verify_pana] ERROR: Pana score ($GRANTED_POINTS) fell below required 140 point floor!"
  $PANA_BIN . || true
  exit 1
fi

echo "=========================================================="
echo " [verify_pana] SUCCESS: Packaging and quality verification passed (Score: $GRANTED_POINTS / $MAX_POINTS)!"
echo "=========================================================="
