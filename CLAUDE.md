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
- 2026-10-26(使用者要求):搬運工以「當下庫存比例最低的櫃台」最優先補;規則抽成 PorterPlanner(純資料),
  缺貨櫃台的需求會往上游傳(烤魚櫃台空、烤魚攤沒成品 -> 先送魚片去烤魚攤),只拿目的地放得下的量,卸不掉就放回來源。
- 2026-10-26(里程碑 3,手感與引導):1a 音效用程式合成占位(tools/gen_sfx.py -> assets/sfx/*.wav,同名覆蓋換正式);
  2c 新存檔先走七步教學鏈,之後箭頭繼續當提示、H 鍵開關;3a 玩家頭上小箭頭轉向目標 + 目標上方彈跳大箭頭。
  飛行動畫與進度環純表現層(規則瞬間完成,事件驅動)。
- 2026-10-26(里程碑 4,iPhone):照使用者的 taifex-signal 台股 App 作法走 PWA,不上 App Store。1a 放 GitHub Pages
  (tyboy0407/manlife-play,Cloudflare 單檔 25 MB 上限放不下 39.5 MB 的 wasm);2a 直式優先、橫式也能動;3a 浮動搖桿 + 右上角選單鈕
  (提示箭頭 / 音效 / 重新開始)取代 H / F9;匯出模板下載已獲同意。
- 使用者習慣:每個系統先開放三個問題、以編號回答,確認後再實作;每個里程碑跑全部測試再 commit。

## 工作方式

- 型別化 GDScript,4 空白縮排。純規則類別放 `core/`(RefCounted,不依賴 Node / 場景 / Autoload,可 headless 測試);場景與節點放 `game/`;全域單例放 `autoload/`;數值資料放 `data/`(JSON / CSV)。
- 程式與資料鍵英文;遊戲內文字繁中,走 `data/locale/strings.csv` + `tr()`;新 UI 文字先加進 CSV 再用。CSV 裡的換行寫字面 `\n`(匯入時 c_unescape),不要放真的換行。
- 關卡用程式碼擺放(座標在關卡腳本),規則與數值在 `data/`;改數值不用動程式。
- 每個系統:討論 -> 定案 -> 實作 -> 跑全部測試 -> commit。里程碑與定案記在本檔。

## 目錄

- `core/data/game_data.gd`:GameData(靜態載入 game.json / items.json / stations.json / counters.json / shop.json;`section(key)`、`helper(role)`、物品尺寸 / 顏色 / 翻譯名)
- `core/economy/`:ItemStack(一疊同種物品,有容量)、StationLogic(輸入堆 -> 處理 -> 輸出堆,輸出滿停工,speed_mult)、PurchaseLogic(價格牌分期;repeatable / max_buys / cost_mult / buys,`complete()` 漲價、`restore()` 存檔還原)、CounterLogic(庫存 / 售價 / 賣出)、PorterPlanner(搬運工派工:need_of / plan / best_dest / best_source,吃字典清單)
- `core/input/move_input.gd`:MoveInput(螢幕方向 -> 世界 XZ;from_actions 鍵盤手把 + 觸控搖桿(static touch_dir,有推就以搖桿為準)、toward 合成輸入)
- `core/guidance/guide_logic.gd`:GuideLogic(教學七步的完成條件與指向、教學後的提示 hint();吃世界狀態字典,回 {kind, target, text, arg})
- `game/common/`:Carrier(CharacterBody3D 浮動模式、背上 ItemStack + StackVisual、旗標 can_fish / takes_output / collects_cash / can_serve / can_use_trash、stack_top 給飛行動畫)、StackVisual、VisualFactory(box / capsule / cylinder / cone / label / 材質快取)、ProgressRing(平放進度環,ArrayMesh 弧,set_progress 量化重建)
- `game/player/player.gd`:Player(input_provider 可餵合成輸入;容量 = 設定 + GameState.capacity_bonus;can_serve / can_use_trash)
- `game/npc/helper.gd`:Helper(role 決定狀態機:fisher 水裡漫游被抓魚 -> 滿了去輸入格卸貨;porter 問 Harbor.find_porter_job(PorterPlanner)搬成品,狀態 to_pickup / picking / to_dropoff / dropping / returning / step_back;cashier 走到被指派櫃台的收銀格站著;數值 game.json helpers.<role>)、`customer.gd`(走到排隊位、等、買完離開,無物理;泡泡顯示物品名 ×數量)
- `game/world/`:Pad(Area3D 基底,每幀對站著的 Carrier 呼叫 _on_carrier_stay,_budget 速率累加器)、StationPad、Station(`Station.create(def)`,spot_id、apply_upgrades 吃 worker_speed / pile_cap、take_back 收回搬運工送不出去的成品)、FishArea、Fish、Counter(`Counter.create(def)` 讀 counters.json;上架格 + 收銀格 ServicePad + 排隊位;`notify_server()` / `has_server()` 幀戳;cashier 指派;apply_upgrades)、CounterPad、ServicePad、MoneyPad(現金堆;收錢的 carrier 站上來收進錢包;set_cash 還原)、PricePad(從錢包扣;_dwell 站滿 payDelaySec 才付;可重複牌、付清後需離開再踏上(_blocked)、restore_state)、TrashPad(玩家站上丟掉背上所有貨物,GameState.add_trashed)
- `game/camera/follow_camera.gd`:跟隨相機(從 +Z 側俯視,螢幕上 = 世界 -Z);直式(高 >= 寬)KEEP_WIDTH、fov 40、偏移 (0, 13.5, 9.5),橫式 KEEP_HEIGHT、fov 42、偏移 (0, 17, 11.5),視窗轉向時重算
- `game/ui/hud.gd`:Hud(class_name):錢包 / 背包內容 / 統計(HUD_STATS 九個參數)/ 上方目標文字(set_objective,Guide 餵)/ 通知 / 操作提示(觸控裝置用 HUD_HINT_TOUCH);右上角選單鈕 + 面板(menu_action:toggle / hints / sound / new_game 兩次確認 / close,hints 與 new_game 用 action 訊號交給關卡);聽 items_moved "cash" 畫 2D 的 $ 飛向錢包
- `game/ui/touch_joystick.gd`:TouchJoystick(鋪滿畫面最底層、mouse_filter IGNORE;_unhandled_input 收 ScreenTouch / ScreenDrag,按下點為中心、RADIUS 90、只跟第一根手指、exclusions 範圍不算;handle_event 給測試)
- `game/ui/guide.gd`:Guide(Node3D,掛在關卡下):每 0.1 秒把關卡狀態餵 GuideLogic,推進教學(GameState.tutorial_step)、解析目標座標、畫玩家頭上箭頭 + 目標彈跳箭頭、餵 HUD 文字;toggle_hints(H)
- `game/levels/harbor.gd` + `harbor.tscn`(主場景):星港漁市,座標常數 STATION_SPOTS / STATION_DEFS / COUNTER_SPOTS / PAD_SPOTS / UNLOCKS;_on_purchased 生幫手與解鎖建築;porter_dests / porter_sources 餵 PorterPlanner,find_porter_job / find_dest_for / find_station_* 給幫手找目標;snapshot / restore_world / save_now / _load_save / new_game
- `autoload/event_bus.gd`:fish_caught / items_processed / sale_made / cash_collected / purchase_progress / purchased / helper_hired / notice / items_moved(kind, item, from, to, count)/ tutorial_step_done / tutorial_finished
- `autoload/sfx.gd`:Sfx(聽事件播 assets/sfx/<name>.wav,10 個 player 輪播、每種最短間隔、環境音執行期開 loop;played 計數給測試)
- `autoload/fly_fx.gd`:Fx(聽 items_moved 生物品幽靈拋物線飛,掛在自己底下;kind "cash" 交給 HUD)
- `tools/gen_sfx.py`:純 Python 合成占位音效(正弦 / 噪音 / 包絡),輸出 assets/sfx/*.wav(22050 Hz 16-bit mono)
- `tools/gen_icons.py`:Pillow 畫占位圖示(assets/icons/icon_128 / 144 / 180 / 512.png)與啟動畫面 splash.png
- `tools/serve_web.py`:本機預覽 build/web(0.0.0.0,印 iPhone 可用的區網網址;8080 被台股 App 佔著,用 8090);`.claude/launch.json` 的 `web`
- `tools/deploy_web.py`:`--export-release Web` -> 同步到 build/pages(tyboy0407/manlife-play 的 clone)-> commit(沿用本 repo 的 git 身分)-> push main;`--export-only` / `--no-export`
- `export_presets.cfg`:Web 預設(不開執行緒、PWA 開、直式、圖示指到 assets/icons);`assets/fonts/NotoSansTC-VF.ttf`(OFL,見 LICENSE.md)是遊戲內唯一的中文字型
- `autoload/game_state.gd`:wallet(add_wallet / spend)/ tutorial_step / hints_on / capacity_bonus / unlocked / hired / upgrades / 統計(含 items_trashed);apply_purchase(effect type:capacity / hire / unlock / upgrade)、upgrade_mult、to_dict / from_dict
- `autoload/save_manager.gd`:存檔 IO(user://manlife_save.json,VERSION 2;has_save / write / read / delete;測試改 save_path)
- `data/config/game.json`:速度、容量、搬運速率(transferPerSec / cashPickupPerSec / payPerSec / payDelaySec / trashPerSec)、魚群、顧客、autosaveSec、helpers、upgrades;`data/items.json`(fish / fillet / grilled / cash);`data/stations.json`(cutting_table、grill);`data/counters.json`(fillet_counter $2、grill_counter $5);`data/shop.json`(八塊牌);`data/locale/strings.csv`

## 世界慣例

- 平面世界:Carrier 用 MOTION_MODE_FLOATING,不算重力;物理層 1 地形(隱形牆)、2 Carrier(玩家 / 幫手互相穿過)。格子與水區是 Area3D,mask 只看層 2。顧客與魚沒有物理。
- 面向:Carrier local +Z 是前方(rotation.y = atan2(dir.x, dir.z)),背上堆疊在 -Z。
- 格子互動都是「站上去就自動」:速率 transferPerSec / cashPickupPerSec / payPerSec / trashPerSec,`Pad._budget` 累加器最多多攢 1 件。
- 錢走錢包:賣出的錢堆在錢格,收錢的 carrier(只有玩家 collects_cash)站上去就收進 `GameState.wallet`;價格牌從錢包扣;背包(ItemStack)只放貨物,`"cash"` 物品只剩錢格堆的外觀。價格牌要站滿 payDelaySec 才開始付(`_dwell`),全速走過 2 格寬的牌只要 0.43 秒所以不會付;價格牌一排在 z = 5、間距 4(牌寬 2)留走道。
- 櫃台:只有 can_serve 的 carrier 站在 ServicePad(櫃台 local +Z)那幾幀 `has_server()` 才賣;收銀員每個櫃台一位(Harbor._assign_cashiers),沒櫃台可去就等新櫃台。
- 搬運工:`PorterPlanner.plan(dests, sources, capacity)`。需求分數:櫃台 = 空位比例(庫存比例最低最優先);工作站原料 = 0.9 × 下游(吃它成品的目的地)最高需求 × 原料空位比例,所以缺貨會沿鏈往上游傳;挑需求最高且有來源(成品最多的工作站)的目的地,amount = min(容量, 目的地空位, 來源數量)。手上有貨時 `best_dest` 找收它且有空位、需求最高的地方;一秒卸不下去就換,都沒有就 `Station.take_back` 放回來源輸出堆並走開一步(放回時 takes_output 關掉,免得輸出格又塞回來)。
- 升級:Station / Counter 在 `_ready` 與 `GameState.changed` 時 `apply_upgrades()`(speed_mult = upgrade_mult("worker_speed"),堆疊上限 = 基礎 × upgrade_mult("pile_cap"),四捨五入);新建的建築自動吃到。
- 價格牌:一次性付清就 `set_deferred("monitoring", false)` + `set_physics_process(false)` 消失;可重複牌付清後漲價留在原地、`_blocked` 記住還站著的人直到離開。monitoring 關掉後再查重疊會報錯,Pad._physics_process 有保護。
- 存檔:`SaveManager.write({"state": GameState.to_dict(), "world": Harbor.snapshot()})`;state 含 wallet;world 含 player {item, count}、money、stations{spot_id: {input, output}}、counters{def_id: {stock}}、pads{id: {remaining, buys}}。讀檔順序:GameState.from_dict -> 依 unlocked 重建建築 -> 依 hired 靜音生幫手 -> restore_world。改存檔格式就加 VERSION(舊檔直接忽略)。
- 新站點 / 櫃台 / 購買:加 JSON + 在 harbor.gd 的 SPOTS / UNLOCKS 給座標;效果型別新增要同時改 GameState.apply_purchase 與 Harbor._on_purchased。
- 表現層只聽事件:格子 / 水區 / 櫃台搬了東西就 `EventBus.items_moved.emit(kind, item, from, to, count)`(from / to 世界座標,堆頂用 Carrier.stack_top / Station.pile_top / Counter.pile_top);Fx 畫幽靈、Sfx 播音、HUD 畫 $ 飛向錢包。規則層不等動畫,所以測試數值不受影響;新的搬運行為記得發事件。
- 進度環:PricePad.ring 顯示 logic.progress()(_update_label 時更新),Station.ring 顯示 work_progress()(只在工作時顯示)。
- 引導:GameState.tutorial_step 0 ~ 7,Guide 每 0.1 秒 refresh,`GuideLogic.tutorial_step_done` 允許跳步(舊存檔有購買紀錄視為完成);教學後 `hint()` 優先序:手上有貨先處理 > 買得起的牌 > 櫃台有貨沒人收銀 > 錢格有錢 > 工作站有成品(沒搬運工才提醒)> 去抓魚。目標 kind / target 由 Guide._resolve 換成座標;新目標種類要同時加 GuideLogic 與 _resolve。

## 網頁 / 手機(PWA)

- 渲染器是 Compatibility(網頁匯出只支援這個);基準視窗 540 × 960、stretch canvas_items + expand,桌機視窗覆寫 450 × 800。
  字型:Godot 內建字型沒有中文、網頁拿不到系統字型,所以 `gui/theme/custom_font` 與 VisualFactory.label 都用 assets/fonts 的 Noto Sans TC。
- 觸控:`input_devices/pointing/emulate_touch_from_mouse` 開著,桌機滑鼠拖也會變觸控事件;搖桿只吃 `_unhandled_input`,GUI 按鈕先吃掉自己的事件,
  另外用 exclusions(選單鈕 / 面板的 rect)擋掉按在按鈕上的那根手指。Hud 的 is_touch_device() 決定提示文字。
- 匯出:`godot --headless --path . --export-release Web build/web/index.html`(模板在 `%APPDATA%\Godot\export_templates\4.7.stable\`,
  只解了 web_* 與 version.txt);產物 index.html / js / wasm(39.5 MB)/ pck / 圖示 / index.manifest.json / index.service.worker.js(快取版本 = 匯出時間,每次匯出自動換)。
  不開執行緒的模板不需要 COOP / COEP 標頭,GitHub Pages 才放得上。
- 部署:`python tools/deploy_web.py`(匯出 + 推 Pages);網址 https://tyboy0407.github.io/manlife-play/,repo 只放匯出成品不放原始碼。
  iPhone:Safari 開網址 -> 分享 -> 加入主畫面;存檔在瀏覽器儲存空間(IndexedDB)。
- 本機預覽:`python tools/serve_web.py --port 8090`,內建瀏覽器用 mobile 視窗看;headless 測試的視窗是正方形(100 × 100 或 1280 × 1280),
  所以 is_portrait 用「高 >= 寬」,測試才走直式分支。

## 測試

```
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1
```

先 `godot --headless --path . --import`,再依檔名順序跑 `tests/verify_*.tscn`:`verify_ui`(HUD 版面:選單鈕與面板貼右上角不出界、搖桿排除區)、`verify_core`(資料 / ItemStack / StationLogic / PurchaseLogic 含可重複牌 / CounterLogic / PorterPlanner 派工 / GuideLogic 教學與提示 / ProgressRing / 音效檔載入與 Sfx 節流 / MoveInput / SaveManager IO / GameState 序列化)、`verify_world`(3D 整合,一路檢查教學箭頭指到哪:建關卡(直式相機、浮動搖桿推 / 放 / 排除區、選單兩次確認)-> 抓魚到滿 -> 卸貨 / 切 / 取 -> 上架 -> 沒人收銀不賣、站收銀格才賣 -> 錢格收進錢包、走過價格牌不付、站著分期(進度環)-> 僱收銀員接手(教學完成轉提示、H 開關) -> 垃圾桶丟魚 -> 僱搬運工送貨 -> 兩種升級牌 -> 再僱漁夫 -> 增建烤魚攤 -> 搬運工送不出去放回來源、最缺貨的櫃台優先補 -> 手動跑第二條鏈 $5 -> items_moved / 幽靈 / 音效計數 -> 存檔 / 重建關卡還原 -> 新遊戲,約 2.5 分鐘)。Godot 路徑預設是桌面上的 4.7 console exe,可用環境變數 `GODOT` 覆蓋。

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
- strings.csv 的欄位裡若有真的換行,Godot 會當成多列(鍵對不到翻譯);要用字面 `\n`。中文欄位只能用全形逗號「,」,ASCII 逗號會多出一欄(補丁腳本可用 `line.count(",") == 2` 檢查)。
- headless 離開時「ObjectDB instances leaked / resources still in use」通常是還在播的音效:AudioStreamPlayback 在 AudioServer 執行緒裡,quit 前先 `Sfx.stop_all()` 再等兩幀。測試裡自己建的節點用 `free()`(不是 queue_free)。
- GDScript 迭代無型別陣列時元素是 Variant,`var x := CONST_STR + n` 會「無法推斷型別」;寫 `var x: String = ... + str(n)`。
- 新加字型 / 圖片後第一次 `--import` 會因為資源還沒匯入而讓 preload 它的腳本解析失敗(整批「Failed to compile depended scripts」),再跑一次就好。
- 靠右上角的 Control 不要用 `set_anchors_and_offsets_preset(..., MINSIZE)`(加進樹前量不到字,之後往右長出畫面);直接設 anchor 1 / offset_right -margin / offset_left -margin-width、grow_horizontal BEGIN,面板給 custom_minimum_size。
- 本機 8080 是台股 App 的伺服器,網頁預覽用 8090;瀏覽器窗格的 launch.json 指向舊的 star-weaver 路徑,改用 `preview_start {url}` 配 Bash 背景伺服器。

## 里程碑

1. 垂直切片(完成 2026-10-25):搖桿移動 + 背上堆疊、淺水區抓魚、切魚台(輸入格 / 工人 / 輸出格)、櫃台 + 排隊顧客 + 錢格、三塊價格牌(分期付款)、漁夫幫手 AI、HUD、資料驅動 JSON、兩套 headless 測試。
2. 存檔與自動化(完成 2026-10-26):存檔(SaveManager + snapshot,自動存 / F9 重來)、第二條貨物鏈(烤魚攤 魚片 -> 烤魚,烤魚櫃台 $5,建地牌 $60)、搬運工 / 收銀員幫手(櫃台改成要有人收銀)、升級牌(工人速度 / 堆疊上限,各三級漲價)、可重複僱用牌(漁夫 ×3 / 搬運工 ×2 / 收銀員 ×2)、垃圾桶。同日追加:現金改錢包(不佔背包、價格牌站 0.6 秒才付);搬運工改成最缺貨的櫃台優先(PorterPlanner)、卸不掉放回來源。
3. 手感與引導(完成 2026-10-26):飛行動畫(物品拋物線、賣出飛向顧客、$ 飛向錢包、付款飛向牌子)、合成占位音效 + 環境音、價格牌付款進度環 + 工作站處理進度環、七步教學鏈 + 之後的提示箭頭(頭上小箭頭 + 目標大箭頭,H 開關)、顧客買到道謝泡泡。
4. iPhone PWA(完成 2026-10-26):Compatibility 渲染器、直式相機、浮動觸控搖桿、右上角選單、Noto Sans TC 字型、占位圖示 / 啟動畫面、Web 匯出預設(PWA)、本機預覽與一鍵部署腳本,上線 https://tyboy0407.github.io/manlife-play/。

之後候選:離線收益、幫手升級、顧客多樣化與耐心、關卡座標資料化與地圖擴張、更多貨物鏈(魚湯)、字型子集化縮小下載、換皮與美術。
