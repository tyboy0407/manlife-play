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
- 2026-10-27(模型):1a 免費 CC0 低多邊形、2b 人物 + 貨物、3a 要內建動畫。使用者自己下載了 Kenney Mini Characters、Kenney Survival Kit、
  Quaternius Animated Fish Pack 放到 assets/models/;我只把用到的檔案複製到 assets/models/game/,原始套件加 .gdignore 且 git 不追蹤。
  角色分配(game.json models):玩家 male-a、漁夫 male-b、搬運工 male-f、收銀員 male-c、工作站工人 male-e、顧客 7 種輪流;
  魚用 Survival Kit 的 fish.glb 側躺疊,魚片 / 烤魚還是方塊(壽司店套件沒下載);水裡的魚用 Quaternius FBX + 游泳動畫。
- 2026-10-27(北極熊,使用者點名:場景隨機出現北極熊吃掉漁夫 / 收銀員 / 搬運工,玩家要到村外武器店買武器驅趕):
  1c 被吃的幫手永久消失,僱用牌的購買次數不退(價格維持已漲的);2c 武器買斷三級(村外一塊可重複牌 $35 ×1.7:Lv1 靠到 1.8 內趕跑、
  Lv2 趕跑後熊更久不來(冷卻 ×1.7)、Lv3 熊在 6 格外看到玩家就逃);3b 熊進村吃掉一個不走,繼續找下一個,直到被趕跑或沒人可吃。
  我定的配套:村裡有幫手才開始倒數,第一隻 45 秒後、之後 60 ~ 90 秒;西牆開缺口(z 1.2 ~ 3.8)通往村外武器店小院;熊用白色方塊占位
  (沒有 CC0 熊模型,models.bear.file 填了就換);武器用 Survival Kit 的鎚 / 斧 / 強化斧掛在玩家腰間。
- 2026-10-27(使用者直接點名四項調整,沒開問題):1 被吃掉的幫手可以買回,價格是該級的 1.5 倍(PurchaseLogic.lose / lost / rebuy_mult,
  買回後回正常階梯,已付的部分保留;牌子買滿消失後被吃也會重新出現);2 熊更頻繁(第一群 40 秒、之後 35 ~ 55 秒)且成群
  (packChances:10% 4 隻、30% 3 隻、50% 2 隻、10% 1 隻,各盯不同幫手,整群走光才重新倒數);3 擴建村莊牌 $1000(unlock village_2:
  拆東門、往東多一塊地:第二個水區、切魚台 + 烤魚攤、第二組櫃台所以顧客變多;大額牌付款速度 × 價格/payScaleCost);
  4 顧客要 1 ~ 5 件(customers.wantWeights 45 / 25 / 15 / 10 / 5,庫存不夠就買得到幾件算幾件)。
- 2026-10-27(使用者點名四項,沒開問題):1 擴建後幫手卡牆 -> Helper.go_to 走 Harbor.route 的東門中途點 + 卡住偵測(tests/verify_nav 先重現再修);
  2 熊改成有血條,玩家帶武器靠近自動攻擊(每 0.5 秒一下),血條歸零才逃;武器三級只加攻擊力 10 / 20 / 35(不再有嚇跑距離 / 冷卻倍率);
  3 血量 = 30 + 每分鐘 10;3 分鐘後出沒間隔在 5 分鐘內從 35 ~ 55 線性縮到 15 ~ 25(GameState.play_time 遊戲時間,存檔);
  4 5 分鐘出北極熊王:血 ×4、體型 1.6、連水裡的魚也吃,吃幫手回滿血、體型 ×1.15,吃魚回 5%、×1.02(上限 2.4 倍)(回血後來拿掉,見下),
  不會自己走,打死後 300 秒再來(我定的)。吃魚回血曾設 15% 讓 Lv3 也打不死(每秒回 80 > 打 70),調成 5% / 咬 1 秒。
- 2026-10-27(使用者點名三項,沒開問題):1 擴建村莊後僱用牌多開放名額:搬運工 +4、收銀員 +2、漁夫 +2(shop.json expandBuys,
  PurchaseLogic.expand 只加一次,買滿消失的牌重新出現、價格接著漲);2 村莊四角各一座守衛塔 $200(shop.json tower_1 ~ 4,牌就是地基):
  塔頂守衛朝射程 9 內最近的活熊每 0.8 秒射一箭(10 傷,箭追著熊飛到了才扣血),熊靠近 7 格內或被射中會改去拆塔(咬一口 2.5 秒扣 40),
  血 120(後來改 800,見下)歸零塌成廢墟,牌重現標「修復」同價 $200(rebuyMult 1,走 lose / on_lost 同一套);3 網頁版偵測到新版自動重新整理
  (export_presets html/head_include 的 JS:監看 service worker 更新,新版裝好就 postMessage('update') 讓它 skipWaiting + claim,
  controllerchange 再 reload;開頁 30 秒內或剛回到前景 10 秒內找到新版立刻換,玩到一半找到的等下次回前景再換;Harbor 失焦時先存檔)。
- 2026-10-27(使用者:搬運工還是卡在東牆上,要求擴建時中間不要有牆):擴建後把整面東牆(三段隱形牆 + 兩段柵欄,Harbor.east_walls)全拆,
  主村與 annex 連成一片;Harbor.route 不再給中途點(回空)、gate_point 回原點,Helper 的卡住偵測留著(改往目的地的 z 方向滑)。
- 2026-10-27(使用者點名兩項,沒開問題):1 守衛塔血量改 800 = 一般熊咬一口 40 要咬 20 口(tower.hp,kingBiteMult 拿掉);
  2 北極熊王吃魚 / 吃幫手不再回血(king.healFish / healHelper 0,還是會變大),改成會拆玩家的建築:切魚台、烤魚攤、守衛塔都算牠的獵物
  (不限距離,挑最近的),咬滿 king.buildingBiteSec(10 秒)就直接拆掉不看血量;被拆的工作站變廢墟、工人不見、格子停用(堆裡的貨留著),
  廢墟位置出現 $200 修復牌(shop.json repairStation,Harbor._add_station 時就生好藏著、effect repair),付清修好。我定的配套:
  修復牌沿用守衛塔牌的 lose / on_lost(買回價 ×1)流程,存檔 world.stations 多記 broken;被拆的工作站不進搬運工 / 漁夫 / 提示的名單。
- 2026-10-28(使用者點名三項,沒開問題):1 熊出沒最快 30 ~ 40 秒一群(bear.intervalMin,開局 35 ~ 55 不變);
  2 打跑的熊掉毛皮(Loot pelt),撿起來進 GameState.pelts,村外武器店旁的「升級武器店」牌收毛皮 5 / 10 / 20(shop.json shop_upgrade:currency pelt、costs 逐次價),
  每升一級武器牌多賣一級(weapon.levels 加到 6 級:Lv4 55 / Lv5 80 / Lv6 120,鎬 / 強化鎬模型;shopBaseLevels 3 + shop_level,PurchaseLogic.raise_max);
  3 打死王掉熊王牙(Loot tooth),站到完好守衛塔底下的熊王牙牌(tooth_tower_n,收 1 顆)付掉 -> 強力守衛塔(tower.strong:血 2000 = 扛 50 口、每箭 25,
  Tower.tier 1,拆了修好還是強力的)。我定的配套:掉落物掉在熊被打倒的地方、玩家走到 1.3 內自動撿;熊王牙牌只在塔完好且還沒強化時出現;
  存檔記 pelts / teeth / shop_level(GameState)、towers.tier、地上的 loot。
- 2026-10-28(使用者:再加兩個守衛塔位置,位置由我選空曠且打得到熊的地方):tower_5 (-3, -2.9)、tower_6 (3, -2.9),在村中央淺水區南緣、
  切魚台輸入格之間的空地(x ±3 是 3.8 寬的空隙;屋頂只遮到水面不遮格子)。理由:四角塔射程 9 照不到村中央(station_2 離最近的角塔 14.5),
  熊咬搬運工 / 工人、王拆切魚台都在這裡;加上這兩座後主村每個點都在某座塔射程內(水中央 5.5、價格牌排 8.5、櫃台由南角塔管)。
  牌與熊王牙牌(tooth_tower_5 / 6)照舊同位置,shop.json 共 23 塊牌。
- 2026-10-28(試玩報告 notes/playtest_2026-10-28.md 後,使用者逐項裁示,14 項改):1 第一群熊 3 分鐘後才來(bear.firstAtSec 180 + firstDelaySec 5);
  2 一群熊最多吃 2 個幫手就整群撤退(packMaxEats,BearSpawner.on_helper_eaten -> Bear.retreat,理由 "full"、NOTICE_BEAR_FULL);4 工作站塞住(成品滿停工)
  提示改指輸出格 / 背著原料先指垃圾桶(HINT_take_jammed / HINT_station_jammed,state.stations[].blocked);5 櫃台滿又沒人收銀提示指收銀格(HINT_counter_full_serve);
  6 王 8 分鐘才來(king.atSec 480);7 教學第 7 步錢不夠時箭頭回工作循環、文字「再賺 $N 就能買」(TUT_earn,args);9 熊來了沒武器又錢不夠:
  指錢格(HINT_BEAR_MONEY)或工作循環(HINT_BEAR_EARN 還差 $N);11 咬人 8 秒(biteSec),熊吃過東西後沒獵物不走、在村裡晃(Bear._linger)直到被打跑或整群吃飽;
  12 一般熊掉 1 ~ 2 張毛皮、王掉 3 顆牙(dropCount,BearLogic.drop_count),武器店升級 3 / 8 / 15 張;15 修復 $100(守衛塔牌 rebuyMult 0.5、repairStation 100);
  16 有武器且熊在 6 格內(bear.busyRadius)暫停抓魚 / 拿貨(Player.busy_with_bear 關 can_fish / takes_output);18 HUD 左上只留背包 / 毛皮 / 熊王牙 / 武器(HUD_RES),
  詳細統計(HUD_STATS)收進選單面板(Hud._stats / stats_text())。不改:#3 塔價、#8 提示挑最便宜、#10、#13 烤魚攤價、#14 擴建價、#17 顧客耐心、#19 武器店位置、#20。
- 2026-11-03(使用者點名兩項,沒開問題):1 擴建區也照主村布置守衛塔:每塊六座(四角在沙地內 2.0 / 1.6 格 + 中央水邊兩座),tower_7 ~ 12 第一塊、13 ~ 18 第二塊,
  牌子(tower_n / tooth_tower_n,位置直接取 TOWER_SPOTS)只在那塊地擴建後出現(Harbor._refresh_tower_pads 用 tower_area(id) <= expansion_level() set_open);
  2 第二次擴建牌 expand_village_2 $2000(unlock village_3,牌在第一塊擴建區 (29.5, 0.5),擴建一次後才出現):ANNEX_RECTS[1](x 31.6 ~ 50.2)、
  拆第一塊的東牆(annex_east_walls)、第三個水區、station_4 + grill_3、fillet_counter_3 + grill_counter_3(counters.json)、僱用牌再 expand 一次
  (PurchaseLogic.expansions,最多 max_expansions 2 次:漁夫 7 / 搬運工 10 / 收銀員 6)、熊入口 entriesExpanded2(東邊 x 54);雪地加寬到 x 55。
- 2026-11-03(使用者點名四項,沒開問題):1 烤魚攤的魚片原料區空了,搬運工最優先補它:PorterPlanner.need_of 工作站原料 stock 0 且沒塞住(dest.blocked)
  回 EMPTY_INPUT_NEED 1.5(> 任何櫃台的 1.0),有料後照原公式;成品堆滿停工的不加急。2 第二次擴建區改成切魚台 + 三座烤魚攤(station_4 33.4、grill_3 / 4 / 5 38.4 / 43.4 / 48.4,
  中央塔 17 / 18 挪到 40.9 / 45.9 的格子空隙);3 第三次擴建牌 expand_village_3 $8000(unlock village_4,牌在第二塊擴建區 (36.4, 5.0) 走道上(原 (40.9, 5.0) 被傳送帶跨過),擴建兩次後才出現):
  ANNEX_RECTS[2](x 50.2 ~ 68.8)、拆第二塊的東牆、第四個水區、僱用牌第三次 expand(max_expansions 3:漁夫 9 / 搬運工 14 / 收銀員 8)、塔 tower_19 ~ 24、熊入口 entriesExpanded3(x 72.6);
  4 第三塊擴建區:兩座烤魚攤(grill_6 53.5 / grill_7 59.5)+ 服飾店 tailor(65.5;stations.json pelt -> sweater、inputPer 5、3 秒一件)+ 毛衣櫃台 sweater_counter($200,
  counters.json wantWeights [1] 一次只買一件)。我定的配套:毛皮仍是不佔背包的資源,服飾店輸入格由玩家站滿 resourceInputDelaySec 0.8 秒後從 GameState.pelts 一張張放
  (StationPad._resource_input,走過不會掉;搬運工不碰毛皮);毛衣是普通貨物,搬運工照 PorterPlanner 送到毛衣櫃台;Guide 在毛皮 >= 5 且服飾店放得下時提示 HINT_pelts;
  王也會拆服飾店(修復 $100 同一套)。
