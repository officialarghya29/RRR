#!/usr/bin/env bash
# Verification gate for Prince of Persia: Echoes of Time.
#
# Downloads a headless Godot build on first use, then:
#   1. imports the project (surfaces script/scene errors)
#   2. boots every level headless (surfaces runtime errors, warnings and leaks)
#   3. runs the assertion suite in tests/
#
# Usage:  ./verify.sh
# Exits non-zero if anything fails, so it can be used as a CI step.

set -uo pipefail

GODOT_VERSION="4.7.2-stable"
GODOT_DIR=".tools"
GODOT_BIN="${GODOT_DIR}/godot"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
GODOT_INNER="Godot_v${GODOT_VERSION}_linux.x86_64"

# Godot download hosts break on HTTP/2 over some networks; HTTP/1.1 is reliable.
CURL_OPTS=(--http1.1 --ipv4 -L --retry 4 --retry-delay 2 --retry-all-errors)

failures=0

ensure_godot() {
  if [[ -x "${GODOT_BIN}" ]]; then
    return 0
  fi
  echo "==> Fetching Godot ${GODOT_VERSION} (one-time, ~75 MB)"
  mkdir -p "${GODOT_DIR}"
  curl "${CURL_OPTS[@]}" -o "${GODOT_DIR}/godot.zip" "${GODOT_URL}" || return 1
  python3 -c "import zipfile;zipfile.ZipFile('${GODOT_DIR}/godot.zip').extractall('${GODOT_DIR}')" || return 1
  mv "${GODOT_DIR}/${GODOT_INNER}" "${GODOT_BIN}" || return 1
  chmod +x "${GODOT_BIN}"
  rm -f "${GODOT_DIR}/godot.zip"
}

if ! ensure_godot; then
  echo "FATAL: could not obtain a Godot binary. Place one at ${GODOT_BIN} manually." >&2
  exit 2
fi

echo "==> Godot: $("${GODOT_BIN}" --headless --version)"

echo "==> 1/3 Importing project"
import_out="$(timeout 300 "${GODOT_BIN}" --headless --path . --import 2>&1)"
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load" <<<"${import_out}"; then
  echo "${import_out}" | grep -E "SCRIPT ERROR|Parse Error|Failed to load"
  echo "FAIL: import reported script errors"
  failures=$((failures + 1))
else
  echo "    ok"
fi

echo "==> 2/3 Booting levels headless (plan B0.1: sim path + legacy path)"
level_count="$(python3 - <<'PY'
import re, pathlib
src = pathlib.Path("data/levels/level_catalog.gd").read_text()
body = src.split("static func count()", 1)[1]
print(re.search(r"return\s+(\d+)", body).group(1))
PY
)"
sim_count="$(python3 - <<'PY'
import re, pathlib
src = pathlib.Path("data/levels/level_catalog.gd").read_text()
body = src.split("static func sim_count()", 1)[1]
print(re.search(r"return\s+(\d+)", body).group(1))
PY
)"
# Sim path (default): boots the room-grid levels on PopSim via SimWorld.
for ((i = 1; i <= sim_count; i++)); do
  boot_out="$(timeout 180 "${GODOT_BIN}" --headless --path . --quit-after 400 -- "--level=${i}" 2>&1)"
  if grep -qE "SCRIPT ERROR|Parse Error|leaked|still in use" <<<"${boot_out}"; then
    echo "${boot_out}" | grep -E "SCRIPT ERROR|Parse Error|leaked|still in use"
    echo "FAIL: sim level ${i} booted dirty"
    failures=$((failures + 1))
  else
    echo "    sim level ${i} ok (${sim_count} total)"
  fi
done
# Legacy path (--legacy-physics): the original physics stack, video fallback.
for ((i = 1; i <= level_count; i++)); do
  boot_out="$(timeout 180 "${GODOT_BIN}" --headless --path . --quit-after 400 -- "--legacy-physics" "--level=${i}" 2>&1)"
  if grep -qE "SCRIPT ERROR|Parse Error|leaked|still in use" <<<"${boot_out}"; then
    echo "${boot_out}" | grep -E "SCRIPT ERROR|Parse Error|leaked|still in use"
    echo "FAIL: legacy level ${i} booted dirty"
    failures=$((failures + 1))
  else
    echo "    legacy level ${i} ok (${level_count} total)"
  fi
done

echo "==> 3/3 Running test suite"
test_out="$(timeout 300 "${GODOT_BIN}" --headless --path . res://tests/test_main.tscn 2>&1)"
test_code=$?
grep -E "PASS|FAIL|passed," <<<"${test_out}" | sed 's/^/    /'
if [[ ${test_code} -ne 0 ]]; then
  echo "FAIL: test suite exited ${test_code}"
  failures=$((failures + 1))
fi

# Session 012 step 3: kid-death timings (echo/shield state around a death).
step3_out="$(timeout 300 "${GODOT_BIN}" --headless --path . res://tests/test_step3_kid_death.tscn 2>&1)"
step3_code=$?
grep -E "PASS|FAIL|passed," <<<"${step3_out}" | sed 's/^/    /'
if [[ ${step3_code} -ne 0 ]]; then
  echo "FAIL: step-3 death-timing suite exited ${step3_code}"
  failures=$((failures + 1))
fi

# Session 012 step 4: whole-flow (title/controls/credits, L1-L3, victory).
flow_out="$(timeout 300 "${GODOT_BIN}" --headless --path . res://tests/test_game_flow.tscn 2>&1)"
flow_code=$?
grep -E "PASS|FAIL|passed," <<<"${flow_out}" | sed 's/^/    /'
if [[ ${flow_code} -ne 0 ]]; then
  echo "FAIL: game-flow suite exited ${flow_code}"
  failures=$((failures + 1))
fi

echo
if [[ ${failures} -eq 0 ]]; then
  echo "ALL CHECKS PASSED"
  exit 0
fi
echo "${failures} check(s) FAILED"
exit 1
