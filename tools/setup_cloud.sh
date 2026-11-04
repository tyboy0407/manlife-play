#!/usr/bin/env bash
# 在雲端 / Linux 環境裝 Godot 4.7(headless 跑測試、匯出網頁版用),並先把專案匯入一次。
# 用法:bash tools/setup_cloud.sh [--templates]
#   --templates:另外下載 Web 匯出模板(整包 tpz 約 1 GB,只解 web_* 與 version.txt),要在雲端跑 tools/deploy_web.py 才需要。
# 裝到 $GODOT_DIR(預設 ~/godot),執行檔是 ~/godot/godot;tools/run_tests.sh 與 deploy_web.py 預設就會找這個路徑。
# 在 claude.ai/code 的環境設定(setup / 啟動指令)填:bash tools/setup_cloud.sh
set -euo pipefail
VER="4.7-stable"
DIR="${GODOT_DIR:-$HOME/godot}"
BASE="https://github.com/godotengine/godot/releases/download/$VER"
mkdir -p "$DIR"
if [ ! -x "$DIR/godot" ]; then
    echo "下載 Godot $VER (Linux x86_64)..."
    curl -fsSL -o "$DIR/godot.zip" "$BASE/Godot_v${VER}_linux.x86_64.zip"
    (cd "$DIR" && unzip -oq godot.zip && mv -f "Godot_v${VER}_linux.x86_64" godot && chmod +x godot && rm -f godot.zip)
fi
"$DIR/godot" --headless --version
if [ "${1:-}" = "--templates" ]; then
    TDIR="$HOME/.local/share/godot/export_templates/${VER/-/.}"   # 4.7.stable
    if [ ! -f "$TDIR/version.txt" ]; then
        echo "下載匯出模板(約 1 GB)..."
        curl -fsSL -o "$DIR/templates.tpz" "$BASE/Godot_v${VER}_export_templates.tpz"
        mkdir -p "$TDIR"
        (cd "$DIR" && unzip -oq templates.tpz 'templates/web_*' 'templates/version.txt' && mv -f templates/* "$TDIR/" && rmdir templates && rm -f templates.tpz)
    fi
    ls "$TDIR"
fi
# 匯入專案(第一次會因為翻譯 / 字型還沒產生而印錯誤,再跑一次就乾淨;build/ 與 docs/ 裡有 .gdignore 不會被掃)
cd "$(dirname "$0")/.."
mkdir -p build && touch build/.gdignore
"$DIR/godot" --headless --path . --import >/dev/null 2>&1 || true
"$DIR/godot" --headless --path . --import >/dev/null 2>&1 || true
echo "完成。GODOT=$DIR/godot(測試:bash tools/run_tests.sh;單跑一個:$DIR/godot --headless --path . res://tests/verify_core.tscn)"
