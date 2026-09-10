#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/checks
touch build/.gdignore
burns_godot="${GODOT:-godot}"
"$burns_godot" --headless --path . --editor --import --quit > build/checks/import.log 2>&1
if grep -nE 'SCRIPT ERROR|Parse Error|ERROR:' build/checks/import.log; then
  exit 1
fi
for test_script in test_deck test_game test_ui test_drag test_art test_presentation test_room_storage test_bot_pacing; do
  if [ ! -f "tests/${test_script}.gd" ]; then
    echo "MISSING: tests/${test_script}.gd is listed in check.sh but not present" >&2
    exit 1
  fi
  "$burns_godot" --headless --path . --script "tests/${test_script}.gd" 2>&1 | tee "build/checks/${test_script}.log"
  if grep -nE 'SCRIPT ERROR|Parse Error|ERROR:' "build/checks/${test_script}.log"; then
    exit 1
  fi
done
