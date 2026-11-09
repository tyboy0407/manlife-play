# -*- coding: utf-8 -*-
"""把 assets/sfx/patches/*.json 算成 assets/sfx/<name>.wav(遊戲載入的音效)。

合成器與檢查器是 game-sfx skill(GhazaGG/Game-Sound-Effect-for-Claude,MIT)的 sfx.py / doctor.py,放在 tools/sfx_synth/(純 Python 標準庫)。
每個 patch 算完都會印 doctor 報告(peak / LUFS / 亮度 / 問題);要看頻譜圖加 --png(PNG 寫到 build/sfx_preview/)。

    python tools/render_sfx.py            # 全部
    python tools/render_sfx.py coin hit   # 只算這幾個
    python tools/render_sfx.py --png      # 另外輸出頻譜圖到 build/sfx_preview/
音效的設計原則與決策記在 assets/sfx/SOUND_STYLE.md;改聲音就改 patch 再重算,檔名不變,程式不用動。
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATCHES = os.path.join(ROOT, "assets", "sfx", "patches")
OUT = os.path.join(ROOT, "assets", "sfx")
SYNTH = os.path.join(ROOT, "tools", "sfx_synth", "sfx.py")
PREVIEW = os.path.join(ROOT, "build", "sfx_preview")


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    png = "--png" in sys.argv
    names = sorted(f[:-5] for f in os.listdir(PATCHES) if f.endswith(".json"))
    if args:
        names = [n for n in names if n in args]
    failed = 0
    for n in names:
        patch = os.path.join(PATCHES, n + ".json")
        cmd = [sys.executable, "-I", SYNTH, patch, "-o", OUT]
        r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
        print(r.stdout.strip())
        if r.returncode != 0 or "FAIL" in r.stdout:
            failed += 1
            print(r.stderr.strip())
        if png:
            os.makedirs(PREVIEW, exist_ok=True)
            subprocess.run([sys.executable, "-I", SYNTH, patch, "-o", PREVIEW, "--png"], capture_output=True, text=True)
    print("rendered %d patches, %d with problems" % (len(names), failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
