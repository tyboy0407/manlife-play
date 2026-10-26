# ManLife

休閒閒置經營(Arcade Idle)原型:搖桿走路、身上疊貨、站上格子自動互動。參考 2026-10-25 的影片(Whiteout Survival 廣告裡的
雪地漁市小遊戲):抓魚 -> 切魚台加工 -> 櫃台賣給排隊顧客 -> 收錢 -> 站在價格牌上付錢解鎖(僱幫手 / 升級 / 擴建)-> 幫手自動化。
引擎 Godot 4.7 標準版(非 .NET),GDScript,3D 方塊占位 + 等角俯視;PC 先行(鍵盤 / 手把),之後加觸控虛擬搖桿。

## 已定案

- 2026-10-25:1a 3D 低多邊形占位、等角俯視相機;2a PC 鍵盤 WASD / 方向鍵 / 手把左搖桿先行,輸入抽成 MoveInput 之後加虛擬搖桿;
  3a 先照影片的雪地漁市主題做原型,機制穩了再換皮。
- 2026-10-26(里程碑 2,使用者直接點名五個功能,沒開問題,設計由我定):櫃台要有人站在「收銀格」才賣(玩家或收銀員);
  垃圾桶丟掉身上所有東西(含現金,免得零錢卡手);可重複購買的價格牌每次漲價(cost × costMult^buys、maxBuys 次),
  付清後要走開再踏上才開始付下一次;升級用 GameState.upgrade_mult(1 + perLevel × 等級)乘在工人速度 / 堆疊上限;
  存檔 = GameState.to_dict + Harbor.snapshot,每 10 秒 / 購買後 / 關視窗自動存,F9 重新開始。
- 2026-10-26(使用者要求):現金改錢包(GameState.wallet),不佔背包;錢格的錢收進錢包、價格牌從錢包扣。
  我加的配套:價格牌要站著 payDelaySec(0.6 秒)才開始付,帶著錢走過不會付;存檔版本升到 2(舊檔忽略)。
- 使用者習慣:每個系統先開放三個問題、以編號回答,確認後再實作;每個里程碑跑全部測試再 commit。

## 工作方式

- 型別化 GDScript,4 空白縮排。純規則類別放 `core/`(RefCounted,不依賴 Node / 場景 / Autoload,可 headless 測試);場景與節點放 `game/`;全域單例放 `autoload/`;數值資料放 `data/`(JSON / CSV)。
- 程式與資料鍵英文;遊戲內文字繁中,走 `data/locale/strings.csv` + `tr()`;新 UI 文字先加進 CSV 再用。CSV 裡的換行寫字面 `\n`(匯入時 c_unescape),不要放真的換行。
- 關卡用程式碼擺放(座標在關卡腳本),規則與數值在 `data/`;改數值不用動程式。
- 每個系統:討論 -> 定案 -> 實作 -> 跑全部測試 -> commit。里程碑與定案記在本檔。

## 目錄