- 2026-11-03(使用者挑了三項,各三個問題全選 a):1 搬運工容量升級牌 upgrade_porter_cap(三級每級 +4:8 -> 12 -> 16 -> 20,$80 ×2,位置 (-10, -1.5) 西側走道;
  GameState.upgrade_bonus(key) = perLevel × 等級,Helper._apply_capacity 在 GameState.changed 時重算,現有搬運工也吃到);
  2 捕熊夾 + 誘餌,固定位置的牌子(像塔的地基):每塊地兩個捕熊夾 trap_n(TRAP_SPOTS,水區兩側雪地、角塔內側,靠熊的入口)、一個誘餌 bait_n(BAIT_SPOTS,西側水邊),
  牌跟著那塊地開放;捕熊夾 $40 一次性:活熊走進 trap.radius 2.5 內就夾到,扣 60(王 150)+ 定住 3 秒(Bear.stun -> state stunned,還是活著打得到),
  用掉後牌子同價重現(on_lost,rebuyMult 1、PricePad.is_consumable_pad 不標買回);誘餌 $30:8 格內的熊(王也是)改去吃(Bear._nearest_bait 在 hunting 時每幀查、
  被塔射中也不會被引開),咬 10 秒吃光(不算吃過東西、不算整群額度)牌子重現;3 傳送帶 $150 一條(CONVEYORS:工作站輸出格 -> 同種貨櫃台上架格,
  十二條;第三塊的烤魚攤接第二塊的烤魚櫃台),牌在工作站旁、兩端都蓋好才出現;ConveyorLogic 每秒拿一件、3 / 秒前進、隔 0.8、櫃台滿在末端排隊;
  架高 2.2(原 1.3)人從底下走;存檔 world.traps / baits / belts。服飾店挪到 x 64.5(傳送帶牌與輸入格才不壓到東柵欄)。
- 2026-11-04(離線收益,三題全選 a):1a 按實際收入速率:在線時記最近 5 分鐘賣出的錢(OfflineLogic,game.json offline.windowSec),
  存檔 world.income_rate 記每秒速率,讀檔用 savedAt 算離線秒數;2a 五折、上限 8 小時(rateMult 0.5 / maxSec 28800);3a 回來時彈面板
  (Hud.show_offline:「離開了 N 小時 M 分,幫手賺了 $N」+ 領取鈕,領取前 get_tree().paused、HUD 設 PROCESS_MODE_ALWAYS 才收得到按鈕)。
  我定的配套:不滿 60 秒(minSec)不算;教學沒做完不算;離線期間熊不來、幫手不會被吃(什麼都不模擬,只算錢);速率視窗裡還沒觀察到的部分
  用存檔帶進來的速率補(剛讀檔就關掉也不會歸零);領取 GameState.claim_offline 進錢包 + offline_earned 統計、EventBus.offline_claimed、goal 音效、
  $ 飛向錢包、通知、立刻存檔;存檔版本不升(舊檔沒 income_rate 當 0)。
