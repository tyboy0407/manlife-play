# ManLife

休閒閒置經營(Arcade Idle)原型:搖桿走路、身上疊貨、站上格子自動互動。參考 2026-10-25 的影片(Whiteout Survival 廣告裡的
雪地漁市小遊戲):抓魚 -> 切魚台加工 -> 櫃台賣給排隊顧客 -> 收錢 -> 站在價格牌上付錢解鎖(僱幫手 / 升級 / 擴建)-> 幫手自動化。
引擎 Godot 4.7 標準版(非 .NET),GDScript,3D 方塊占位 + 等角俯視;PC 先行(鍵盤 / 手把),之後加觸控虛擬搖桿。

## 已定案(2026-10-25)

- 1a 3D 低多邊形占位、等角俯視相機;2a PC 鍵盤 WASD / 方向鍵 / 手把左搖桿先行,輸入抽成 MoveInput 之後加虛擬搖桿;
  3a 先照影片的雪地漁市主題做原型,機制穩了再換皮。
- 使用者習慣:每個系統先開放三個問題、以編號回答,確認後再實作;每個里程碑跑全部測試再 commit。

## 工作方式

- 型別化 GDScript,4 空白縮排。純規則類別放 `core/`(RefCounted,不依賴 Node / 場景 / Autoload,可 headless 測試);場景與節點放 `game/`;全域單例放 `autoload/`;數值資料放 `data/`(JSON / CSV)。
- 程式與資料鍵英文;遊戲內文字繁中,走 `data/locale/strings.csv` + `tr()`;新 UI 文字先加進 CSV 再用。
- 關卡用程式碼擺放(座標在關卡腳本),規則與數值在 `data/`;改數值不用動程式。
- 每個系統:討論 -> 定案 -> 實作 -> 跑全部測試 -> commit。里程碑與定案記在本檔。

## 目錄

- `core/data/game_data.gd`:GameData(靜態載入 game.json / items.json / stations.json / shop.json,物品尺寸 / 顏色 / 翻譯名)
- `core/economy/`:ItemStack(一疊同種物品,有容量)、StationLogic(輸入堆 -> 處理 -> 輸出堆,輸出滿停工)、PurchaseLogic(價格牌分期)、CounterLogic(庫存 / 售價 / 賣出)
- `core/input/move_input.gd`:MoveInput(螢幕方向 -> 世界 XZ;from_actions 鍵盤手把、toward 合成輸入)
- `game/common/`:Carrier(CharacterBody3D 浮動模式、背上 ItemStack + StackVisual、旗標 can_fish / takes_output / collects_cash)、StackVisual(疊方塊,columns 排列)、VisualFactory(方塊 / 膠囊 / 圓柱 / Label3D 與材質快取)
- `game/player/player.gd`:Player(input_provider 可餵合成輸入;容量 = 設定 + GameState.capacity_bonus)
- `game/npc/`:Helper(漁夫 AI:水裡漫游被抓魚 -> 滿了去輸入格卸貨)、Customer(走到排隊位、等、買完離開,無物理)
- `game/world/`:Pad(Area3D 基底,每幀對站著的 Carrier 呼叫 _on_carrier_stay,_budget 速率累加器)、StationPad(輸入 / 輸出)、Station(桌子 + 工人 + 兩格 + 兩堆)、FishArea(淺水區生魚、靠近自動捕獲、最近的魚發黃光)、Fish、Counter(上架格 + 排隊位 + 顧客生成與結帳)、CounterPad、MoneyPad(現金堆,收錢的 carrier 站上來搬走)、PricePad(付清 -> GameState.apply_purchase;buildSpot 橘色建地)
- `game/camera/follow_camera.gd`:跟隨相機(從 +Z 側俯視,螢幕上 = 世界 -Z)
- `game/ui/hud.gd`:背上內容 / 統計 / 通知 / 操作提示
- `game/levels/harbor.gd` + `harbor.tscn`(主場景):星港漁市,座標常數 STATION_SPOTS / PAD_SPOTS,聽 purchased 生幫手與第二座切魚台
- `autoload/event_bus.gd`:fish_caught / items_processed / sale_made / cash_collected / purchase_progress / purchased / helper_hired / notice
- `autoload/game_state.gd`:capacity_bonus / unlocked / hired / 統計;apply_purchase(effect type:capacity / hire / unlock)。不存檔(待做)
- `data/config/game.json`:速度、容量、搬運速率、魚群、顧客、櫃台;`data/items.json`;`data/stations.json`;`data/shop.json`;`data/locale/strings.csv`

