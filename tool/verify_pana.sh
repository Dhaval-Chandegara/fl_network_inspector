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

# 2. Ensure pana CLI is available (support custom PUB_CACHE)
PUB_CACHE_DIR="${PUB_CACHE:-$HOME/.pub-cache}"
export PATH="$PUB_CACHE_DIR/bin:$PATH"

if ! command -v pana >/dev/null 2>&1; then
  if ! dart pub global list 2>/dev/null | grep -q pana; then
    echo "[verify_pana] Activating pana CLI from pub.dev..."
    dart pub global activate pana >/dev/null 2>&1 || {
      echo "[verify_pana] WARNING: Failed to activate pana globally (check network reachability to pub.dev)."
    }
  fi
fi

PANA_BIN="pana"
if ! command -v "$PANA_BIN" >/dev/null 2>&1; then
  PANA_BIN="dart pub global run pana:pana"
fi

# 3. Execute pana scoring analysis
echo "[verify_pana] Step 2: Running pana package analysis..."
PANA_ERR_FILE="$(mktemp "${TMPDIR:-/tmp}/pana_err_XXXXXX")"
PANA_JSON="$($PANA_BIN --json . 2>"$PANA_ERR_FILE" || true)"

if [ -z "$PANA_JSON" ]; then
  echo "[verify_pana] WARNING: Pana analysis failed to produce JSON output."
  if [ -s "$PANA_ERR_FILE" ]; then
    echo "[verify_pana] Pana error output:"
    cat "$PANA_ERR_FILE"
  fi
  rm -f "$PANA_ERR_FILE"
  echo "[verify_pana] ERROR: Could not retrieve pana scoring report (check network reachability to pub.dev)."
  exit 1
fi
rm -f "$PANA_ERR_FILE"

# Extract granted points and max points directly from JSON
if command -v dart >/dev/null 2>&1; then
  read -r GRANTED_POINTS MAX_POINTS < <(dart run -e '
    import "dart:convert";
    import "dart:io";
    void main(List<String> args) {
      try {
        final d = jsonDecode(args[0]);
        final granted = d["scores"]?["grantedPoints"] ?? d["grantedPoints"] ?? 0;
        final max = d["scores"]?["maxPoints"] ?? d["maxPoints"] ?? 0;
        print("$granted $max");
      } catch (_) {
        print("0 0");
      }
    }
  ' "$PANA_JSON" 2>/dev/null || echo "0 0")
elif command -v node >/dev/null 2>&1; then
  read -r GRANTED_POINTS MAX_POINTS < <(node -e '
    try {
      const d = JSON.parse(process.argv[1]);
      const granted = d.scores?.grantedPoints ?? d.grantedPoints ?? 0;
      const max = d.scores?.maxPoints ?? d.maxPoints ?? 0;
      console.log(`${granted} ${max}`);
    } catch {
      console.log("0 0");
    }
  ' "$PANA_JSON" 2>/dev/null || echo "0 0")
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