- 2026-11-04(使用者:修掉體驗不好與區域重疊的地方,如收銀格與守衛塔重疊,用測試全過證明):加 tests/verify_layout 把全部占地(格子、工作站桌子、
  櫃台本體與排隊位、塔、捕熊夾、誘餌、水區、牆)蒐集起來兩兩查重疊(牌子就是地基的組合除外),並要求排隊位留在自己那塊地的柵欄內。修掉的:
  1 擴建區的 fillet_counter_2 / _3 收銀格壓在 tower_9 / tower_15 底下 -> 塔挪到上架格南邊(x 14.4 / 33.0);2 擴建區水區 16 寬把四角塔、捕熊夾、誘餌都泡在水裡
  -> 擴建區水區改 12 寬(Harbor.ANNEX_WATER_W,魚欄裝飾跟著縮);3 擴建區兩座櫃台各排 6 個顧客(每 1.3 格)會排進隔壁櫃台的上架格、穿過東柵欄 ->
  counters.json 的 maxCustomers 4 / queueSpacing 1.2(Counter 讀 def 蓋過 customers.max),櫃台改放 x 16.6 / 25.4、35.2 / 44.0(上架格貼西邊)。
  體驗(試玩機器人 notes 的紀錄為證):4 工作站塞住時玩家滿手來回搬成品,錢格堆到 $464 提示也不叫他收(錢包一直 $0,熊來了買不起武器)
  -> GuideLogic._work_hint 的「錢格 + 錢包買得起牌、錢包自己不夠 -> 先收錢」挪到塞住 / 買牌之前(空手時);5 撿毛皮一秒三則通知把「打跑熊了」立刻蓋掉
  -> Hud.show_notice 排隊:上一則顯示不到 0.9 秒就排隊,同一類(前 8 字相同)只更新最新的(notice_text / queued_notices 給測試)。
  6 武器打不過熊還一直重僱便宜幫手送死(機器人 20 分鐘停在武器 Lv1、幫手全被吃)-> BearLogic.outmatched(level, elapsed):殺 outmatchBears(2)隻的時間
  (ceil(血 / 攻擊力) × 間隔 × 2)超過咬一口 biteSec 就算打不過;GuideLogic 在「幫手被吃過 (helpers_lost > 0) 且打不過」時先存錢升級武器(武器牌買得起就指牌、
  錢格有錢先收、不然工作循環 + HINT_SAVE_WEAPON 還差 $N),不提其他牌(#8 挑最便宜只在打得過時適用)。同 seed 機器人:武器 Lv1 -> Lv3、打跑 18 -> 44 隻。
  沒改(使用者 10-28 裁示不改):塔價 $200 / 提示挑最便宜 / 熊群頻率,所以機器人 20 分鐘仍買不到塔、幫手仍會被吃完。
  7 機器人的「卡住」其實是提示箭頭來回翻:背著貨、櫃台快滿又沒人收銀,每賣一件提示就在上架格 / 收銀格之間翻一次,玩家在兩格之間來回跑
  (卡住紀錄裡速度是全速 6.5)-> GuideLogic 加遲滯:櫃台放不下整疊且有庫存又沒人收銀,先指收銀格賣到放得下再上架(空櫃台照舊先上架)。
  tools/playtest 的卡住紀錄多印速度 / 輸入 / 內部狀態,以後別再誤判成撞牆。
- 2026-11-04(使用者挑了四項版面調整,各選 a):1 顧客門:每塊地的東柵欄在顧客那排(CUSTOMER_DOOR_Z 9.2 ~ 11.2)只開視覺柵欄、隱形牆留著,門外一塊沙地路口
  (_add_doormat,柵欄拆了也留著);該塊地的櫃台顧客從門外 (柵欄 x + 1.5, 10.2) 出生、買完走回同一點(Counter.door 由 Harbor.customer_door(area_of_x(x)) 設;
  沒設 door 的櫃台照舊用 spawn_offset / exit_offset)。2 第三次擴建牌挪到 (36.4, 5)(z 5 唯一沒傳送帶經過的空隙);傳送帶架高 1.3 -> 2.2(conveyor.height,
  原本比人物 1.5 與牌子標籤 1.6 還矮),verify_layout 要求架高 >= 2.05 且帶子不穿過守衛塔。3 擴建區東側塔 / 捕熊夾改離東柵欄 2.3 格(tower_8 / 10 29.3、14 / 16 47.9、
  20 / 22 66.5,trap_4 / 6 / 8 同 x)。4 魚群上限按水面面積等比(FishArea.BASE_WATER_AREA 112 = 主村 16 × 7;擴建區水區改 11 寬 -> 12 條)。
- 2026-11-04(北極熊王獎勵循環,使用者選 1b 2a 3a):規則在 core/threat/king_logic.gd(KingLogic,數值 game.json bear.king.reward)。
  預告:王出場前 warnSec 45 秒 HUD 紅字倒數(EventBus.king_warning -> Hud.set_warning),期間一般熊群不來(BearSpawner.king_warning_active)。
  表現分:王在村裡期間 Harbor.king_eaten / king_wrecked(helper_eaten / station_destroyed / tower_destroyed 的 by 是王才算)-> grade() perfect ×2 / good(沒拆建築)×1.5 / normal ×1;
  連續 perfect 每層 +10%(上限 +50%),不是 perfect 歸零(GameState.king_streak)。1b 寶箱三選一:王倒下掉 Loot kind "chest"(data = KingLogic.chest:保底牙 3、
  現金卡 = 收入速率 × 90 秒 × 倍率(至少 $100)、毛皮卡 5 × 倍率、券卡依 couponWeights 2 / 2 / 1 抽保險 / 平靜 / 免費升級),玩家走到就開:牙進資源、Hud.show_choice 三選一、
  遊戲暫停(HUD ALWAYS),選了 action "choice:<i>" -> Harbor._claim_chest(現金進錢包 / 毛皮 / 券進 GameState.coupons;平靜券直接 bears.calm(120 秒一般熊不來,快照 calmLeft))。
  3a 王每打死一次 Lv +1(GameState.king_level,上限 10):血 ×(1 + 0.25 × 級)、體型 ×(1 + 0.05 × 級)、咬建築 ×0.9^級、寶箱 ×(1 + 0.2 × 級);王頭上 Lv 標籤;
  武器店屋頂戰利品牆每殺一次一顆頭骨(trophyCap 10),第 5 / 10 次里程碑永久背包 +1(GameState.king_slain)。
  2a 熊王祭壇(武器店院子,牌收熊王牙):altar_insurance 1 牙可重複(effect coupon insurance:被吃的幫手名額不扣、牌不漲,10 秒後 spawn_helper 回來,Harbor._insured)、
  altar_ice 3 牙一次性(unlock ice_traps:TrapLogic.ice 用 trap.ice 的 150 / 王 300 / 定住 6 秒,所有夾子一起)、嚇熊圖騰 totem_1 ~ 4 每塊地一座 2 牙
  (TOTEM_SPOTS 各塊地南側,牌隨擴建開;插了的那塊地一般熊群入口不選(BearSpawner._pick_entry 用 Harbor.has_totem(entry_area)),全插了照舊;王不受影響)。
  免費升級券:PricePad 站滿 payDelaySec 直接付清 effect upgrade 的牌(不扣錢)。存檔:GameState king_level / king_kills / king_streak / coupons、
  loot 多記 data(寶箱)、bear.calmLeft;圖騰靠 unlocked。
- 2026-11-04(使用者點名:寶箱卡片 UI、統計分頁、技術債全修):9 寶箱三選一改成卡片(Hud.show_choice 吃 [{title, desc, color}]:色塊 + 標題 + 說明,整張是按鈕;
  Harbor.chest_opened 的說明列倍率拆解 CHEST_MULT「表現 ×2.0｜連勝 N 層 +%｜王 Lv +% = ×總」,card_desc 說明現金怎麼算 / 券的用途);
  10 統計分三頁 TabContainer(經濟 / 幫手與熊 / 王與券,HUD_STATS_ECON / _HELPERS / _KING + HUD_COUPONS;stats_pages() / stats_text() 合併給測試,面板開著每 0.5 秒重算);
  11 docs/ 只放匯出成品(deploy_web 同步會清空),文件搬到 notes/(playtest 報告、model_candidates);12 verify_world 拆成兩段(見測試);
  13 熊王里程碑的背包 +1 改記 GameState.king_capacity_bonus(與 capacity 牌分開,Player 容量用 total_capacity_bonus());
  14 效能:HUD 錢包 / 背包文字只在數字變了才重排(_wallet_shown / _info_key)、Fx 幽靈與 HUD 的 $ 用物件池(飛完藏起來重用,Fx.pooled())、
  物理 30 Hz 只在網頁(project.godot physics_ticks_per_second.web=30,桌機與測試仍 60)+ physics_interpolation 開著讓 30 Hz 不抖;
  15 音效:warn(王來襲預告:倒數開始、每 15 秒、10 秒、3 秒)、chest(開箱)、card(選卡),tools/gen_sfx.py 可指定名字只產生那幾個。
- 2026-11-04(使用者:錢格堆到兩萬多,站著收太慢):MoneyPad 收錢速度改成 max(cashPickupPerSec 40, 堆 × cashPickupFrac 1.5) 每秒,
  堆越多收越快(指數衰減,每秒收掉約 78%,$20000 約 5 秒內收完,少量時仍是 40/秒);數值在 game.json。
- 2026-11-05(使用者點名三項:第四次擴建、刪圖騰、村外探險;第一項選 1a 2a 3a、第三項選 1a 2c 3b):
  1 第四次擴建往南:expand_village_4 $20000(牌在主村南牆邊 (-6.5, 11),擴建三次後出現;unlock village_5,annex 4 -> Harbor._build_south_block):
  拆主村南牆(south_walls:隱形牆 + 柵欄,留探險缺口)、SOUTH_RECT(x -12.6 ~ 12.6、z 12.6 ~ 30.6)沙地 / 東西南柵欄與隱形牆、魚湯廚房 kitchen (0, 18.5)
  (stations.json input 給陣列 ["fillet", "grilled"] -> soup,5 秒一碗)、魚湯櫃台 soup_counter (-3, 26.5) $15(顧客門在南塊東柵欄 SOUTH_DOOR_Z 27.5 ~ 29.5,
  customer_door_for 看 z > 12.6)、塔 tower_25 / 26 (±11, 16.5)、傳送帶 belt_kitchen(牌 (4, 22.5))、僱用名額第四次 expand(max_expansions 4:漁夫 11 / 搬運工 18 / 收銀員 10)、
  熊入口 entriesExpanded4 多南入口 (0, 34)。多原料工作站:StationLogic.inputs / counts(每種一堆、每堆上限 input_cap、每種都夠 input_per 才做一批,
  accepts / input_count_of / add_input_of / missing_input;舊的 input_id / input_count 對應第一種),Station 每種原料一個 StationPad(item)與堆(input_pads / input_piles,
  input_pad_for(item) / pile_top_for),PorterPlanner 的目的地每種原料一筆(id = instance id × 4 + 序號,來源 / 櫃台 id 也 ×4),Guide 的 station 狀態多 inputs / missing、
  提示帶 item 指對的格子;存檔 stations 多記 inputs。2 嚇熊圖騰整套刪掉(牌、TOTEM_SPOTS、has_totem、BearSpawner 的入口過濾、totem_planted)。
  3 村外探險:EXPLORE_RECT(x -40 ~ 90、z -12 ~ 50)四面空氣牆,出口三個:武器店院子西柵欄 EXIT_WEST_Z 0.8 ~ 3.2、最東那面牆 EXIT_EAST_Z -1 ~ 2(主村東門段改成
  缺口兩側兩小段 _set_east_exit,擴建後各塊東牆自己留)、南牆 EXIT_SOUTH_X -1 ~ 1(南塊蓋了換南塊的南牆);北邊是海沒出口。雪原上 LANDMARKS 岩石 / 枯樹 / 雪堆
  (沿用既有顏色,StaticBatch surface 不超);沒獎勵、沒熊(2c / 3b)。is_inside_village / player_outside / home_point(最近的出口外側),
  GuideLogic 在 state.outside 時最優先回 {kind home, HINT_HOME},Guide._resolve "home" 指 home_point;存檔 player 多記 x / z,讀檔站回原地(村外也是)。
- 2026-11-05(使用者點名七項;1 選 1c 2c 3a、2 ~ 5 全選 a、6 / 7 直接做):
  1 訂單系統:村外西北碼頭(Harbor.DOCK_SPOT (-30, -7.4) 交貨格 OrderDock + 貨船布景 BOAT_SPOT)停一艘貨船,OrderLogic(game.json orders)教學後 30 秒起每 150 × 0.85^擴建 秒
  (最低 60)貼一張限時 240 秒的訂單:2 ~ 3 種櫃台賣的貨(毛衣除外)各 6 + 3 × 擴建 件,25% 多要一條稀有魚;玩家或搬運工站交貨格就扣(搬運工:porter_dests 把碼頭當櫃台目的地,
  Harbor.route 給 WEST_ROUTE 五個中途點繞西門 / 院子缺口,回程倒著走);送齊現金 = 市價 × 2 直接進錢包 + 附贈(50% 毛皮 3 張 / 50% 一張券);逾時消失無懲罰。
  HUD 多一行訂單(Hud.set_order)、船上的牌寫內容、Guide 背著訂單要的貨時指碼頭(kind dock、HINT_order);存檔 world.orders。
  2 稀有魚:FishArea 每 60 ~ 90 秒偶爾生一條金魚(Fish.rare,金色 overlay、游速 ×1.8、150 秒沒抓游走;不在 fish 名單裡所以漁夫 / 王 / 提示不理),
  只有玩家(collects_cash)靠到 2 格內站滿 2 秒抓到(RareFishLogic,進度環,走開歸零)-> GameState.rarefish 資源(不佔背包,HUD_RES 顯示),換地圖碎片或交訂單。
  3 修理工:武器店院子牌 hire_repairman $300(maxBuys 1、每擴建 +1、被吃 1.5 買回),Helper role repairman:沒事站 REPAIRMAN_POST (-10.5, 2.4),
  有廢墟(Harbor.nearest_wrecked:工作站 / 塔)就走到建築南側 1.6 格站 15 秒(helpers.repairman.repairSec,頭上進度環)-> Harbor.repair_free 走修復牌的
  PricePad.complete_free(不扣錢、同一套 purchased 流程蓋回去);會被熊吃、嚇呆進度歸零。
  4 顧客成長:customers.perExpansion {max 1, intervalMult 0.85, wantShift 1, wantMax 9}:Counter.apply_expansion(擴建次數)(新櫃台生時、每次擴建 _apply_customer_growth)
  顧客上限 +1 / 次、生成間隔 × 0.85^n、wantWeights 往多件偏(CounterLogic.shift_weights;毛衣櫃台自己給 wantWeights 的不偏);第 base_max_customers 位之後排到第二排
  (slot_position:local -Z 1.2 格,櫃台北側);售價不變。
  5 地圖與旅行商人:村外東邊雪原營地 MERCHANT_CAMP (80, -6)(帳篷 / 營火 / 商人人物 / 招牌),牌 map_cash(costs 500 / 1500 / 5000)與 map_fish(currency rarefish,costs 3 / 5 / 8)
  擇一付,買了 GameState.map_pieces +1 並 _sync_map_pads 讓另一塊跟著跳下一片(PurchaseLogic.set_buys / PricePad.sync_buys),三片拼齊兩塊牌都消失;merchant_pelts $300 重複牌
  (effect resource pelt 5)。選單「地圖」頁 Hud.show_map(資料 Harbor.map_data):1 片畫村莊 / 擴建區 / 水區 / 武器店、2 片加雪原與碼頭 / 商人、3 片加未知區域「???」與「回村」鈕
  (action map_home -> 玩家傳回 PLAYER_SPAWN)。
  6 新版內容:data/changelog.json {versions: [{version, notes}]}(最新在前),Settings.seen_version(裝置設定,不在存檔)!= 最新版且有存檔就在開局彈 Hud.show_changelog
  (離線面板開著就下次再彈);新玩家直接記成看過;選單「新版內容」隨時可看。7 玩法說明:選單「玩法說明」Hud.show_help 六頁(HELP_TAB_* / HELP_*:基本操作 / 生產鏈 / 幫手 / 熊與武器 / 擴建 / 王與其他)。
  測試:world_test_base 建關卡後 orders.next_in = 1e9、FishArea.rare_auto = false(訂單 / 金魚只在測試指定時出現)。
- 2026-11-05(故事,使用者選 1b 古神「冰母」、2a 無名主角、3a 泡泡 + 日誌 + 章節短文;第二稿要求更沉重、克蘇魯式絕望結局;大綱 notes/story_outline.md):
  資料 data/story.json(chapters / journal 各帶 when 條件;lines{npc: [{when, keys}]} 取最後一個成立的;customerLines 依櫃台種類與階段),文字全在 strings.csv。
  純規則 core/story/story_logic.gd(StoryLogic:check(cond, state) / unlocked_chapters / unlocked_journal / npc_lines / customer_lines_for / stage early-late-ended / counter_kind)。
  節點 game/story/story.gd(Story,掛關卡下,群組 story):每 0.5 秒餵進度(GameState + expansion_level),新章節 -> GameState.story_add + HUD.show_chapter、
  新日誌 -> 通知;讀檔第一次 refresh 靜音(silent_first)。NPC 泡泡:老闆 / 船長(新加在甲板上,只有外觀 Harbor.captain)/ 商人 / 修理工,
  站 2.2 內滿 1 秒冒一句(輪流)、3.5 秒或走開收;跟修理工談過(南邊擴建後)記 flag repairman_talked -> 第一個荒年日誌。雪原地標走到 2.5 內記 landmarks。
  結局:三片地圖拼齊 -> 神龕(SHRINE_SPOT (86, -9) 雪原東北角,_build_shrine 外觀、牌 shrine 收 3 條稀有魚,_refresh_shrine)-> 付清 unlocked["shrine"] ->
  尾聲章節、顧客買到不道謝改面向北方(Customer.leave 問 Story.ended / customer_line)。存檔 GameState.story {chapters, journal, landmarks, flags}。
  選單多「日誌」頁(Hud.show_journal / journal_text,未解鎖 ???);章節短文面板 Hud.show_chapter(不暫停)。
- 2026-11-06(使用者點名三項,沒開問題):1 北極熊王等級上限 10 -> 5(bear.king.reward.maxLevel,舊檔 from_dict 夾回);2 守衛塔升級:玩家走到完好的塔旁
  tower.upgrade.radius 2.6 內(Harbor._update_tower_button 每幀找最近的,tower_upgrading)HUD 下方中央出現「升級」鈕(Hud.set_upgrade_button,搖桿排除區)
  -> 按了 action tower_upgrade_open -> Harbor.tower_upgrade_prompt -> Hud.show_tower_upgrade 面板(射速 / 傷害兩顆按鈕 + 關閉,不暫停;走開鈕收起、面板也關;
  原本「站滿 5 秒自動開」同日依使用者要求改掉),按了 action tower_up:rate / damage -> Harbor.tower_stat_upgrade:錢包扣 $500(cost)升一級,各最多 maxEach 10 次;
  射速每級射擊間隔 × rateMult 0.92(十級 0.35 秒)、傷害每級 +damagePerLevel 0.2 倍基礎(十級一般塔 30、強力塔 75);Tower.rate_level / damage_level 存檔 towers{rate, damage};
  3 衛兵:牌 hire_guard $300 固定價(costMult 1、maxBuys 4、被吃 1.5 買回)在南塊 (-8, 20),擴建四次(south_block)後才開;Helper role guard(helpers.guard:速度 5.4、
  damage 12、attackIntervalSec 0.6、attackRange 1.7、patrolWaitSec 1.5,models.roles.guard female-c):在 Harbor.patrol_points(每塊地四角內側 + 南塊四角)隨機巡邏,
  有活熊(含王,Harbor.guard_target 最近的)就衝過去打(hits_total),不會被嚇呆(set_panic 忽略)、會被吃。
  同日追加(使用者點名):衛兵外觀套盔甲(頭盔 / 胸甲 / 肩甲方塊)+ 右手斧頭(武器 Lv2 模型)+ 頭上「衛兵」標籤(Helper._dress_guard;Kenney 套件沒有盔甲人物);
  價格牌付錢加速:payPerSec 15 -> 20、payScaleCost 100 -> 25($25 以上的牌都約 1.25 秒付清,payDelaySec 0.6 不變所以走過仍不付)。
- 使用者習慣:每個系統先開放三個問題、以編號回答,確認後再實作;每個里程碑跑全部測試再 commit。

## 工作方式

- 型別化 GDScript,4 空白縮排。純規則類別放 `core/`(RefCounted,不依賴 Node / 場景 / Autoload,可 headless 測試);場景與節點放 `game/`;全域單例放 `autoload/`;數值資料放 `data/`(JSON / CSV)。
- 程式與資料鍵英文;遊戲內文字繁中,走 `data/locale/strings.csv` + `tr()`;新 UI 文字先加進 CSV 再用。CSV 裡的換行寫字面 `\n`(匯入時 c_unescape),不要放真的換行。
- 關卡用程式碼擺放(座標在關卡腳本),規則與數值在 `data/`;改數值不用動程式。
- 每個系統:討論 -> 定案 -> 實作 -> 跑全部測試 -> commit。里程碑與定案記在本檔。

## 目錄

- `core/data/game_data.gd`:GameData(靜態載入 game.json / items.json / stations.json / counters.json / shop.json;`section(key)`、`helper(role)`、物品尺寸 / 顏色 / 翻譯名)
- `core/economy/`:ItemStack(一疊同種物品,有容量)、StationLogic(原料堆(inputs 可多種,每種一堆 counts)-> 每批每種吃 input_per 個(inputPer,服飾店 5)-> 輸出堆,輸出滿停工,speed_mult,has_enough_input / missing_input;accepts / input_count_of / add_input_of / input_space_of,舊的 input_id / input_count 對應第一種)、PurchaseLogic(價格牌分期;repeatable / max_buys / cost_mult / buys,`complete()` 漲價、`restore(buys, remaining, lost)` 存檔還原;
  僱用牌 `lose()` 退名額、lost / rebuy_mult 買回價、is_rebuy;expand_buys / `expand()` 擴建村莊多開放名額(每次擴建一次,expansions <= max_expansions 3);currency cash / pelt / tooth、costs 逐次價、
  base_max_buys / `raise_max(n)` 武器店升級多開名額)、CounterLogic(庫存 / 售價 / 賣出;static roll_want(權重, roll) 顧客要幾件)、PorterPlanner(搬運工派工:need_of / plan / best_dest / best_source,吃字典清單;工作站原料區空且沒 blocked 回 EMPTY_INPUT_NEED 1.5 最優先)
- `core/economy/order_logic.gd`:OrderLogic(訂單:interval(擴建) / time_limit / per_kind(擴建) / pool(menu) / generate(menu, 擴建, roll_rare) / need_of / wanted_items / deliver / is_complete / complete
  / progress / tick(delta, 擴建) 回 new | expired | "" / snapshot / restore;RARE_ITEM "rarefish";數值 game.json orders)
- `core/fishing/rare_fish_logic.gd`:RareFishLogic(稀有魚:next_interval(roll) / lifetime / catch_radius / catch_sec / speed_mult / tick_catch(progress, delta, in_range) / is_caught;ITEM "rarefish";數值 game.json rareFish)
- `core/economy/offline_logic.gd`:OfflineLogic(離線收益:begin(t, 存檔速率) / record(t, cash) / rate(t) 最近 windowSec 的每秒收入(沒觀察到的部分用 seed_rate 補)、
  static offline_seconds(savedAt, now)、earnings(速率, 離線秒) = 速率 × min(秒, maxSec) × rateMult(不滿 minSec 回 0)、counted_seconds、static split_duration -> {h, m};數值 game.json offline)
- `core/input/move_input.gd`:MoveInput(螢幕方向 -> 世界 XZ;from_actions 鍵盤手把 + 觸控搖桿(static touch_dir,有推就以搖桿為準)、toward 合成輸入)
- `core/guidance/guide_logic.gd`:GuideLogic(教學七步的完成條件與指向、教學後的提示 hint();吃世界狀態字典,回 {kind, target, text, arg};
  北極熊在村裡(state.bear)最優先:沒武器指武器牌 WEAPON_PAD、有武器 kind "bear")
- `core/threat/king_logic.gd`:KingLogic(北極熊王獎勵循環:warn_sec / hp_mult / scale_mult / building_bite_mult / reward_level_mult(level)、grade(eaten, wrecked) / grade_mult / next_streak / streak_bonus / total_mult、
  cash_card / pelt_card / coupon_card(roll) / chest(...) 寶箱內容、calm_sec / insurance_return_sec、is_milestone / trophy_cap;數值 game.json bear.king.reward)
- `core/threat/trap_logic.gd`:TrapLogic(ice 冰封夾用 cfg.ice;捕熊夾 / 誘餌規則:damage(king) / stun_sec / radius / bait_radius / bait_eat_sec / bait_fish_count;static in_reach、pick_bait;數值 game.json trap)
- `core/economy/conveyor_logic.gd`:ConveyorLogic(傳送帶:length / speed / rate / spacing、items 位置陣列、tick(delta, 來源數, 櫃台空位) 回 {taken, delivered}、capacity / can_take、snapshot / restore)
- `core/threat/tower_logic.gd`:TowerLogic(守衛塔規則:hp(tier) / damage(tier) / max_tier(強力塔 tower.strong)/ attack_range / attack_interval / arrow_speed / bite_damage / bites_to_break(tier) / bite_sec /
  aggro_radius / height / dps / shots_to_kill;static pick_target(from, [{id, pos, alive}], range) 射程內最近的活熊;數值 game.json tower)
- `core/threat/bear_logic.gd`:BearLogic(北極熊規則:first_delay / interval / next_cooldown(等級, roll)/ bite_sec / bite_radius / panic_radius /
  speed / flee_speed / entries(expanded)/ pack_size(roll);難度曲線 ramp(elapsed) / interval(elapsed) / hp(elapsed);
  武器 weapon_level_cfg / weapon_damage / attack_range / attack_interval / can_attack / outmatched(level, elapsed) 打不打得過 / weapon_model;王 king_at_sec / king_respawn_sec / king_hp_mult /
  king_bite_sec / king_fish_bite_sec / king_building_bite_sec / king_scale / king_grow_helper / king_grow_fish / king_max_scale / king_heal_fish /
  king_heal_helper;drop(king) 掉什麼、shop_base_levels / weapon_levels_for_sale(shop_level) 武器店等級賣到第幾級;static pick_target 最近的獵物)
- `game/common/`:Carrier(CharacterBody3D 浮動模式、背上 ItemStack + StackVisual、旗標 can_fish / takes_output / collects_cash / can_serve / can_use_trash、stack_top 給飛行動畫、腳下 blob_shadow;model_name 有對應 GLB 就掛 CharacterModel 代替膠囊,move_toward_dir 每幀依速度餵 set_moving)、StackVisual(整堆一個 MultiMesh:物品在 items.json 有 model 就用 ModelLibrary.item_mesh / item_fit 的模型網格,否則方塊;換物品種類才重排位置,之後只改 visible_instance_count;uses_model 給測試)、ModelLibrary(靜態快取:character(name) / player_model / role_model / worker_model / customer_models 讀 game.json models;item_mesh / item_fit 把 items.json 的 model 等比例塞進尺寸框;water_fish;scene_aabb / first_mesh / mesh_instances / find_anim / local_xform 工具)、CharacterModel(人物 GLB:縮到身高、腳底貼 0、XZ 置中,idle / walk 循環;set_moving(速度比例)、set_action(動作, loop, speed)、clear_action、current())、StaticBatch(不會動的方塊 / 圓柱依顏色合併成一個 ArrayMesh,每色一個 surface)、VisualFactory(box / capsule / cylinder / cone / label / blob_shadow / 材質快取)、ProgressRing(平放進度環,ArrayMesh 弧,set_progress 量化重建)
- `game/player/player.gd`:Player(input_provider 可餵合成輸入;容量 = 設定 + GameState.capacity_bonus;can_serve / can_use_trash;
  weapon_prop 腰間武器,_refresh_weapon 依 GameState.weapon_level 換 weapon.levels[].model;_attack 每 attackIntervalSec 自動打最近、在 range 內的熊,hits_total)
- `game/world/order_dock.gd`:OrderDock(Pad,碼頭交貨格:有訂單時背著訂單要的貨的 carrier 站上來就扣,稀有魚從 GameState 資源扣;送齊叫 Harbor.order_completed;delivered_here)
- `game/npc/helper.gd`:Helper(role 決定狀態機:repairman 修理工 idle / to_post / to_repair / repairing(repair_sec、repair_progress、repaired_total,Harbor.nearest_wrecked / repair_spot / repair_free);fisher 水裡漫游被抓魚 -> 滿了去輸入格卸貨;porter 問 Harbor.find_porter_job(PorterPlanner)搬成品,狀態 to_pickup / picking / to_dropoff / dropping / returning / step_back;cashier 走到被指派櫃台的收銀格站著;數值 game.json helpers.<role>;北極熊:set_panic 嚇呆不動 + 驚嘆號 + emote-no、
  be_eaten 規則上立刻消失(分組 / 旗標 / 物理 / 格子)外觀縮小後釋放;go_to 覆寫:向 Harbor.route 要中途點(目前沒有牆要繞,回空)、卡住 1 秒重算 / 往目的地 z 方向滑 0.6)、
  `bear.gd`(Bear:king_level / king_logic 王的等級(血 / 體型 / 咬建築 / Lv 標籤);從 entry 進來,hunting 盯最近的幫手 -> 靠到 panicRadius 幫手嚇呆 -> biteRadius 內 biting 咬 biteSec 秒 -> Harbor.helper_eaten -> 找下一個;
  hp / hp_max = BearLogic.hp(play_time),take_hit 扣血閃紅、頭上血條,歸零 defeat 逃回 entry(fleeing);沒人可吃 leaving;is_king:體型 size_scale、
  連 Fish 也當獵物、_feast 回血變大、沒獵物就在村中間等;白方塊占位或 models.bear)、`customer.gd`(走到排隊位、等、買完原地 emote-yes 0.6 秒再離開,無物理;輪流用 models.customers 的人物模型,沒有就膠囊;泡泡顯示物品名 ×數量)
- `game/world/`:Pad(Area3D 基底,每幀對站著的 Carrier 呼叫 _on_carrier_stay,_budget 速率累加器)、StationPad(item 指定收哪種原料;原料是資源(GameState.is_resource:pelt / tooth)時 _resource_input:玩家站滿 resourceInputDelaySec 才從 GameState 扣)、Station(`Station.create(def)`;每種原料一個 StationPad(item)與堆:input_pads / input_piles / input_pad_for / pile_top_for;id kitchen 畫大鍋、tailor 畫衣架 + 毛衣,spot_id、apply_upgrades 吃 worker_speed / pile_cap、take_back 收回搬運工送不出去的成品;worker_model = models.worker 的人物,處理中播 interact-right)、FishArea(max_fish = maxInWater × 面積 / BASE_WATER_AREA)、Fish(水裡的魚:models.waterFish 的 FBX 模型 + 游泳動畫,縮到 length 長、頭朝 local +Z,被盯上蓋 material_overlay;沒模型就方塊)、Counter(`Counter.create(def)` 讀 counters.json(maxCustomers / queueSpacing 可蓋過 customers.max 與 1.3 間距);door 顧客門(spawn_point / exit_point);上架格 DepositPad + 收銀格 ServicePad + 排隊位 slot_position;顧客 want = roll_want(customers.wantWeights);`notify_server()` / `has_server()` 幀戳;cashier 指派;apply_upgrades)、CounterPad、ServicePad、MoneyPad(現金堆;收錢的 carrier 站上來收進錢包,速度 max(cashPickupPerSec, 堆 × cashPickupFrac);set_cash 還原)、PricePad(從錢包扣;_dwell 站滿 payDelaySec 才付,速率 × max(1, 價格 / payScaleCost);可重複牌、付清後需離開再踏上(_blocked)、
  on_lost 退名額重新開放並標「買回 ×1.5」(守衛塔牌標「修復」)、expand() 擴建多開名額、raise_max(n)、set_open(開關)、is_tower_pad / is_repair_pad、restore_state;
  currency 不是 cash 的牌從 GameState.resource 扣、標籤用 COST_<currency>)、Loot(掉落物 pelt / tooth / chest(熊王寶箱,data 存內容,踩到叫 Harbor.chest_opened):浮動旋轉,玩家走到 lootPickupRadius 內 collect -> GameState.add_resource、
  EventBus.loot_collected、Harbor.loot_collected;snapshot {kind, x, z})、
  Trap(捕熊夾,Node3D 無物理:armed、arm() / trigger(bear) 扣血 + stun、每幀找群組 bear 裡活著且在 radius 內的、snapshot / restore)、
  Bait(誘餌魚堆:placed、lure_radius / eat_sec、place() / consume(by) -> Harbor.bait_eaten、StackVisual 魚堆外觀)、
  Conveyor(傳送帶:setup(id, station, counter) 從輸出格架到上架格,每幀 logic.tick 搬貨、帶上的貨用物品模型 / 方塊、橫紋會跑、snapshot / restore)、
  Tower(守衛塔,Node3D 無物理:state none / alive / broken、tier 0 / 1(upgrade() 熊王牙強化:血 2000、每箭 25、金環金旗,is_strong),build(silent) / take_bite(damage, by) / wreck(by)(王直接拆)-> 塌了叫 Harbor.tower_destroyed、
  每 attackIntervalSec 對射程內最近的活熊射 Arrow(內部類別,追著熊飛,到了 _arrow_hit -> Bear.take_hit + on_tower_hit)、
  血條 / 射程環 / 守衛(models.guard 人物)/ 廢墟外觀、snapshot / restore)、TrashPad(玩家站上丟掉背上所有貨物,GameState.add_trashed)、BearSpawner(king_logic、king_warning_active / king_warning_left 預告、calm(sec) / calm_left 平靜券;掛在關卡下:村裡有幫手才倒數,第一群 firstDelaySec、
  整群走光才 next_cooldown(遊戲時間越久越密);一次 pack_size 隻從同一入口排開;bears / has_bear / has_pack / first_bear / nearest_bear / targeted_ids;
  王:king / king_next_sec,play_time 到 king.atSec 自動 spawn_king,打死後 respawnSec 再來;spawn(prefer) / spawn_pack(n) / spawn_king() 強制出現、
  enabled 給測試關掉;snapshot / restore 記冷卻秒數(熊在場時存 8 秒)與 kingNextSec)
- `game/camera/follow_camera.gd`:跟隨相機(從 +Z 側俯視,螢幕上 = 世界 -Z);直式(高 >= 寬)KEEP_WIDTH、fov 40、偏移 (0, 13.5, 9.5),橫式 KEEP_HEIGHT、fov 42、偏移 (0, 17, 11.5),視窗轉向時重算
- `game/ui/hud.gd`:Hud(class_name):訂單一行 set_order / order_text;地圖頁 show_map / map_open / map_home_visible(map_source 由關卡給 map_data,_draw_map 畫;panel_action map_home / map_close)、
  玩法說明 show_help / help_open / help_tab_count、新版內容 show_changelog / changelog_open / changelog_text(panel_action help_close / changelog_close);選單多 map / help / changelog;三選一卡片面板(show_choice(title, body, [{title, desc, color}]) / choice_action(i) 發 action "choice:<i>" / choice_open / choice_count / choice_title)、統計分頁 stats_pages / stats_text / stats_tab_count、set_warning 紅字警告、通知排隊(show_notice 上一則不到 0.9 秒就排隊、同類只留最新)、離線收益面板(show_offline(cash, 離線秒, 算進的秒) 半透明遮罩 + 置中面板 + 領取鈕,offline_action("claim") 發 action "offline_claim";offline_open / offline_cash、income_rate 給統計)、錢包 / 背包內容 / 統計(HUD_STATS 九個參數)/ 上方目標文字(set_objective,Guide 餵)/ 通知 / 操作提示(觸控裝置用 HUD_HINT_TOUCH);右上角選單鈕 + 面板(menu_action:toggle / hints / sound / new_game 兩次確認 / close,hints 與 new_game 用 action 訊號交給關卡);聽 items_moved "cash" 畫 2D 的 $ 飛向錢包
- `game/ui/touch_joystick.gd`:TouchJoystick(鋪滿畫面最底層、mouse_filter IGNORE;_unhandled_input 收 ScreenTouch / ScreenDrag,按下點為中心、RADIUS 90、只跟第一根手指、exclusions 範圍不算;handle_event 給測試)
- `game/ui/guide.gd`:Guide(Node3D,掛在關卡下):每 0.1 秒把關卡狀態餵 GuideLogic,推進教學(GameState.tutorial_step)、解析目標座標、畫玩家頭上箭頭 + 目標彈跳箭頭、餵 HUD 文字;toggle_hints(H)
- `game/levels/harbor.gd` + `harbor.tscn`(主場景):SOUTH_RECT / south_walls / south_block / _build_south_block 第四次擴建(往南)、EXPLORE_RECT / EXIT_* / LANDMARKS / _build_exploration / _set_east_exit / exit_east_walls / is_inside_village / player_outside / home_point 村外探險、_gap_segments、customer_door_for、king_logic / king_eaten / king_wrecked / _king_slain(寶箱)/ chest_opened / _claim_chest / pending_chest、trophies / _refresh_trophies、_insured 保險券回來、ALTAR_SIGN 祭壇、offline(OfflineLogic,聽 sale_made 記收入;snapshot 多 income_rate、_load_save 算 _offline_pending 與 offline_sec,_ready 最後 _show_offline 暫停、_claim_offline 領取;_exit_tree 解除暫停)、星港漁市,座標常數 STATION_SPOTS / STATION_DEFS / COUNTER_SPOTS / PAD_SPOTS / UNLOCKS;_on_purchased 生幫手與解鎖建築;porter_dests / porter_sources 餵 PorterPlanner,find_porter_job / find_dest_for / find_station_* 給幫手找目標;snapshot / restore_world / save_now / _load_save / new_game;
  顧客門 CUSTOMER_DOOR_Z / customer_door(area) / area_of_x / _fence_segments / _add_doormat、西牆缺口 GATE_Z、_build_outside 村外武器店院子(店屋 WEAPON_SHOP、老闆 shopkeeper、武器牌 PAD_SPOTS.weapon)、bears(BearSpawner)、
  helper_eaten 結算被吃的幫手(hire_pad_for(role).on_lost);守衛塔 TOWER_SPOTS 主村六座 + 每塊擴建區六座(牌子位置直接取 TOWER_SPOTS;tower_area(id) 屬於哪塊地)、towers / _build_towers /
  tower_by_id / tower_pad_for / tooth_pad_for / alive_towers / tower_destroyed(牌 on_lost 修復價)/ _refresh_tower_pads(熊王牙牌只在塔完好未強化時開),_on_purchased "tower" 蓋 / 修、
  "tower_upgrade" 強化、"shop_upgrade" -> _apply_shop_level(武器牌 raise_max、招牌 shop_sign 顯示等級);掉落物 loot / drop_loot / loot_collected / _on_bear_defeated(熊被打跑掉毛皮、王掉熊王牙);東牆 east_walls(三段隱形牆 + 柵欄,擴建時整面拆;east_gate / east_gate_mesh 是門那段)、_build_annex 擴建區
  (_build_annex(k):ANNEX_RECTS[k-1] 沙地、柵欄、隱形牆、深水池、FishArea<k+1>;東牆記在 annex_east_walls 下一塊拆)、annexes / expansion_level / fish_areas / nearest_fish_area / pick_fish_area(漁夫挑人少的水區)、is_expanded、
  route / gate_point(東牆拆了之後回空 / 原點,留給 Helper.go_to 以後補規則)、fish_eaten(王吃魚)、_physics_process 累加 GameState.play_time
- `autoload/event_bus.gd`:king_warning(sec) / chest_opened / chest_claimed / king_leveled / helper_insured / offline_claimed(cash, sec)/ fish_caught / items_processed / sale_made / cash_collected / purchase_progress / purchased / helper_hired / notice / items_moved(kind, item, from, to, count)/ tutorial_step_done / tutorial_finished /
  bear_appeared / bear_biting / bear_hit(bear, damage, hp_left)/ bear_defeated / bear_left(reason fled | no_prey)/ helper_eaten(role, helper)/ fish_eaten / bear_fed /
  tower_built / tower_shot / tower_damaged / tower_destroyed / station_destroyed / station_repaired / loot_dropped(kind, pos)/ loot_collected(kind, total)/ shop_upgraded(level)/ tower_upgraded(tower)
- `autoload/settings.gd`:Settings(裝置偏好,user://settings.json 與存檔分開:quality smooth / fine、show_fps、seen_version(看過的新版內容版本,mark_version_seen);沒檔案時觸控裝置預設 smooth;is_touch_device、scaling_3d、toggle_quality、changed 訊號)
- `autoload/sfx.gd`:Sfx(聽事件播 assets/sfx/<name>.wav,10 個 player 輪播、每種最短間隔、環境音執行期開 loop;played 計數給測試;
  北極熊 roar(出現 / 被打跑)、chomp(吃掉幫手 / 魚)、hit(打到熊)、arrow(守衛塔射箭)、crash(塔塌 / 工作站被拆)、pick(撿掉落物)、unlock(武器店升級 / 塔強化)、warn(王預告)、chest(開箱)、card(選卡))
- `autoload/fly_fx.gd`:Fx(聽 items_moved 生物品幽靈拋物線飛,掛在自己底下,幽靈節點物件池 _pool / pooled();kind "cash" 交給 HUD)
- `tools/gen_sfx.py`:純 Python 合成占位音效(正弦 / 噪音 / 包絡),輸出 assets/sfx/*.wav(22050 Hz 16-bit mono);命令列給名字只產生那幾個(`python tools/gen_sfx.py warn chest card`)
- `tools/gen_icons.py`:Pillow 畫占位圖示(assets/icons/icon_128 / 144 / 180 / 512.png)與啟動畫面 splash.png
- `tools/inspect_models.gd`:headless 印出模型場景結構(節點、網格 AABB、材質、骨架 rest 位置、動畫清單);
  `godot --headless --path . --script tools/inspect_models.gd -- res://assets/models/game/characters/character-male-a.glb`
- `assets/models/game/`:遊戲實際載入的模型(characters/ Kenney Mini Characters 12 個人物 GLB + Textures/colormap.png、props/ Survival Kit 的 fish / tool-hammer / tool-axe / tool-axe-upgraded GLB、
  fish/ Quaternius 魚 FBX ×3),來源與授權見裡面的 CREDITS.md;原始套件放 `assets/models/<套件名>/`,內含 `.gdignore`(不匯入、不匯出),git 不追蹤
- `tools/snap_scene.tscn` + `.gd`:開小視窗跑主場景、把玩家 / 熊擺到幾個位置截 PNG(村子、武器店、熊咬幫手、Lv3 武器),接新外觀時看一眼用;
  `godot --path . --resolution 900x900 res://tools/snap_scene.tscn -- <輸出資料夾>`(要用場景跑,`--script` 模式沒有 Autoload)
- `tools/playtest.tscn` + `.gd`:自動試玩機器人(照 Guide 提示走、熊照正式規則來;工作站塞住 / 櫃台滿 / 牌子沒錢時做真人會做的事),
  印每 10 秒狀態、購買 / 被吃 / 熊事件與 SUMMARY;`godot --headless --path . res://tools/playtest.tscn -- <分鐘 20> <倍速 4> <seed>`;報告在 notes/playtest_2026-10-28.md
- `tools/serve_web.py`:本機預覽 build/web(0.0.0.0,印 iPhone 可用的區網網址;8080 被台股 App 佔著,用 8090);`.claude/launch.json` 的 `web`
- `tools/deploy_web.py`:`--export-release Web` -> 同步到 `docs/`(Pages 從這裡發布)-> 只 commit docs/ -> push origin main;`--export-only` / `--no-export` / `--no-push`
- `tools/setup_cloud.sh`:Linux / 雲端裝 Godot 4.7(~/godot/godot)+ 可選 `--templates` 匯出模板,並先 --import 兩次;`tools/run_tests.sh`:bash 版測試跑法(timeout 600 / 個)
- `export_presets.cfg`:Web 預設(不開執行緒、PWA 開、直式、圖示指到 assets/icons);`assets/fonts/NotoSansTC-VF.ttf`(OFL,見 LICENSE.md)是遊戲內唯一的中文字型
- `autoload/game_state.gd`:rarefish / map_pieces(MAP_PIECES 3,has_full_map)/ orders_done / orders_cash(complete_order 進錢包)、apply_purchase 多 map_piece / resource;king_level / king_kills / king_streak / king_capacity_bonus(total_capacity_bonus() = capacity 牌 + 里程碑)/ coupons(coupon / add_coupon / use_coupon,effect type coupon)/ king_slain(new_streak, logic)、wallet(add_wallet / spend / claim_offline 離線收益進錢包 + offline_earned 統計)/ tutorial_step / hints_on / capacity_bonus / unlocked / hired / upgrades / weapon_level / helpers_lost / play_time /
  pelts / teeth / shop_level(resource(kind) / add_resource / spend_resource,kind cash / pelt / tooth)/ 統計(含 items_trashed);
  apply_purchase(effect type:capacity / hire / unlock / upgrade / weapon / shop_upgrade;tower / repair / tower_upgrade 只記 unlocked)、lose_helper(role)、upgrade_mult、to_dict / from_dict
- `autoload/save_manager.gd`:存檔 IO(user://manlife_save.json,VERSION 2;has_save / write / read / delete;測試改 save_path)
- `data/changelog.json`:新版內容 {versions: [{version, notes: [...]}]}(最新在前;GameData.changelog / latest_version);每次部署新功能記得加一版
- `data/config/game.json`(orders 訂單、rareFish 稀有魚、customers.perExpansion 顧客成長、helpers.repairman {speed, capacity, repairSec}、models.roles.repairman;offline {windowSec, minSec, maxSec, rateMult} 離線收益;bear.entriesExpanded2 / 3 第二 / 三次擴建的入口;resourceInputDelaySec 服飾店放毛皮前要站多久):速度、容量、搬運速率(transferPerSec / cashPickupPerSec / payPerSec / payDelaySec / trashPerSec)、魚群、顧客、autosaveSec、helpers、upgrades、models(人物 GLB 資料夾與身高、player / worker / roles / customers / shopkeeper 用哪個人物、waterFish、
  bear.file 可選的熊模型)、bear(enabled / firstDelaySec / intervalSec / intervalMin / rampStartSec / rampSec / hpBase / hpPerMin / packChances /
  speed / fleeSpeed / biteSec / biteRadius / panicRadius / entries / entriesExpanded / length / king {atSec, respawnSec, hpMult, biteSec, fishBiteSec, buildingBiteSec, scale,
  growHelper, growFish, maxScale, healFish, healHelper, drop}、drop)、tower(hp / damage / … / strong {hp, damage})、weapon(attackIntervalSec、shopBaseLevels、levels[] ×6 damage / range / model)、
  lootPickupRadius、payScaleCost、customers.wantWeights、
  (weapon.levels 見上);`data/items.json`(fish / fillet / grilled / cash;`model` {file, rotationDeg} 指定物品模型,目前只有 fish);`data/stations.json`(cutting_table、grill、tailor 毛皮 -> 毛衣 inputPer 5、kitchen 魚片 + 烤魚 -> 魚湯 5 秒);`data/counters.json`(fillet_counter $2、grill_counter $5,擴建區的 *_counter_2 / *_counter_3,第三塊的 sweater_counter $200 wantWeights [1]、南塊的 soup_counter $15);`data/shop.json`(九十四塊牌:熊王祭壇 altar_insurance / altar_ice;含村外的 weapon、$1000 / $2000 / $8000 / $20000 的 expand_village / _2 / _3 / _4、二十六座守衛塔 tower_1 ~ 26、收毛皮的 shop_upgrade、收熊王牙的 tooth_tower_1 ~ 26、十三條傳送帶;僱用牌 rebuyMult 1.5;頂層 repairStation 工作站修復價);
  `data/items.json`(多 pelt / tooth 給飛行幽靈用、sweater 毛衣);shop.json 共九十八塊牌(多 hire_repairman $300、map_cash / map_fish 地圖碎片、merchant_pelts 毛皮補給);game.json 另有 upgrades.porter_cap(perLevel 4)、trap {damage, kingDamage, stunSec, radius, bait {radius, eatSec, fishCount}}、
  conveyor {itemsPerSec, speed, spacing, height};shop.json 多 upgrade_porter_cap、trap_1 ~ 8、bait_1 ~ 4、belt_<工作站> ×12;`data/locale/strings.csv`

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
- 模型:人物統一「腳底 0、local +Z 是臉」(Kenney Mini Characters 本來就朝 +Z,從 pick-up 動畫的 torso 往 +Z 彎確認過),
  CharacterModel 把 GLB 等比例縮到 models.characterHeight(1.5;顧客 customerHeight 1.3;工人 ×0.95),背上堆疊放在 model.height + 0.05;
  動畫只靠速度比例切 idle / walk,工作站工人 set_action("interact-right", true, speed_mult)、顧客買到 set_action("emote-yes", false)。
  物品模型:items.json `model` 指定檔案與 rotationDeg,ModelLibrary.item_fit 等比例塞進 size 框、XZ 置中、底貼框底(魚側躺:rotationDeg [90, 0, 0],
  size 改成模型比例 0.7 × 0.23 × 0.36);StackVisual 與 Fx 幽靈共用同一網格與變換,堆疊高度仍只看 size。水裡的魚:縮到 waterFish.length,頭朝 +Z
  (Quaternius 魚的 Face 骨頭在 +Z)。沒有模型(或資料裡拿掉)一律退回方塊 / 膠囊,舊外觀與測試都還能跑。
- 北極熊:規則在 BearLogic、節點 Bear(無物理,穿牆)、出沒由 BearSpawner(遊戲時間 < firstAtSec 不來;一群吃滿 packMaxEats 個 -> 全部 retreat);幫手被吃 = Harbor.helper_eaten(名單移除、櫃台 cashier 清掉、
  GameState.lose_helper 角色計數 -1、僱用牌退名額)。打熊:Player._attack 每幀找群組 "bear" 裡 alive() 且最近的,距離 <= attack_range 且計時到就
  take_hit(weapon_damage);Lv0 攻擊力 0 永遠打不了。血條歸零 -> defeat -> fleeing 回 entry -> left("fled")。被咬的幫手 panicked 時
  _physics_process 直接停住(旗標照舊,所以站在收銀格的收銀員仍會賣)。遊戲時間 GameState.play_time 由 Harbor 每幀累加(存檔),
  BearLogic.hp / interval / ramp 都吃它;王的出場也看它(king_next_sec)。熊吃過東西後沒獵物不走(_linger 在村裡晃),沒吃過才 leaving;
  玩家有武器且熊在 busyRadius 內 Player 關掉 can_fish / takes_output(追熊不順手抓魚)。掉落數 BearLogic.drop_count(king, roll)。王吃魚:Harbor.fish_eaten -> FishArea.remove_fish。
  熊出沒前提是 level.helpers 非空(教學期間不會來);存檔只記冷卻秒數。村外院子:西牆缺口 GATE_Z、院子有自己的隱形牆;
  走到村外要先到缺口(測試 _go_outside),直線會撞牆。新增武器等級只加 weapon.levels 一項並把 shop.json 的 maxBuys 加一。
  成群:BearSpawner 一次 spawn_pack(pack_size(randf())) 隻,同一入口沿 z 每 2.2 排開,Bear._retarget 先避開別隻已盯的幫手;
  每隻各自 left -> bear_left 事件,最後一隻(不含王)走了才設冷卻、才發 NOTICE_BEAR_FLED / LEFT;王走了發 NOTICE_BEAR_KING_DEAD 並排 respawn。
- 幫手走位:Carrier.go_to 是直線;Helper.go_to 覆寫成「目的地變了就向 Harbor.route 要中途點」(中途點 0.8 內換下一個),
  速度低於 20% 超過 1 秒算卡住:重算路線,沒中途點就往目的地 z 方向滑 0.6。擴建後東牆整面拆掉,所以 route 目前永遠回空;
  曾試過「留東門、繞門口中途點」,玩家實測搬運工還是會卡在門外的牆上(目的地貼著牆、斜向撞牆滑不進缺口),所以改成不留牆。
  以後加新的牆就在 route 補規則,tests/verify_nav 用擴建後的搬運工 / 漁夫來回驗證。
- 守衛塔:六座 Tower 一開始就在(state none;四角 + 中央 x ±3 / z -2.9),牌(effect tower、target 塔 id)付清 -> GameState.apply_purchase 只記 unlocked -> Harbor._on_purchased
  tower_by_id(target).build()。塔每幀自己找群組 "bear" 裡 alive() 且射程內最近的(TowerLogic.pick_target)射 Arrow,箭到了才 take_hit(傷害, tower)
  並 Bear.on_tower_hit(塔在 aggroRadius 內、沒在咬東西就改盯塔);Bear._retarget 也把 aggroRadius 內的完好塔當目標(幾隻可一起拆),
  咬塔的距離 = bite_radius × 體型 + 0.7,咬一口 TowerLogic.bite_sec 扣 bite_damage(hp 800 / 40 = 20 口),沒塌繼續咬。塌了:Tower._collapse ->
  Harbor.tower_destroyed -> tower_pad_for(id).on_lost()(lose():buys 0、lost 1、修復價 = cost × rebuyMult 1)-> 付清 complete 再 build。
  存檔 world.towers{id: {state, hp}};舊檔沒這段就看牌買過沒。塔的 Bear.take_hit(by) 是 Node3D(玩家或塔),bear_defeated 的 by 也是。
- 北極熊王拆建築:Bear._retarget 在 is_king 時把所有完好的 Tower 與 Station 都放進獵物(不限 aggroRadius),_bite_sec_for 對建築回
  king_building_bite_sec(10),咬滿 _eat -> Tower.wreck / Station.wreck(不看血量);吃魚 / 幫手 _feast 只變大(heal 0,血量等比例跟著上限漲)。
  Station.wreck:set_broken(true)(桌子 _built 藏、_rubble 顯示、工人不見、兩個 StationPad monitoring / physics 關、堆留著、logic 停工)
  -> EventBus.station_destroyed -> Harbor.station_destroyed -> repair_pad_for(spot_id).on_lost()(牌 repair_<spot_id>,_add_station 時生在桌子位置、
  restore_state(1, 0) 當作已買藏著)-> 付清 _on_purchased "repair" -> Station.repair()。Harbor.find_station_* / porter_dests / porter_sources
  與 Guide 的 stations 都跳過 is_broken() 的;存檔 world.stations{spot: {input, output, broken}},restore 後廢墟的修復牌一定 on_lost 開著。
  咬工作站的距離 = bite_radius × 體型 + 1.0。工作站修復價在 shop.json 頂層 repairStation.cost(GameData.repair_station())。
- 掉落物 / 資源:Bear.defeat -> EventBus.bear_defeated -> Harbor._on_bear_defeated -> drop_loot(BearLogic.drop(is_king):pelt / tooth)在熊的位置生 Loot;
  Loot 每幀看玩家距離 <= lootPickupRadius 就 collect(GameState.add_resource、items_moved "loot" 飛向玩家、notice NOTICE_LOOT_<kind>)。資源不佔背包,
  HUD 統計顯示。價格牌 currency 不是 cash 時 PricePad 從 GameState.resource(currency) 扣(payPerSec 同速率),Guide 的 _cheapest_pad 把資源夠的牌當最優先、不夠的跳過。
- 武器店等級:GameState.shop_level(apply_purchase "shop_upgrade" +1)-> Harbor._apply_shop_level:武器牌 raise_max(BearLogic.weapon_levels_for_sale(shop_level)
  = shopBaseLevels 3 + 等級,上限 levels.size)讓買滿消失的武器牌重新出現、價格接著 ×1.7(Lv4 $172 / Lv5 $292 / Lv6 $497),招牌換 SIGN_WEAPON_SHOP_LV。
  讀檔時 _load_save 在 restore_world 之前先 _apply_shop_level,武器牌的 buys 才不會被夾回 3。升級牌 shop_upgrade 用 costs [5, 10, 20](PurchaseLogic.costs 蓋過 cost × costMult)。
- 強力守衛塔:熊王牙牌 tooth_tower_n 在塔底下(PAD_SPOTS 同塔位置,label 拉高到 6.4),Harbor._refresh_tower_pads 只在塔 alive 且 tier 0 時 set_open(true)
  (蓋好 / 修好 / 讀檔 / 拆掉都重算);付清 _on_purchased "tower_upgrade" -> Tower.upgrade():tier 1、hp_max = TowerLogic.hp(1)、血回滿、Arrow 傷害 damage(1)。
  存檔 towers{id: {state, hp, tier}};拆掉修好仍是 tier 1。
- 擴建名額:UNLOCKS.village_2 / 3 / 4 的 expandShop -> 所有 PricePad.expand():PurchaseLogic.expand() 把 max_buys 加 expandBuys(每次擴建一次、最多三次),買滿的牌重開、
  remaining 設成下一級價。讀檔順序 _spawn_unlock(expand)在 restore_world(restore 夾在新的 max_buys 內)之前,所以不用存。
- 買回:幫手被吃 -> Harbor.hire_pad_for(role).on_lost() -> PurchaseLogic.lose()(buys -1、lost +1、價格 × rebuy_mult、已付保留)
  -> 牌子 _enable 重新出現。complete() 時 lost -1 回正常階梯。存檔 pads 多記 lost。
- 版面:新加會占地的東西(格子、塔、夾、誘餌、水區、牆、櫃台排隊位)跑 tests/verify_layout 看有沒有壓到別人(含南塊與探險的空氣牆 / 出口);擴建區只有 18.6 寬,水區 11 寬(ANNEX_WATER_W)、
  兩座櫃台的上架格貼西邊、各排 4 個顧客、顧客從該塊地東柵欄的顧客門進出;新的「牌子就是地基」組合要加進 verify_layout._allowed。
- 擴建(village_2 / 3 / 4):UNLOCKS 的 `annex: k` 讓 _spawn_unlock 先 _build_annex(k)(k = 1 拆整面東牆 east_walls,k >= 2 拆前一塊的東牆 annex_east_walls[k-2];蓋 Annex<k> StaticBatch、FishArea<k+1>),
  再生那塊的建築(k = 1:station_3 / grill_2 / *_counter_2;k = 2:station_4 / grill_3 ~ 5 / *_counter_3;k = 3:grill_6 / grill_7 / tailor / sweater_counter;座標在 STATION_SPOTS / COUNTER_SPOTS)。
  擴建區的塔牌與下一次擴建牌(expand_village_k 要擴建 k - 1 次後才出現)靠 _refresh_tower_pads 開關(建關卡、擴建、讀檔時都重算)。
  服飾店鏈:玩家站服飾店輸入格放毛皮(資源)-> 工人 5 張做一件毛衣 -> 搬運工 / 玩家送毛衣櫃台 -> 顧客一次買一件 $200。多水區:Harbor.fish_areas,漁夫在 idle -> fishing 時 pick_fish_area
  (漁夫最少、再最近),Guide 指 nearest_fish_area;熊的入口擴建後換 entriesExpanded。東牆沒拆前 x > 12.6 走不過去。
- 捕熊夾 / 誘餌 / 傳送帶:Trap / Bait 跟塔一樣一開始就在(TRAP_SPOTS / BAIT_SPOTS,牌子同位置),買了 _on_purchased "trap" / "bait" -> arm() / place();
  Trap 自己每幀偵測熊(不靠 Bear),夾到 -> Bear.stun + take_hit(by = Trap)-> Harbor.trap_used -> 牌 on_lost 同價重現;Bear._hunt 在 hunting 時每幀 _nearest_bait
  (level.baits、lure_radius)改盯誘餌,_bite_sec_for(Bait) = Bait.eat_sec,_eat 時 consume -> Harbor.bait_eaten -> 牌 on_lost。
  傳送帶 Conveyor 掛在 world 下、conveyors 清單;牌 effect conveyor、target = CONVEYORS 的 id,_refresh_tower_pads 只在兩端都在且還沒蓋時開;
  讀檔 _load_save 依 GameState.unlocked 先 build_conveyor(silent) 再 restore_world 還原帶上的貨。帶子只搬工作站輸出堆 -> 櫃台,搬運工照舊可以搶同一堆。
- 離線收益:Harbor.offline(OfflineLogic)聽 sale_made 記 (play_time, cash),snapshot 存 income_rate;_load_save 時 offline_sec = now - savedAt,
  教學做完且 earnings > 0 就在 _ready 最後 _show_offline(hud.show_offline + get_tree().paused = true、hud.process_mode ALWAYS);領取鈕 -> action "offline_claim"
  -> _claim_offline(解除暫停、GameState.claim_offline、offline_claimed 事件、items_moved "cash" 從玩家頭上飛向錢包、通知、save_now)。暫停時 play_time 不走、
  自動存檔不跑(沒領就關掉,下次回來照舊算);_exit_tree 解除暫停免得換場景卡住。測試要離線收益就改存檔 JSON 的 savedAt / world.income_rate 再重建關卡。
- 北極熊王獎勵循環:BearSpawner 在 king_next_sec 前 warnSec 秒進入預告(每秒 king_warning,HUD 紅字;一般熊冷卻暫停),王出場 Harbor 把 king_eaten / king_wrecked 歸零;
  Bear.defeat -> Harbor._on_bear_defeated 看到王 -> _king_slain:KingLogic.grade / chest(含 streak)、GameState.king_slain(升級 / 擊殺 / 連勝 / 里程碑)、drop_loot("chest", pos, data)、
  _refresh_trophies、save。Loot chest 踩到 -> Harbor.chest_opened(牙進資源、hud.show_choice、paused)-> 按鈕 action "choice:i" -> _claim_chest(解除暫停、發 chest_claimed、save)。
  王倒在玩家腳邊時寶箱通常當場就開(測試要同時接受 choice_open 與 has_king)。券:insurance 在 helper_eaten 先 use_coupon(名額 / 牌都不動,_insured 排 10 秒後 spawn_helper);
  calm 選卡時直接 bears.calm;upgrade 在 PricePad._on_carrier_stay 站滿 payDelaySec 就 pay(remaining) 完成。圖騰:牌 effect totem、_on_purchased 重畫 _refresh_totems,
  冰封夾:unlock ice_traps,Trap.trigger 時把 logic.ice 設成 is_unlocked。
- 第四次擴建 / 探險:UNLOCKS.village_5 的 annex 4 -> _build_annex(4) 轉 _build_south_block(不在 ANNEX_RECTS 裡,area_of_x 仍只看東邊三塊;expansion_level() 算
  annexes.size() 所以南塊算第 4 次:tower_25 / 26 的牌、entriesExpanded4、expand_village_4 牌只在擴建三次後且南塊沒蓋時開)。新的「牆 + 柵欄」一律留缺口
  (_gap_segments),出口座標見 EXIT_*;走出村子只有距離成本,幫手不會跟出去,村裡的熊照來;home_point 給提示箭頭。多原料工作站加新的時 stations.json input 給陣列即可,
  格子從左到右照 inputs 順序排(每格間隔 2.6)。
- 顧客數量:want 由 CounterLogic.roll_want 抽(擴建後 Counter.apply_expansion 把權重往多件偏、顧客上限 +1 / 次、間隔 × 0.85^n;超過一排排第二排),泡泡顯示 ×N,serve(want) 賣 min(want, 庫存) 就走(不等補貨)。
- 訂單 / 碼頭:Harbor.orders(OrderLogic)在 _physics_process _tick_orders(教學做完才倒數):new -> post_order(order_menu = 櫃台賣的 {item: price})、expired -> 通知;
  OrderDock(DOCK_SPOT,村外西北)扣貨、送齊 order_completed(現金進錢包 GameState.complete_order、附贈、通知、存檔)。搬運工:porter_dests 多碼頭的每種貨一筆(kind counter、
  id = dock instance id × 4 + 序號);Helper.go_to 向 route 要中途點:_west_zone(x)0 村裡 / 1 院子 / 2 雪原 不同才給 WEST_ROUTE(出去正著走、回來倒著走)。
  以後加新的村外地點就在 route 補區段。稀有魚:FishArea.rare(spawn_rare 強制生、has_rare / rare_progress)、static rare_auto 測試關掉。
- 修理工 / 免費修:Harbor.is_wrecked / nearest_wrecked / repair_spot / repair_free(n, by) -> 修復牌 PricePad.complete_free()(pay(remaining) + _complete(null))-> purchased -> _on_purchased repair / tower;
  修理工被吃走 helper_eaten 同一套(hire_pad_for("repairman"))。
- 旅行商人 / 地圖:牌在 PAD_SPOTS(x 77.5 / 80.5 / 83.5, z -1),_on_purchased "map_piece" -> _sync_map_pads(兩塊牌 sync_buys(GameState.map_pieces))、"resource" 飛行幽靈;
  讀檔 restore_world 最後也 _sync_map_pads。地圖頁資料 map_data():world EXPLORE_RECT、rects(村 / 院子 / 擴建區 / 南塊 / 水區)、points(碼頭 / 商人)、player、pieces、unknown(x > 90、z > 50)。
- 新版內容:_maybe_show_changelog 在 _ready 最後(沒離線面板時)判斷;改了功能就在 data/changelog.json 最前面加一版(version 字串不同就會彈)。
- 引導:GameState.tutorial_step 0 ~ 7,Guide 每 0.1 秒 refresh,`GuideLogic.tutorial_step_done` 允許跳步(舊存檔有購買紀錄視為完成);教學後 `hint()` 優先序:村外(state.outside)先指回村 > 熊 > 手上有貨先處理(櫃台放不下整疊且沒人收銀先去收銀格)> 錢格 + 錢包買得起牌而錢包自己不夠(先收錢)> 幫手被吃過且武器打不過(state.outmatched)先存錢升級武器 > 工作站塞住拿成品 > 買得起的牌 > 櫃台有貨沒人收銀 > 錢格有錢 > 工作站有成品(沒搬運工才提醒)> 去抓魚。目標 kind / target 由 Guide._resolve 換成座標;新目標種類要同時加 GuideLogic 與 _resolve。

## 網頁 / 手機(PWA)

- 渲染器是 Compatibility(網頁匯出只支援這個);基準視窗 540 × 960、stretch canvas_items + expand,桌機視窗覆寫 450 × 800。
  字型:Godot 內建字型沒有中文、網頁拿不到系統字型,所以 `gui/theme/custom_font` 與 VisualFactory.label 都用 assets/fonts 的 Noto Sans TC。
- 觸控:`input_devices/pointing/emulate_touch_from_mouse` 開著,桌機滑鼠拖也會變觸控事件;搖桿只吃 `_unhandled_input`,GUI 按鈕先吃掉自己的事件,
  另外用 exclusions(選單鈕 / 面板的 rect)擋掉按在按鈕上的那根手指。Hud 的 is_touch_device() 決定提示文字。
- 匯出:`godot --headless --path . --export-release Web build/web/index.html`(模板在 `%APPDATA%\Godot\export_templates\4.7.stable\`,
  只解了 web_* 與 version.txt);產物 index.html / js / wasm(39.5 MB)/ pck / 圖示 / index.manifest.json / index.service.worker.js(快取版本 = 匯出時間,每次匯出自動換)。
  不開執行緒的模板不需要 COOP / COEP 標頭,GitHub Pages 才放得上。
- 部署:`python tools/deploy_web.py`(匯出 -> 複製到 `docs/` -> 只 commit docs/ -> push origin main);網址 https://tyboy0407.github.io/manlife-play/。
  2026-11-04 起原始碼與網頁成品同一個 GitHub repo `tyboy0407/manlife-play`(public):原始碼在根目錄、成品在 `docs/`(含 .nojekyll、.gdignore),
  Pages 設定從 main 的 /docs 發布(之前是成品 repo 從根目錄發布,舊的 build/pages clone 不再使用)。`build/` 要有 `.gdignore`,不然 Godot 會匯入成品 PNG。
  iPhone:Safari 開網址 -> 分享 -> 加入主畫面;存檔在瀏覽器儲存空間(IndexedDB)。
- 雲端(claude.ai/code 的 Linux 環境,已連 manlife-play):沒有 Godot,先 `bash tools/setup_cloud.sh`(下載 4.7 Linux 執行檔到 ~/godot/godot 並匯入專案;
  要匯出網頁版再加 `--templates` 下載匯出模板約 1 GB),測試用 `bash tools/run_tests.sh`(run_tests.ps1 的 bash 版,GODOT 環境變數可覆蓋),
  部署 `python tools/deploy_web.py` 同一支(push 需要雲端的 GitHub 權限涵蓋 manlife-play)。雲端做不到:截圖工具(要視窗)。
- 自動更新:Godot 的 service worker 本身不會 skipWaiting,新版裝好要全關再開兩次才生效。export_presets 的 `html/head_include`
  多了一段 JS:load 後抓 registration,`updatefound` -> 新 worker `installed`(且已有 controller)就 `postMessage('update')`
  (Godot SW 內建的訊息:skipWaiting + clients.claim + navigate),再聽 `controllerchange` 自己 reload 一次(Safari 沒有 WindowClient.navigate);
  開頁 30 秒內、或回到前景 10 秒內找到的新版立刻換,玩到一半找到的先記著,下次回前景(visibilitychange)再換;回前景 / 每 5 分鐘 `reg.update()` 查一次。
  Harbor 收到 NOTIFICATION_APPLICATION_FOCUS_OUT 也存檔,重新整理最多掉幾秒。head_include 是 cfg 單行字串,JS 裡不能有雙引號或反斜線。
- 本機預覽:`python tools/serve_web.py --port 8090`,內建瀏覽器用 mobile 視窗看;headless 測試的視窗是正方形(100 × 100 或 1280 × 1280),
  所以 is_portrait 用「高 >= 寬」,測試才走直式分支。
- 效能(2026-10-27,手機幀數偏低的對策):三大成本是即時陰影、3 倍像素密度、每件物品一個繪製呼叫。
  畫質由 Settings 決定,Harbor._apply_quality 套用:smooth = 關 DirectionalLight 陰影 + 顯示 blob_shadow 群組的腳下圓影 + `viewport.scaling_3d_scale` 0.75;
  fine = 即時陰影(專案設定 2048 貼圖、低軟陰影、光源兩層分割、最遠 45)+ 全解析度。選單可切、可顯示 FPS。
  像素密度在 export_presets 的 `html/head_include` 用一小段 JS 把 `window.devicePixelRatio` 蓋成最多 2(Godot 網頁版讀這個值決定畫布大小)。
  堆疊(StackVisual)整堆一個 MultiMesh;地形 / 牆 / 雪堆 / 魚欄合併成 Harbor.scenery(StaticBatch)。2026-11-04 補上:HUD 文字只在數字變了才重排、幽靈與 $ 物件池、網頁物理 30 Hz + 插值(桌機 / 測試仍 60)。

## 測試

```
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1
bash tools/run_tests.sh          # Linux / 雲端(先 bash tools/setup_cloud.sh)
```

GitHub Actions(`.github/workflows/tests.yml`)在推到 main 時(docs/、README、CLAUDE.md 的改動除外)或手動觸發,於 ubuntu-latest 跑同樣兩支腳本,約 7 分鐘;
2026-11-04 首次執行全過(Godot v4.7.stable.official,四套測試 ALL OK),這也證明 setup_cloud.sh / run_tests.sh 在 Linux 雲端能跑。

先 `godot --headless --path . --import`,再依檔名順序跑 `tests/verify_*.tscn`(verify_world 與 verify_world2 共用 tests/world_test_base.gd:WorldTestBase 有建關卡、合成輸入走路、
付牌、追熊、事件計數、存檔路徑與收尾;子類別覆寫 _tag() / _run();verify_world 跑完把存檔複製到 user://_verify_world_handoff.json,verify_world2 從它接手,所以 world2 要在 world 之後跑、單跑會 FAIL 提示):`verify_core`(見下)、`verify_layout`(擴建四次(含南塊)後蒐集所有占地矩形兩兩查重疊、排隊位不出自己那塊地的柵欄、傳送帶架高且不穿塔、顧客門、魚群上限按面積、廚房兩個輸入格、探險四面空氣牆與三個出口、村裡 / 村外判斷、
顧客成長(主村櫃台 10 位第二排 / 擴建區 8 位 / 5 ~ 9 件)、碼頭與商人營地在村外、碼頭路線中途點,約 5 秒)、`verify_nav`(擴建後東牆整面拆掉、幫手直線往返:x 12.6 沒有牆、搬運工送到擴建區櫃台再送回、
漁夫去擴建區的水再回主村卸貨、route 村裡回空、搬運工帶魚片繞西門 / 院子缺口到碼頭交訂單再倒著走回村,約 60 秒)、`verify_ui`(HUD 版面:選單鈕與面板貼右上角不出界、搖桿排除區、地圖頁(0 片 / 3 片回村鈕)、玩法說明六頁、新版內容、訂單一行)、`verify_core`(資料 / ItemStack / StationLogic / PurchaseLogic 含可重複牌 / CounterLogic / PorterPlanner 派工 / GuideLogic 教學與提示(含北極熊優先)/ BearLogic 冷卻與難度曲線、血量、成群機率、武器攻擊力、王的參數(不回血、咬建築 10 秒)、掉落物、武器店等級賣到第幾級、盯最近的 / TowerLogic 數值(血 800 = 20 口、強力塔 2000 = 50 口)、幾箭射死、射程內最近的活熊 / TrapLogic 數值、觸發、挑誘餌 / ConveyorLogic 拿貨 / 前進 / 排隊 / 存檔 / PurchaseLogic 買回、擴建名額、捕熊夾牌同價重現、守衛塔牌修復 / 工作站修復價 / 收毛皮的逐次價牌、武器牌 raise_max / roll_want / Settings 讀寫 / StackVisual MultiMesh 與 StaticBatch 合併 / ProgressRing / 音效檔載入與 Sfx 節流 / MoveInput / SaveManager IO / GameState 序列化)、`verify_world`(3D 整合第一段,約 3 分鐘,一路檢查教學箭頭指到哪:建關卡(直式相機、浮動搖桿推 / 放 / 排除區、選單兩次確認)-> 抓魚到滿 -> 卸貨 / 切 / 取 -> 上架 -> 沒人收銀不賣、站收銀格才賣 -> 錢格收進錢包、走過價格牌不付、站著分期(進度環)-> 僱收銀員接手(教學完成轉提示、H 開關) -> 垃圾桶丟魚 -> 僱搬運工送貨 -> 兩種升級牌 + 搬運工容量 Lv1(8 -> 12)-> 傳送帶 $150(切魚台 -> 魚片櫃台,自己送 3 件)-> 再僱漁夫 -> 增建烤魚攤 -> 搬運工送不出去放回來源、空的烤魚攤原料區優先補 -> 手動跑第二條鏈 $5 -> 北極熊(強制出現盯漁夫 -> 嚇呆 -> 咬 4 秒吃掉、僱用數 -1、牌子不退 -> 穿過西牆缺口到村外買武器 Lv1 ->
追著熊 Lv1 每下 10 打到血條歸零才逃、掉毛皮走過去撿 -> $15 買回漁夫 -> 買到 Lv3 -> 一群三隻各盯不同幫手、每隻兩下打跑、冷卻照當時的間隔、再掉三張毛皮 ->
5 張毛皮升級武器店 Lv1、武器牌重新出現買 Lv4 $172)->
守衛塔(沿西牆走到西北角買 tower_1 $200 -> 熊放在入口:塔射箭、熊被射中改來拆塔、30 血三箭射死玩家沒出手 -> 塔剩 10 血被厚血熊咬塌:廢墟、
牌重現「修復」$200 -> 修好血回滿)-> 捕熊夾 $40(熊踩到扣 60 定住 3 秒、牌同價重現)+ 誘餌 $30(熊被引走吃 10 秒、牌重現)-> 稀有魚(強制生金魚:漁夫不理、站旁邊進度 / 走開歸零、站滿 2 秒抓到資源 +1)
-> 村外探險(從院子西缺口出去:算村外、提示指回村、走到 x -40 被空氣牆擋、走回來提示恢復)-> 訂單(倒數到了自動貼、換成只要 6 片魚片的訂單、提示指碼頭、背著魚片繞到碼頭交貨:錢包 +$24 + 附贈、逾時消失)
-> 旅行商人(玩家傳到營地:現金買第一片兩塊牌同步、稀有魚買第二片、地圖頁 2 片沒回村鈕、第三片拼齊牌消失、毛皮補給 +5、地圖頁回村鈕傳回出生點、玩法說明 / 新版內容面板)-> items_moved / 幽靈 / 音效計數、畫質切換(陰影 / 圓影 / 3D 縮放)、FPS 開關、布景合併 -> 寫交接存檔)、`verify_world2`(第二段,約 3 分鐘:從交接存檔接手 -> 擴建村莊(錢包直接 +1000、7 秒付清 -> 東牆整面拆、第二水區有魚、第二組建築、新櫃台有顧客、僱用牌 5 / 6 / 4 次 -> $2000 第二次:切魚台 + 三座烤魚攤、名額 7 / 10 / 6 ->
$8000 第三次:兩座烤魚攤 + 服飾店 + 毛衣櫃台、名額 9 / 14 / 8、帶毛皮走過服飾店輸入格不放、站著放 10 張 -> 做 2 件毛衣 -> 上架賣 $200 -> $20000 第四次往南:南牆拆、廚房兩個輸入格、魚湯櫃台、塔 25 / 26 牌、名額 11 / 18、顧客成長(主村 10 位 / 擴建區 8 位 / 至少 5 件、第 7 位排第二排)、只有魚片不做、加烤魚 5 秒一碗、玩家送去賣 $15)
-> 修理工(院子付 $300 僱、站崗位、切魚台 2 設成廢墟 -> 走過去站 15 秒免費修好牌消失、塔被拆也去修血回滿)-> 北極熊王(play_time 撥到出場前 40 秒:預告倒數、一般熊暫停 -> 王出場 Lv0 血 ×4 體型 1.6 ->
吃魚只變大不回血 -> 吃搬運工不回血更大、牌可買回 -> 盯著切魚台咬 10 秒拆掉:廢墟、工人不見、格子停用、不再是搬運工 / 漁夫的目的地、
修復牌 $200 出現(快照記 broken)-> 站上廢墟修好 -> 打死:寶箱當場開(保底 3 顆牙、三選一、暫停;表現 normal ×1.0、王 Lv1、戰利品牆一顆頭骨)-> 選現金卡進錢包、再按不重複 -> 王消失 300 秒後再來 -> 站到 tower_1 底下付 1 顆牙:強力守衛塔血 2000 每箭 25)-> 存檔 / 重建關卡還原(含訂單內容與進度、地圖 2 片兩塊牌同步、修理工、顧客成長、武器等級、買回的漁夫、三塊擴建區(十一座工作站含服飾店、七座櫃台)、熊的冷卻、遊戲時間、王的下次時間、守衛塔狀態與血量與強化、武器店等級、毛皮數、地上的掉落物、擴建後的僱用名額)-> 離線收益(存檔 savedAt 撥回 3 小時、速率 2 $/s -> 重建關卡面板彈出 $10800、暫停、領取進錢包、再按不重複)-> 券 / 祭壇(保險券被吃不扣名額 10 秒回來、平靜券 120 秒與快照、免費升級券站上牌直接付清、冰封夾扣 150)-> 新遊戲)。Godot 路徑預設是桌面上的 4.7 console exe,可用環境變數 `GODOT` 覆蓋。

- 新增腳本或資源後要先 `--import`,否則 class_name 找不到;第一次 import 會因為 .translation 還沒產生而印錯誤,第二次就正常。
- 測試指令一定加 timeout:測試場景若編譯失敗,headless 永遠不會結束。
- verify_world 用合成輸入走路:`_pay_pad(pad)` 先到錢格收夠錢再站到牌子上,買東西的錢用 `money_pad.add_cash` 補;測試自己把 `SaveManager.save_path` 指到暫存檔。
  北極熊在 `_spawn_level` 後一律 `bears.enabled = false`(headless 也是即時走,不關的話 45 秒後熊會自己來吃幫手),要測再 `spawn(prefer)`;
  買武器期間把熊 `set_physics_process(false)` 定住、再挪到缺口附近,不然它會先把收銀員吃掉讓後面的存檔檢查失敗。
  要改存檔 JSON 再重建關卡:先 queue_free 舊關卡、等 3 幀完全釋放再改檔(它活著時任何事件都會再存一次把 savedAt 蓋掉);
  從捕熊夾 trap_1 走回村裡要沿西牆 (-11.9, 0.5) 繞,直線會擦過搬運工容量牌 (-10, -1.5) 的角付到錢。
  world2 從交接存檔重生的幫手都在出生點,王的段落先把漁夫傳到擴建區水裡 (22.3, -7),不然王會順手吃掉牠讓存檔檢查少一個幫手。
  收銀員可能已被派到新櫃台,上架就賣掉:記 _sales.size() 要在上架前;離線秒數會含測試跑掉的幾秒,收益用區間比。
  顧客一次買好幾件後錢格的錢常常收不完,記錢包數字前先等 `money_pad.cash == 0`;Guide 每 0.1 秒才重算,查提示前 `_step(8)`。
  血量跟著 play_time 連續變,比對 hp_max 用 1.0 的容差;逃走的熊到邊緣就 free,群體檢查要把 freed 也算逃走;王在水邊會邊吃魚邊回血,
  守衛塔段落:走到西北角要沿西牆(x -11.6)繞,直線會穿過切魚台的格子順手拿貨;$200 以每秒 30 付要站 7 秒,測試先 logic.pay(80);
  王的段落先把 tower_1 state 設回 none、結束再 restore 成 alive(王現在不限距離盯塔與工作站,存檔檢查要看塔還在);吃魚的檢查直接把
  king.target 設成最近的魚(免得牠先跑去拆切魚台)。測試先把漁夫調去擴建區的水、讓王吃搬運工(存檔檢查不看搬運工)。
  拆建築的段落用 station_1(測試沒買 station_2);修復時把王 set_physics_process(false) 挪遠,修完再開。

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
- 原始模型套件一定要放 `.gdignore`:Kenney 一包 100 多個 GLB / FBX / OBJ + 預覽圖,Godot 會全部匯入,`all_resources` 也全部匯出到網頁版;
  只把要用的檔案複製到 assets/models/game/。Kenney GLB 的貼圖是相對路徑 `Textures/colormap.png`,複製時連 Textures 資料夾一起(兩個套件的 colormap 不同,分開放)。
- glTF / FBX 匯入的動畫預設不循環(loop_mode 0),執行期對 Animation 資源設 LOOP_LINEAR 即可(同一 PackedScene 的實例共用資源,設一次全部生效)。
  Quaternius 舊版 FBX 的 Armature 帶 rotation -90° / scale 100,網格 AABB 要沿父節點累乘(ModelLibrary.scene_aabb)才是真實尺寸。
- 模型朝向不用猜:看骨架 rest 位置(魚的 Face / Tail 骨頭)或動畫資料(pick-up 的 torso 往哪邊彎,scratchpad 的 glb_anim.py 作法:解析 GLB 的 JSON + BIN);
  內建瀏覽器窗格的分頁只有 1 FPS,拖搖桿測不出朝向。
- 節點上別用 `create_timer().timeout.connect(lambda 捕捉子節點)` 延後隱藏:關卡換場景時子節點先被 free,timer 觸發會印「Lambda capture was freed」;改在 _physics_process 倒數。
- Git Bash 的 `grep -c $'\r'` 在這台機器會把 LF 檔也算成有 CR(誤判);看行尾用 `git ls-files --eol`。專案檔案都是 LF。
- `godot --script xxx.gd`(SceneTree 腳本)模式沒有 Autoload,用到 GameState / SaveManager 的工具要做成場景(.tscn)用 `--path . res://...tscn` 跑;
  `--` 之後的參數要用 `OS.get_cmdline_user_args()`(`get_cmdline_args` 不含它們)。截圖要有視窗(headless 畫不出來),會短暫跳出來。
- StaticBatch 每種顏色一個 surface,verify_world 限制 <= 10:新布景盡量沿用既有顏色(沙、柵欄、木頭)。
- 本機 8080 是台股 App 的伺服器,網頁預覽用 8090;瀏覽器窗格的 launch.json 指向舊的 star-weaver 路徑,改用 `preview_start {url}` 配 Bash 背景伺服器。

## 里程碑

1. 垂直切片(完成 2026-10-25):搖桿移動 + 背上堆疊、淺水區抓魚、切魚台(輸入格 / 工人 / 輸出格)、櫃台 + 排隊顧客 + 錢格、三塊價格牌(分期付款)、漁夫幫手 AI、HUD、資料驅動 JSON、兩套 headless 測試。
2. 存檔與自動化(完成 2026-10-26):存檔(SaveManager + snapshot,自動存 / F9 重來)、第二條貨物鏈(烤魚攤 魚片 -> 烤魚,烤魚櫃台 $5,建地牌 $60)、搬運工 / 收銀員幫手(櫃台改成要有人收銀)、升級牌(工人速度 / 堆疊上限,各三級漲價)、可重複僱用牌(漁夫 ×3 / 搬運工 ×2 / 收銀員 ×2)、垃圾桶。同日追加:現金改錢包(不佔背包、價格牌站 0.6 秒才付);搬運工改成最缺貨的櫃台優先(PorterPlanner)、卸不掉放回來源。
3. 手感與引導(完成 2026-10-26):飛行動畫(物品拋物線、賣出飛向顧客、$ 飛向錢包、付款飛向牌子)、合成占位音效 + 環境音、價格牌付款進度環 + 工作站處理進度環、七步教學鏈 + 之後的提示箭頭(頭上小箭頭 + 目標大箭頭,H 開關)、顧客買到道謝泡泡。
4. iPhone PWA(完成 2026-10-26):Compatibility 渲染器、直式相機、浮動觸控搖桿、右上角選單、Noto Sans TC 字型、占位圖示 / 啟動畫面、Web 匯出預設(PWA)、本機預覽與一鍵部署腳本,上線 https://tyboy0407.github.io/manlife-play/。

5. 模型(完成 2026-10-27):Kenney Mini Characters 人物(玩家 / 漁夫 / 搬運工 / 收銀員 / 工人各一種、顧客 7 種輪流)+ idle / walk / interact / emote 動畫、
   Survival Kit 的魚當貨物模型(堆疊與飛行幽靈共用)、Quaternius 動畫魚在水裡游;ModelLibrary / CharacterModel 資料驅動,沒模型退回占位。
   候選清單在 notes/model_candidates.md(魚片 / 烤魚模型可用 Quaternius Modular Sushi Restaurant Kit)。

6. 北極熊與武器店(完成 2026-10-27;同日追加:被吃幫手 1.5 倍買回、熊成群且更頻繁、$1000 擴建村莊(東邊 annex:第二水區 / 工作站 / 櫃台)、
   顧客要 1 ~ 5 件;再追加:幫手繞東門不卡牆(verify_nav)、熊有血條要打到歸零、武器只加攻擊力、血量與出沒頻率隨遊戲時間變難、
   5 分鐘出北極熊王(吃魚吃幫手、回血變大、打死 300 秒後再來)):BearLogic / Bear / BearSpawner(有幫手才來、第一隻 45 秒、之後 60 ~ 90 秒;盯最近的幫手、嚇呆、咬 4 秒吃掉,
   被吃永久消失且僱用牌不退、熊留著找下一個直到被趕跑或沒人可吃)、西牆缺口 + 村外武器店(老闆 + 三級武器牌 $35 ×1.7:趕跑 / 冷卻 ×1.7 / 看到就逃)、
   玩家腰間武器模型、提示箭頭優先指武器牌或熊、roar / chomp 音效、HUD 武器等級與被吃數、存檔含武器等級與熊冷卻、tools/snap_scene 截圖工具。
   再追加(2026-10-27):擴建後僱用牌多開放名額(搬運工 +4、收銀員 +2、漁夫 +2)、四角守衛塔 $200(射箭打熊、被熊拆了 $200 修復,TowerLogic / Tower)、
   網頁版偵測到新版自動重新整理(head_include JS + 失焦存檔)。
   再追加(2026-10-27):守衛塔血 800(扛 20 口)、北極熊王不回血、改拆建築(切魚台 / 烤魚攤 / 守衛塔咬 10 秒就垮,廢墟上 $200 修復牌)。
   再追加(2026-10-28):熊最快 30 ~ 40 秒一群;打跑的熊掉毛皮 -> 武器店升級三級(5 / 10 / 20 張)多賣武器 Lv4 ~ 6;打死王掉熊王牙 -> 強力守衛塔(血 2000、每箭 25)。

之後候選:北極熊模型(Quaternius Animals / Kenney Animal Pack 的熊)、魚片 / 烤魚 / 建築模型(壽司店套件)、離線收益、幫手升級、顧客多樣化與耐心、
關卡座標資料化與地圖擴張、更多貨物鏈(魚湯)、字型子集化縮小下載。
