#!/usr/bin/env bash
# ManLife headless 測試(Linux / macOS / Git Bash 版的 run_tests.ps1):先 --import,再依檔名順序跑 tests/verify_*.tscn;
# 任一個失敗就 exit 1。每個測試最多 10 分鐘(測試場景編譯失敗時 headless 不會自己結束)。
# 用法:bash tools/run_tests.sh [--no-import]
# Godot 路徑用環境變數 GODOT,預設 ~/godot/godot(tools/setup_cloud.sh 裝的)。
set -u
GODOT="${GODOT:-$HOME/godot/godot}"
if [ ! -x "$GODOT" ]; then
    echo "Godot not found: $GODOT (set env GODOT, or run: bash tools/setup_cloud.sh)"
    exit 2
fi
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
if [ "${1:-}" != "--no-import" ]; then
    "$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1
fi
failed=0
for scene in $(ls "$PROJ"/tests/verify_*.tscn 2>/dev/null | sort); do
    name="$(basename "$scene")"
    timeout 600 "$GODOT" --headless --path "$PROJ" "res://tests/$name"
    if [ $? -ne 0 ]; then
        failed=1
        echo "FAILED: $name"
    fi
done
if [ $failed -ne 0 ]; then
    echo "TESTS FAILED"
    exit 1
fi
echo "ALL TESTS PASSED"
exit 0
