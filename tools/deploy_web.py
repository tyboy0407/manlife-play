"""匯出網頁版並推到 GitHub Pages(原始碼與網頁成品同一個 repo:tyboy0407/manlife-play,Pages 從 main 的 docs/ 發布)。
用法:python tools/deploy_web.py [--export-only] [--no-export] [--no-push] [--message "..."]
需要:Godot 4.7(環境變數 GODOT;Windows 預設桌面的 console exe、Linux 預設 ~/godot/godot = tools/setup_cloud.sh 裝的)、
      已安裝 4.7 的 Web 匯出模板(Linux:bash tools/setup_cloud.sh --templates)、本 repo 的 origin 指到 GitHub 且有 push 權限。
流程:godot --headless --export-release Web build/web/index.html
   -> docs/ 清掉舊檔、複製 build/web、加 .nojekyll(Pages 不走 Jekyll)與 .gdignore(Godot 不匯入成品)
   -> 只 commit docs/(其他未提交的改動不會被掃進去)-> push origin main。推完約一分鐘生效,網址 https://tyboy0407.github.io/manlife-play/。
"""
import argparse
import datetime
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB = os.path.join(ROOT, "build", "web")
DOCS = os.path.join(ROOT, "docs")
SITE = "https://tyboy0407.github.io/manlife-play/"


def godot_exe():
    exe = os.environ.get("GODOT")
    if exe and os.path.isfile(exe):
        return exe
    home = os.path.expanduser("~")
    for cand in (
        os.path.join(home, "OneDrive", "桌面", "Godot_v4.7-stable_win64.exe", "Godot_v4.7-stable_win64_console.exe"),
        os.path.join(home, "godot", "godot"),
    ):
        if os.path.isfile(cand):
            return cand
    raise SystemExit("找不到 Godot,請設環境變數 GODOT(Windows:4.7 的 console exe;Linux:bash tools/setup_cloud.sh)")


def run(cmd, cwd=None, check=True):
    print("$", " ".join(cmd))
    return subprocess.run(cmd, cwd=cwd, check=check)


def export_web():
    os.makedirs(WEB, exist_ok=True)
    with open(os.path.join(os.path.dirname(WEB), ".gdignore"), "w") as f:
        f.write("")   # build/ 裡的成品不要被 Godot 匯入(不然 PNG 會多出 .import 與 UID 重複警告)
    run([godot_exe(), "--headless", "--path", ROOT, "--export-release", "Web", os.path.join(WEB, "index.html")])
    for name in ("index.html", "index.js", "index.wasm", "index.pck"):
        if not os.path.isfile(os.path.join(WEB, name)):
            raise SystemExit("匯出失敗:缺 %s(匯出模板裝了嗎?)" % name)
    total = sum(os.path.getsize(os.path.join(WEB, f)) for f in os.listdir(WEB))
    print("匯出完成:%d 個檔案,共 %.1f MB" % (len(os.listdir(WEB)), total / 1e6))


def sync_docs(message, push):
    if not os.path.isfile(os.path.join(WEB, "index.html")):
        raise SystemExit("build/web 沒有匯出成品,先跑一次匯出")
    os.makedirs(DOCS, exist_ok=True)
    for name in os.listdir(DOCS):
        path = os.path.join(DOCS, name)
        if os.path.isdir(path):
            shutil.rmtree(path)
        else:
            os.remove(path)
    for name in os.listdir(WEB):
        if name.endswith(".import"):
            continue
        shutil.copy2(os.path.join(WEB, name), os.path.join(DOCS, name))
    for marker in (".nojekyll", ".gdignore"):
        with open(os.path.join(DOCS, marker), "w") as f:
            f.write("")
    run(["git", "add", "-A", "docs"], cwd=ROOT)
    status = subprocess.run(["git", "status", "--porcelain", "docs"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    if not status:
        print("docs/ 內容沒變,不用推")
        return
    run(["git", "-c", "core.autocrlf=false", "commit", "-q", "-m", message, "--", "docs"], cwd=ROOT)
    if not push:
        print("已 commit docs/(--no-push,沒推)")
        return
    run(["git", "push", "origin", "HEAD:main"], cwd=ROOT)
    print("已推送。網址:%s(約一分鐘後更新;iPhone 上的 App 重開一次會換新版)" % SITE)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--export-only", action="store_true", help="只匯出,不動 docs/")
    ap.add_argument("--no-export", action="store_true", help="不匯出,直接用 build/web 現有內容更新 docs/")
    ap.add_argument("--no-push", action="store_true", help="更新 docs/ 並 commit,但不 push")
    ap.add_argument("--message", default=None)
    args = ap.parse_args()
    if not args.no_export:
        export_web()
    if args.export_only:
        return
    message = args.message or "Deploy %s" % datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    sync_docs(message, not args.no_push)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as e:
        sys.exit("指令失敗(exit %d):%s" % (e.returncode, " ".join(e.cmd)))