- `core/data/game_data.gd`:GameData(靜態載入 game.json / items.json / stations.json / counters.json / shop.json;`section(key)`、`helper(role)`、物品尺寸 / 顏色 / 翻譯名)
- `core/economy/`:ItemStack(一疊同種物品,有容量)、StationLogic(輸入堆 -> 處理 -> 輸出堆,輸出滿停工,speed_mult)、PurchaseLogic(價格牌分期;repeatable / max_buys / cost_mult / buys,`complete()` 漲價、`restore()` 存檔還原)、CounterLogic(庫存 / 售價 / 賣出)
- `core/input/move_input.gd`:MoveInput(螢幕方向 -> 世界 XZ;from_actions 鍵盤手把、toward 合成輸入)
- `game/common/`:Carrier(CharacterBody3D 浮動模式、背上 ItemStack + StackVisual、旗標 can_fish / takes_output / collects_cash / can_serve / can_use_trash)、StackVisual、VisualFactory
- `game/player/player.gd`:Player(input_provider 可餵合成輸入;容量 = 設定 + GameState.capacity_bonus;can_serve / can_use_trash)
- `game/npc/helper.gd`:Helper(role 決定狀態機:fisher 水裡漫游被抓魚 -> 滿了去輸入格卸貨;porter 用 Harbor.find_porter_job 把工作站成品搬到最空的櫃台 / 下游工作站;cashier 走到被指派櫃台的收銀格站著;數值 game.json helpers.<role>)、`customer.gd`(走到排隊位、等、買完離開,無物理;泡泡顯示物品名 ×數量)
- `game/world/`:Pad(Area3D 基底,每幀對站著的 Carrier 呼叫 _on_carrier_stay,_budget 速率累加器)、StationPad、Station(`Station.create(def)`,spot_id、apply_upgrades 吃 worker_speed / pile_cap)、FishArea、Fish、Counter(`Counter.create(def)` 讀 counters.json;上架格 + 收銀格 ServicePad + 排隊位;`notify_server()` / `has_server()` 幀戳;cashier 指派;apply_upgrades)、CounterPad、ServicePad、MoneyPad(現金堆;收錢的 carrier 站上來收進錢包;set_cash 還原)、PricePad(從錢包扣;_dwell 站滿 payDelaySec 才付;可重複牌、付清後需離開再踏上(_blocked)、restore_state)、TrashPad(玩家站上丟掉背上所有貨物,GameState.add_trashed)
- `game/camera/follow_camera.gd`:跟隨相機(從 +Z 側俯視,螢幕上 = 世界 -Z)
- `game/ui/hud.gd`:錢包 / 背上內容 / 統計(HUD_STATS 九個參數)/ 通知 / 操作提示(每幀讀 GameState,不靠訊號)
- `game/levels/harbor.gd` + `harbor.tscn`(主場景):星港漁市,座標常數 STATION_SPOTS / STATION_DEFS / COUNTER_SPOTS / PAD_SPOTS / UNLOCKS;_on_purchased 生幫手與解鎖建築;find_* 給幫手找目標;snapshot / restore_world / save_now / _load_save / new_game
- `autoload/event_bus.gd`:fish_caught / items_processed / sale_made / cash_collected / purchase_progress / purchased / helper_hired / notice
- `autoload/game_state.gd`:wallet(add_wallet / spend)/ capacity_bonus / unlocked / hired / upgrades / 統計(含 items_trashed);apply_purchase(effect type:capacity / hire / unlock / upgrade)、upgrade_mult、to_dict / from_dict
- `autoload/save_manager.gd`:存檔 IO(user://manlife_save.json,VERSION 2;has_save / write / read / delete;測試改 save_path)
- `data/config/game.json`:速度、容量、搬運速率(transferPerSec / cashPickupPerSec / payPerSec / payDelaySec / trashPerSec)、魚群、顧客、autosaveSec、helpers、upgrades;`data/items.json`(fish / fillet / grilled / cash);`data/stations.json`(cutting_table、grill);`data/counters.json`(fillet_counter $2、grill_counter $5);`data/shop.json`(八塊牌);`data/locale/strings.csv`

## 世界慣例

- 平面世界:Carrier 用 MOTION_MODE_FLOATING,不算重力;物理層 1 地形(隱形牆)、2 Carrier(玩家 / 幫手互相穿過)。格子與水區是 Area3D,mask 只看層 2。顧客與魚沒有物理。
- 面向:Carrier local +Z 是前方(rotation.y = atan2(dir.x, dir.z)),背上堆疊在 -Z。
- 格子互動都是「站上去就自動」:速率 transferPerSec / cashPickupPerSec / payPerSec / trashPerSec,`Pad._budget` 累加器最多多攢 1 件。
- 錢走錢包:賣出的錢堆在錢格,收錢的 carrier(只有玩家 collects_cash)站上去就收進 `GameState.wallet`;價格牌從錢包扣;背包(ItemStack)只放貨物,`"cash"` 物品只剩錢格堆的外觀。價格牌要站滿 payDelaySec 才開始付(`_dwell`),全速走過 2 格寬的牌只要 0.43 秒所以不會付;價格牌一排在 z = 5、間距 4(牌寬 2)留走道。
- 櫃台:只有 can_serve 的 carrier 站在 ServicePad(櫃台 local +Z)那幾幀 `has_server()` 才賣;收銀員每個櫃台一位(Harbor._assign_cashiers),沒櫃台可去就等新櫃台。
- 搬運工:`Harbor.find_porter_job()` 挑成品最多且有地方送的工作站,`find_dest_for(item, exclude)` 偏向最空的櫃台(分數 = 空位比例)、吃該原料的工作站打 0.9 折;卸不下就換目的地。
- 升級:Station / Counter 在 `_ready` 與 `GameState.changed` 時 `apply_upgrades()`(speed_mult = upgrade_mult("worker_speed"),堆疊上限 = 基礎 × upgrade_mult("pile_cap"),四捨五入);新建的建築自動吃到。
- 價格牌:一次性付清就 `set_deferred("monitoring", false)` + `set_physics_process(false)` 消失;可重複牌付清後漲價留在原地、`_blocked` 記住還站著的人直到離開。monitoring 關掉後再查重疊會報錯,Pad._physics_process 有保護。
- 存檔:`SaveManager.write({"state": GameState.to_dict(), "world": Harbor.snapshot()})`;state 含 wallet;world 含 player {item, count}、money、stations{spot_id: {input, output}}、counters{def_id: {stock}}、pads{id: {remaining, buys}}。讀檔順序:GameState.from_dict -> 依 unlocked 重建建築 -> 依 hired 靜音生幫手 -> restore_world。改存檔格式就加 VERSION(舊檔直接忽略)。
- 新站點 / 櫃台 / 購買:加 JSON + 在 harbor.gd 的 SPOTS / UNLOCKS 給座標;效果型別新增要同時改 GameState.apply_purchase 與 Harbor._on_purchased。

## 測試

```
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1
```

先 `godot --headless --path . --import`,再依檔名順序跑 `tests/verify_*.tscn`:`verify_core`(資料 / ItemStack / StationLogic / PurchaseLogic 含可重複牌 / CounterLogic / MoveInput / SaveManager IO / GameState 序列化)、`verify_world`(3D 整合:建關卡 -> 抓魚到滿 -> 卸貨 / 切 / 取 -> 上架 -> 沒人收銀不賣、站收銀格才賣 -> 錢格收進錢包、走過價格牌不付、站著分期 -> 僱收銀員接手 -> 垃圾桶丟魚 -> 僱搬運工送貨 -> 兩種升級牌 -> 再僱漁夫 -> 增建烤魚攤跑第二條鏈 $5 -> 存檔 / 重建關卡還原 -> 新遊戲,約 2 分鐘)。Godot 路徑預設是桌面上的 4.7 console exe,可用環境變數 `GODOT` 覆蓋。

- 新增腳本或資源後要先 `--import`,否則 class_name 找不到;第一次 import 會因為 .translation 還沒產生而印錯誤,第二次就正常。
- 測試指令一定加 timeout:測試場景若編譯失敗,headless 永遠不會結束。
- verify_world 用合成輸入走路:`_pay_pad(pad)` 先到錢格收夠錢再站到牌子上,買東西的錢用 `money_pad.add_cash` 補;測試自己把 `SaveManager.save_path` 指到暫存檔。

## 踩過的坑

- Bash 工具單次指令超過約 5KB 會被截斷:大檔用 Write 工具寫,大段 Python 補丁先寫到檔案再執行。
- Godot 編輯器預設「存檔時轉換縮排」成 Tab:使用者在編輯器裡存過的腳本可能整檔變 Tab;改檔前先看縮排,同一檔不能混用,commit 前統一回 4 空白。
- Area2D / Area3D 子類別不能宣告叫 `gravity` 的變數(與內建屬性撞名)。
- `Array.filter()` 回傳無型別陣列,不能直接指派給 `Array[T]` 變數(用無型別變數或 `assign`)。
- 用 `.new()` 建、直接加在 CanvasLayer 下的 Control 要用 `set_anchors_and_offsets_preset(PRESET_FULL_RECT)` 鋪滿。
- 換場景會把整個舊場景 memdelete:UI 關閉回呼用 `tree_exiting`,不要用 `tree_exited`。
- strings.csv 的欄位裡若有真的換行,Godot 會當成多列(鍵對不到翻譯);要用字面 `\n`。

## 里程碑

1. 垂直切片(完成 2026-10-25):搖桿移動 + 背上堆疊、淺水區抓魚、切魚台(輸入格 / 工人 / 輸出格)、櫃台 + 排隊顧客 + 錢格、三塊價格牌(分期付款)、漁夫幫手 AI、HUD、資料驅動 JSON、兩套 headless 測試。
2. 存檔與自動化(完成 2026-10-26):存檔(SaveManager + snapshot,自動存 / F9 重來)、第二條貨物鏈(烤魚攤 魚片 -> 烤魚,烤魚櫃台 $5,建地牌 $60)、搬運工 / 收銀員幫手(櫃台改成要有人收銀)、升級牌(工人速度 / 堆疊上限,各三級漲價)、可重複僱用牌(漁夫 ×3 / 搬運工 ×2 / 收銀員 ×2)、垃圾桶。同日追加:現金改錢包(不佔背包、價格牌站 0.6 秒才付)。

之後候選:離線收益、更多站點與貨物鏈(魚湯)、星幣 / 聲望等長線目標、觸控虛擬搖桿與手機匯出、小地圖或箭頭指引、換皮與美術。