## 世界慣例

- 平面世界:Carrier 用 MOTION_MODE_FLOATING,不算重力;物理層 1 地形(隱形牆)、2 Carrier(玩家 / 幫手互相穿過)。格子與水區是 Area3D,mask 只看層 2。顧客與魚沒有物理。
- 面向:Carrier local +Z 是前方(rotation.y = atan2(dir.x, dir.z)),背上堆疊在 -Z。
- 格子互動都是「站上去就自動」:速率 transferPerSec / cashPickupPerSec / payPerSec,`Pad._budget` 累加器最多多攢 1 件。
- 價格牌付清:`set_deferred("monitoring", false)` + `set_physics_process(false)`(monitoring 關掉後再查重疊會報錯,Pad._physics_process 也有保護)。
- 新站點 / 新購買:加 JSON + 在 harbor.gd 的 SPOTS 給座標;效果型別新增要同時改 GameState.apply_purchase 與 Harbor._on_purchased。

## 測試

```
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1
```

先 `godot --headless --path . --import`,再依檔名順序跑 `tests/verify_*.tscn`:`verify_core`(資料 / ItemStack / StationLogic / PurchaseLogic / CounterLogic / MoveInput)、`verify_world`(3D 整合:建關卡 -> 抓魚到滿 -> 卸貨 -> 切 -> 取魚片 -> 上架 -> 顧客買 -> 撿錢 -> 分期付款僱漁夫 -> 漁夫自己抓魚卸貨 -> 擴充背包 -> 增建切魚台,約 60 秒)。Godot 路徑預設是桌面上的 4.7 console exe,可用環境變數 `GODOT` 覆蓋。

- 新增腳本或資源後要先 `--import`,否則 class_name 找不到;第一次 import 會因為 .translation 還沒產生而印錯誤,第二次就正常。
- 測試指令一定加 timeout:測試場景若編譯失敗,headless 永遠不會結束。

## 踩過的坑

- Bash 工具單次指令超過約 5KB 會被截斷:大檔用 Write 工具寫。
- Godot 編輯器預設「存檔時轉換縮排」成 Tab:使用者在編輯器裡存過的腳本可能整檔變 Tab;改檔前先看縮排,同一檔不能混用,commit 前統一回 4 空白。
- Area2D / Area3D 子類別不能宣告叫 `gravity` 的變數(與內建屬性撞名)。
- `Array.filter()` 回傳無型別陣列,不能直接指派給 `Array[T]` 變數(用無型別變數或 `assign`)。
- 用 `.new()` 建、直接加在 CanvasLayer 下的 Control 要用 `set_anchors_and_offsets_preset(PRESET_FULL_RECT)` 鋪滿。
- 換場景會把整個舊場景 memdelete:UI 關閉回呼用 `tree_exiting`,不要用 `tree_exited`。

## 里程碑

1. 垂直切片(完成 2026-10-25):搖桿移動 + 背上堆疊、淺水區抓魚、切魚台(輸入格 / 工人 / 輸出格)、櫃台 + 排隊顧客 + 錢格、三塊價格牌(僱漁夫 $10 / 擴充背包 $25 / 增建切魚台 $50,分期付款)、漁夫幫手 AI、HUD、資料驅動 JSON、兩套 headless 測試。

之後候選:存檔與離線收益、更多站點與貨物鏈(烤魚 / 魚湯)、更多幫手角色(搬運工 / 收銀)、升級(工人速度、堆疊上限)、觸控虛擬搖桿與手機匯出、換皮與美術。
