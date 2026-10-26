"""匯出網頁版並推到 GitHub Pages。
用法:python tools/deploy_web.py [--export-only] [--no-export] [--repo tyboy0407/manlife-play] [--message "..."]
需要:Godot 4.7 console exe(環境變數 GODOT,或桌面預設路徑)、已安裝 4.7 匯出模板、gh 已登入。
流程:godot --headless --export-release Web build/web/index.html
   -> build/pages(Pages repo 的 clone,沒有就 clone)清掉舊檔、複製 build/web、加 .nojekyll
   -> commit -> push main。Pages 設定成從 main 根目錄發佈,推完約一分鐘生效。
"""
import argparse
import datetime
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB = os.path.join(ROOT, "build", "web")
PAGES = os.path.join(ROOT, "build", "pages")
DEFAULT_REPO = "tyboy0407/manlife-play"


def godot_exe():
    exe = os.environ.get("GODOT")
    if exe and os.path.isfile(exe):
        return exe
    desktop = os.path.join(os.path.expanduser("~"), "OneDrive", "桌面")
    cand = os.path.join(desktop, "Godot_v4.7-stable_win64.exe", "Godot_v4.7-stable_win64_console.exe")
    if os.path.isfile(cand):
        return cand
    raise SystemExit("找不到 Godot,請設環境變數 GODOT 指向 4.7 的 console exe")


def run(cmd, cwd=None, check=True):
    print("$", " ".join(cmd))
    return subprocess.run(cmd, cwd=cwd, check=check)


def git_identity():
    """Pages 的 clone 是新 repo,沒有 commit 身分;沿用本專案 repo 設定的 user.name / user.email。"""
    out = []
    for key, fallback in (("user.name", "ManLife deploy"), ("user.email", "deploy@manlife.local")):
        r = subprocess.run(["git", "-C", ROOT, "config", key], capture_output=True, text=True)
        value = r.stdout.strip() or fallback
        out += ["-c", "%s=%s" % (key, value)]
    return out


def export_web():
    os.makedirs(WEB, exist_ok=True)
    run([godot_exe(), "--headless", "--path", ROOT, "--export-release", "Web", os.path.join(WEB, "index.html")])
    for name in ("index.html", "index.js", "index.wasm", "index.pck"):
        if not os.path.isfile(os.path.join(WEB, name)):
            raise SystemExit("匯出失敗:缺 %s(匯出模板裝了嗎?)" % name)
    total = sum(os.path.getsize(os.path.join(WEB, f)) for f in os.listdir(WEB))
    print("匯出完成:%d 個檔案,共 %.1f MB" % (len(os.listdir(WEB)), total / 1e6))


def sync_pages(repo, message):
    if not os.path.isdir(os.path.join(PAGES, ".git")):
        os.makedirs(os.path.dirname(PAGES), exist_ok=True)
        run(["gh", "repo", "clone", repo, PAGES])
    for name in os.listdir(PAGES):
        if name == ".git":
            continue
        path = os.path.join(PAGES, name)
        if os.path.isdir(path):
            shutil.rmtree(path)
        else:
            os.remove(path)
    for name in os.listdir(WEB):
        shutil.copy2(os.path.join(WEB, name), os.path.join(PAGES, name))
    with open(os.path.join(PAGES, ".nojekyll"), "w") as f:
        f.write("")
    run(["git", "add", "-A"], cwd=PAGES)
    status = subprocess.run(["git", "status", "--porcelain"], cwd=PAGES, capture_output=True, text=True).stdout.strip()
    if not status:
        print("Pages 內容沒變,不用推")
        return
    run(["git", "-c", "core.autocrlf=false"] + git_identity() + ["commit", "-q", "-m", message], cwd=PAGES)
    run(["git", "push", "origin", "HEAD:main"], cwd=PAGES)
    owner, name = repo.split("/")
    print("已推送。網址:https://%s.github.io/%s/(約一分鐘後更新;iPhone 上的 App 重開一次會換新版)" % (owner, name))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--export-only", action="store_true", help="只匯出,不推")
    ap.add_argument("--no-export", action="store_true", help="不匯出,直接推 build/web 現有內容")
    ap.add_argument("--repo", default=DEFAULT_REPO)
    ap.add_argument("--message", default=None)
    args = ap.parse_args()
    if not args.no_export:
        export_web()
    if args.export_only:
        return
    message = args.message or "Deploy %s" % datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    sync_pages(args.repo, message)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as e:
        sys.exit("指令失敗(exit %d):%s" % (e.returncode, " ".join(e.cmd)))
