# ManLife

新遊戲,2026-10-25 建立空專案。引擎 Godot 4.7 標準版(非 .NET),GDScript。
玩法與方向尚未定義:開工前先跟使用者討論(使用者習慣開放三個問題、以編號回答),確認後再實作。

## 工作方式

- 型別化 GDScript,4 空白縮排。純規則類別放 `core/`(RefCounted,不依賴 Node / 場景 / Autoload,可 headless 測試);場景與節點放 `game/`;全域單例放 `autoload/`;數值資料放 `data/`(JSON / CSV)。
- 程式與資料鍵英文;遊戲內文字繁中,走 `data/locale/strings.csv` + `tr()`;新 UI 文字先加進 CSV 再用。
- 規則函式回傳 `{"ok", "reason"(代碼), "args"}`,UI 用 `tr("<前綴>_REASON_<代碼>")` 翻譯。
- 每個系統:討論 -> 定案 -> 實作 -> 跑全部測試 -> commit。里程碑與定案記在本檔。

## 測試

```
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1
```

先 `godot --headless --path . --import`,再依檔名順序跑 `tests/verify_*.tscn`;每個測試場景自己 print `OK` / `FAIL` 並用 exit code 回報。Godot 路徑預設是桌面上的 4.7 console exe,可用環境變數 `GODOT` 覆蓋。

- 新增腳本或資源後要先 `--import`,否則 class_name 找不到。
- 測試指令一定加 timeout:測試場景若編譯失敗,headless 永遠不會結束。

## 踩過的坑(上一個專案留下的)

- Bash 工具單次指令超過約 5KB 會被截斷:大檔用 Write 工具寫。
- Godot 編輯器預設「存檔時轉換縮排」成 Tab:使用者在編輯器裡存過的腳本可能整檔變 Tab;改檔前先看縮排,同一檔不能混用,commit 前統一回 4 空白(或請使用者把編輯器設定改成空格)。
- Area2D 子類別不能宣告叫 `gravity` 的變數(與內建屬性撞名)。
- 用 `.new()` 建、直接加在 CanvasLayer 下的 Control 要用 `set_anchors_and_offsets_preset(PRESET_FULL_RECT)` 鋪滿。
- 換場景會把整個舊場景 memdelete:UI 關閉回呼用 `tree_exiting`,不要用 `tree_exited`。

## 里程碑

(尚未開始)
