class_name Harbor
extends Node3D
## 星港漁市原型關卡:雪地 + 沙灘 + 淺水區(抓魚)+ 魚欄裝飾、工作站、櫃台與排隊顧客、錢格、垃圾桶、價格牌(shop.json),
## 玩家、跟隨相機、HUD。全部用程式碼擺放(座標在這裡,規則與數值在 data/)。
## 世界座標:x 右、-z 螢幕上(水在上面)、+z 螢幕下(顧客從右邊來)。價格牌一排在 z = 5、間距 4(牌寬 2),中間留 2 格寬的走道,
## 帶著現金穿過走道才不會順手付進別的牌。
## 解鎖:unlock 效果的 target 查 UNLOCKS 生工作站 / 櫃台;僱用生 Helper。存檔:GameState + snapshot(),自動存、關閉存、F9 重來。
## 村外(西邊出口 z 1.2 ~ 3.8 的缺口外)是武器店的小院子:店屋 + 老闆 + 武器牌(shop.json weapon,三級漲價);
## 北極熊(BearSpawner)從地圖邊緣進來吃幫手,玩家要帶武器靠近才趕得走;被吃的幫手由 helper_eaten 結算(僱用牌退名額、買回 1.5 倍)。
## 擴建村莊(shop.json expand_village $1000,unlock village_2):把東牆整段拆掉(east_walls:三段隱形牆 + 柵欄,主村與 annex 連成一片,幫手不用繞門),往東蓋 annex:沙地、第二個水區、
## 第二座切魚台 + 烤魚攤、第二組櫃台(顧客跟著變多);僱用牌多開放名額(shop.json expandBuys:漁夫 +2、搬運工 +4、收銀員 +2)。
## 第二次擴建(expand_village_2 $2000,unlock village_3):再往東一塊(ANNEX_RECTS[1]):拆第一塊擴建區的東牆、第三個水區、切魚台 + 三座烤魚攤、第三組櫃台、
## 僱用牌再多開一次名額;牌子放在第一塊擴建區裡(擴建一次後才出現)。第三次擴建(expand_village_3 $8000,unlock village_4,牌在第二塊擴建區):
## 第四個水區、兩座烤魚攤 + 服飾店(tailor:玩家把毛皮放進去,5 張做一件毛衣)+ 毛衣櫃台($200)。
## 每塊擴建區也照主村放六座守衛塔(tower_7 ~ 12、13 ~ 18、19 ~ 24),牌子跟著那塊地開放。
## 守衛塔(Tower):村莊四角各一座(tower_1 ~ 4)+ 村中央水邊兩座(tower_5 / 6,在切魚台輸入格之間,補四角射程 9 照不到的中間),
## 牌子($200)就是地基;蓋好會朝靠近的熊射箭,被熊拆掉後站回地基花 $200 修。
## 北極熊王會拆工作站(切魚台 / 烤魚攤):_add_station 時順便生一塊藏著的修復牌(repair_<spot_id>,shop.json repairStation $200)在桌子位置,
## 被拆(station_destroyed)才出現,付清 _on_purchased "repair" 修好。
## 掉落物(Loot):熊被打跑掉毛皮、王被打死掉熊王牙(_on_bear_defeated -> drop_loot),玩家走過去撿(GameState.pelts / teeth)。
## 武器店升級牌(shop_upgrade,收毛皮 5 / 10 / 20)在院子裡:每級讓武器牌多賣一級(_apply_shop_level -> raise_max,武器 Lv4 ~ 6);
## 捕熊夾(Trap,TRAP_SPOTS:每塊地北邊水區兩側各一個,靠熊的入口)與誘餌(Bait,BAIT_SPOTS:每塊地西側水邊一個)的牌子就是放置位置,
## 用掉後 trap_used / bait_eaten 讓牌子同價重新出現;傳送帶(Conveyor,CONVEYORS:工作站輸出格 -> 同種貨櫃台上架格)的牌在工作站旁,
## 兩端都蓋好才出現(_refresh_tower_pads 一起管),買了 build_conveyor;搬運工容量升級牌 upgrade_porter_cap 在西側走道。
## 熊王牙牌(tooth_tower_n,收 1 顆)就在塔下,塔完好且還沒強化才出現(_refresh_tower_pads),付清 tower.upgrade() 變強力守衛塔。
## 訂單(OrderLogic):村外西北的碼頭(DOCK_SPOT 交貨格 OrderDock + 貨船布景)定時貼限時訂單,玩家 / 搬運工把貨送到交貨格,
## 送齊 order_completed 給現金(進錢包)+ 附贈;搬運工送訂單走 porter_dests(碼頭當作一個「櫃台」目的地)+ route 的西門中途點。
## 修理工(Helper role repairman,牌 hire_repairman 在武器店院子):平常站 REPAIRMAN_POST,有建築被拆(nearest_wrecked)就走過去站 15 秒 repair_free
## (走修復牌的 complete_free,不扣錢)。顧客成長:每擴建一次所有櫃台 apply_expansion(擴建次數)。
## 旅行商人(MERCHANT_CAMP,村外東邊雪原):帳篷 + 營火 + 商人,牌 map_cash / map_fish(地圖碎片,現金或稀有魚擇一,買了另一塊跟著跳下一片)、
## merchant_pelts(毛皮補給);地圖碎片記 GameState.map_pieces,選單的地圖頁(Hud.show_map,map_data())拼齊三片可一鍵回村(action map_home)。

const STATION_SPOTS := {"station_1": Vector3(-6.0, 0, 0), "station_2": Vector3(0.0, 0, 0), "grill": Vector3(6.0, 0, 0),
    "station_3": Vector3(18.0, 0, 0), "grill_2": Vector3(25.0, 0, 0),
    "station_4": Vector3(33.4, 0, 0), "grill_3": Vector3(38.4, 0, 0), "grill_4": Vector3(43.4, 0, 0), "grill_5": Vector3(48.4, 0, 0),   # 第二塊:切魚台 + 三座烤魚攤
    "grill_6": Vector3(53.5, 0, 0), "grill_7": Vector3(59.5, 0, 0), "tailor": Vector3(64.5, 0, 0),   # 第三塊:兩座烤魚攤 + 服飾店
    "kitchen": Vector3(0.0, 0, 18.5)}   # 南塊:魚湯廚房(兩個輸入格:魚片 / 烤魚)
const STATION_DEFS := {"station_1": "cutting_table", "station_2": "cutting_table", "grill": "grill", "station_3": "cutting_table", "grill_2": "grill",
    "station_4": "cutting_table", "grill_3": "grill", "grill_4": "grill", "grill_5": "grill", "grill_6": "grill", "grill_7": "grill", "tailor": "tailor", "kitchen": "kitchen"}
const COUNTER_SPOTS := {"fillet_counter": Vector3(-9.0, 0, 8.5), "grill_counter": Vector3(3.0, 0, 8.5), "soup_counter": Vector3(-3.0, 0, 26.5),
    "fillet_counter_2": Vector3(16.6, 0, 8.5), "grill_counter_2": Vector3(25.4, 0, 8.5),   # 擴建區 18.6 寬放兩座櫃台:上架格貼西邊、排 4 個顧客(counters.json maxCustomers)
    "fillet_counter_3": Vector3(35.2, 0, 8.5), "grill_counter_3": Vector3(44.0, 0, 8.5),   # 排隊位才不會排進隔壁的上架格或穿過東柵欄
    "sweater_counter": Vector3(59.5, 0, 8.5)}
const PAD_SPOTS := {
    "hire_fisher": Vector3(-10.0, 0, 5.0), "hire_porter": Vector3(-6.0, 0, 5.0), "hire_cashier": Vector3(-2.0, 0, 5.0),
    "capacity_1": Vector3(2.0, 0, 5.0), "upgrade_worker_speed": Vector3(6.0, 0, 5.0), "upgrade_pile_cap": Vector3(10.0, 0, 5.0),
    "expand_table": Vector3(0.0, 0, 0), "unlock_grill": Vector3(6.0, 0, 0),
    "weapon": Vector3(-19.5, 0, 4.0), "expand_village": Vector3(10.0, 0, 0.0), "expand_village_2": Vector3(29.5, 0, 0.5),
    "upgrade_porter_cap": Vector3(-10.0, 0, -1.5),   # 西側走道、切魚台旁(價格牌排已經排滿)
    "expand_village_3": Vector3(36.4, 0, 5.0), "expand_village_4": Vector3(-6.5, 0, 11.0),   # 第四次(往南)的牌在主村南牆邊,擴建三次後才出現   # 第二塊擴建區裡 z 5 的走道,35.4 ~ 37.4 是唯一沒有傳送帶經過的空隙
    "tower_1": Vector3(-11.0, 0, -9.5), "tower_2": Vector3(11.0, 0, -9.5), "tower_3": Vector3(-11.0, 0, 11.0), "tower_4": Vector3(11.0, 0, 11.0),
    "tower_5": Vector3(-3.0, 0, -2.9), "tower_6": Vector3(3.0, 0, -2.9),
    "shop_upgrade": Vector3(-15.5, 0, 4.6),
    "altar_insurance": Vector3(-21.9, 0, 4.6), "altar_ice": Vector3(-15.5, 0, 1.5),   # 熊王祭壇(收熊王牙):武器店院子裡
    "hire_repairman": Vector3(-15.5, 0, -1.5),   # 修理工的僱用牌:武器店院子東北角
    "hire_guard": Vector3(-8.0, 0, 20.0),   # 衛兵的僱用牌:南塊(第四次擴建後才出現),魚湯廚房西邊
    "map_cash": Vector3(77.5, 0, -1.0), "map_fish": Vector3(80.5, 0, -1.0), "merchant_pelts": Vector3(83.5, 0, -1.0),   # 旅行商人營地(村外東邊雪原)
    "shrine": Vector3(86.0, 0, -9.0),   # 冰母的神龕(雪原東北角,三片地圖拼齊才出現;收 3 條稀有魚 = 結局)
    "tooth_tower_1": Vector3(-11.0, 0, -9.5), "tooth_tower_2": Vector3(11.0, 0, -9.5), "tooth_tower_3": Vector3(-11.0, 0, 11.0), "tooth_tower_4": Vector3(11.0, 0, 11.0),
    "tooth_tower_5": Vector3(-3.0, 0, -2.9), "tooth_tower_6": Vector3(3.0, 0, -2.9),
}
# 守衛塔(= 牌子的位置,牌是地基):四角 + 村中央水邊兩座(x ±3 是切魚台輸入格之間的空地,z -2.9 貼著淺水區南緣,屋頂只遮到水面);
# 每塊擴建區照同樣布置六座(tower_7 ~ 12 第一塊、13 ~ 18 第二塊、19 ~ 24 第三塊:西側兩座在沙地內 2.0 / 1.4 格、東側兩座離東柵欄 2.3 格(塔基與捕熊夾離柵欄 1 格、離水 0.5 格),中央兩座在工作站輸入格之間的水邊)
const TOWER_SPOTS := {"tower_1": Vector3(-11.0, 0, -9.5), "tower_2": Vector3(11.0, 0, -9.5),
    "tower_3": Vector3(-11.0, 0, 11.0), "tower_4": Vector3(11.0, 0, 11.0),
    "tower_5": Vector3(-3.0, 0, -2.9), "tower_6": Vector3(3.0, 0, -2.9),
    "tower_7": Vector3(15.0, 0, -9.5), "tower_8": Vector3(29.3, 0, -9.5), "tower_9": Vector3(14.4, 0, 11.0), "tower_10": Vector3(29.3, 0, 11.0),   # 西南塔在魚片櫃台的上架格南邊,避開收銀格
    "tower_11": Vector3(21.5, 0, -2.9), "tower_12": Vector3(28.3, 0, -2.9),
    "tower_13": Vector3(33.6, 0, -9.5), "tower_14": Vector3(47.9, 0, -9.5), "tower_15": Vector3(33.0, 0, 11.0), "tower_16": Vector3(47.9, 0, 11.0),
    "tower_17": Vector3(40.9, 0, -2.9), "tower_18": Vector3(45.9, 0, -2.9),
    "tower_19": Vector3(52.2, 0, -9.5), "tower_20": Vector3(66.5, 0, -9.5), "tower_21": Vector3(52.2, 0, 11.0), "tower_22": Vector3(66.5, 0, 11.0),
    "tower_23": Vector3(56.5, 0, -2.9), "tower_24": Vector3(62.5, 0, -2.9),
    "tower_25": Vector3(-11.0, 0, 16.5), "tower_26": Vector3(11.0, 0, 16.5)}   # 南塊兩座(西北 / 東北角)
const TOWERS_PER_AREA := 6   # tower_1 ~ 6 主村、7 ~ 12 第一塊擴建區、13 ~ 18 第二塊、19 ~ 24 第三塊
# 捕熊夾:每塊地兩個(水區兩側的雪地上、角塔內側,熊從入口進來往村裡走會經過;觸發半徑 trap.radius),trap_1 / 2 主村、3 / 4 第一塊 …
const TRAP_SPOTS := {"trap_1": Vector3(-11.2, 0, -6.8), "trap_2": Vector3(11.2, 0, -6.8),
    "trap_3": Vector3(14.6, 0, -6.8), "trap_4": Vector3(29.3, 0, -6.8),
    "trap_5": Vector3(33.2, 0, -6.8), "trap_6": Vector3(47.9, 0, -6.8),
    "trap_7": Vector3(51.8, 0, -6.8), "trap_8": Vector3(66.5, 0, -6.8)}
const TRAPS_PER_AREA := 2
# 誘餌魚堆:每塊地一個(西側水邊的沙地上),bait_1 主村、2 ~ 4 三塊擴建區
const BAIT_SPOTS := {"bait_1": Vector3(-10.3, 0, -4.3), "bait_2": Vector3(14.7, 0, -4.3), "bait_3": Vector3(33.3, 0, -4.3), "bait_4": Vector3(51.9, 0, -4.3)}
# 傳送帶:工作站輸出格 -> 同種貨的櫃台上架格;pad = 牌子位置(主村 / 第一塊在輸出格東側,第二 / 三塊在 z 5 的走道上)
const CONVEYORS := {
    "belt_station_1": {"from": "station_1", "to": "fillet_counter", "pad": Vector3(-3.8, 0, 2.2)},
    "belt_station_2": {"from": "station_2", "to": "fillet_counter", "pad": Vector3(2.2, 0, 2.2)},
    "belt_grill": {"from": "grill", "to": "grill_counter", "pad": Vector3(8.2, 0, 2.2)},
    "belt_station_3": {"from": "station_3", "to": "fillet_counter_2", "pad": Vector3(20.2, 0, 2.2)},
    "belt_grill_2": {"from": "grill_2", "to": "grill_counter_2", "pad": Vector3(27.2, 0, 2.2)},
    "belt_station_4": {"from": "station_4", "to": "fillet_counter_3", "pad": Vector3(33.4, 0, 5.0)},
    "belt_grill_3": {"from": "grill_3", "to": "grill_counter_3", "pad": Vector3(38.4, 0, 5.0)},
    "belt_grill_4": {"from": "grill_4", "to": "grill_counter_3", "pad": Vector3(43.4, 0, 5.0)},
    "belt_grill_5": {"from": "grill_5", "to": "grill_counter_3", "pad": Vector3(48.4, 0, 5.0)},
    "belt_grill_6": {"from": "grill_6", "to": "grill_counter_3", "pad": Vector3(53.5, 0, 5.0)},
    "belt_grill_7": {"from": "grill_7", "to": "grill_counter_3", "pad": Vector3(59.5, 0, 5.0)},
    "belt_tailor": {"from": "tailor", "to": "sweater_counter", "pad": Vector3(64.5, 0, 5.0)},
    "belt_kitchen": {"from": "kitchen", "to": "soup_counter", "pad": Vector3(4.0, 0, 22.5)},
}
const UNLOCKS := {
    "station_2": {"stations": ["station_2"], "counters": []},
    "grill_complex": {"stations": ["grill"], "counters": ["grill_counter"]},
    "village_2": {"stations": ["station_3", "grill_2"], "counters": ["fillet_counter_2", "grill_counter_2"], "annex": 1, "expandShop": true},
    "village_3": {"stations": ["station_4", "grill_3", "grill_4", "grill_5"], "counters": ["fillet_counter_3", "grill_counter_3"], "annex": 2, "expandShop": true},
    "village_4": {"stations": ["grill_6", "grill_7", "tailor"], "counters": ["sweater_counter"], "annex": 3, "expandShop": true},
    "village_5": {"stations": ["kitchen"], "counters": ["soup_counter"], "annex": 4, "expandShop": true},   # 第四次:往南(SOUTH_RECT)
}
const EAST_GATE_Z := Vector2(-4.0, 4.0)     # 東牆中段的門(柵欄缺口的外觀;擴建時整面東牆都拆)
const ANNEX_RECT := Rect2(13.0, -11.0, 18.6, 23.6)   # 第一塊擴建區(x 13 ~ 31.6)
const ANNEX_RECTS := [Rect2(13.0, -11.0, 18.6, 23.6), Rect2(31.6, -11.0, 18.6, 23.6), Rect2(50.2, -11.0, 18.6, 23.6)]   # 三塊擴建區(x 13 ~ 31.6 ~ 50.2 ~ 68.8)
const ANNEX_WATER_W := 11.0   # 擴建區水區寬度(主村 16;擴建區窄,兩側各留 3.8 格沙地給角塔 / 捕熊夾 / 誘餌,東側塔離柵欄 2.3 格)
# 第四次擴建:主村南邊一塊(SOUTH_RECT,x -12.6 ~ 12.6、z 12.6 ~ 30.6):魚湯廚房(魚片 + 烤魚 -> 魚湯)+ 魚湯櫃台 + 兩座塔;拆主村南牆
const SOUTH_RECT := Rect2(-12.6, 12.6, 25.2, 18.0)
const SOUTH_DOOR_Z := Vector2(27.5, 29.5)      # 南塊東柵欄上的顧客門
# 村外雪原(探險):空氣牆圍住 EXPLORE_RECT,村的西(武器店院子)/ 東(最東那面牆)/ 南(南牆)各一個缺口;北邊是海,沒有出口
const EXPLORE_RECT := Rect2(-40.0, -12.0, 130.0, 62.0)
const EXIT_WEST_Z := Vector2(0.8, 3.2)         # 武器店院子西柵欄的缺口(z 範圍)
const EXIT_EAST_Z := Vector2(-1.0, 2.0)        # 最東那面牆的缺口(z 範圍)
const EXIT_SOUTH_X := Vector2(-1.0, 1.0)       # 南牆的缺口(x 範圍)
const LANDMARKS := [["rock", Vector3(-34, 0, -3)], ["rock", Vector3(-33, 0, 20)], ["tree", Vector3(-28, 0, 40)], ["rock", Vector3(30, 0, 38)],
    ["tree", Vector3(60, 0, 42)], ["rock", Vector3(80, 0, 20)], ["tree", Vector3(86, 0, 10)], ["pile", Vector3(20, 0, 45)], ["pile", Vector3(-20, 0, 32)],
    ["tree", Vector3(75, 0, 35)], ["rock", Vector3(-36, 0, 2)], ["pile", Vector3(45, 0, 40)], ["tree", Vector3(-25, 0, 14)], ["rock", Vector3(5, 0, 40)]]
const ALTAR_SIGN := Vector3(-18.7, 0, 3.0)
# 碼頭(訂單):村外西北,貨船停在探險範圍北緣的海邊;交貨格 DOCK_SPOT 在棧橋上
const DOCK_SPOT := Vector3(-30.0, 0, -7.4)
const BOAT_SPOT := Vector3(-30.0, 0, -11.2)
# 搬運工送訂單要穿過西門與武器店院子的西缺口:村裡 -> 碼頭的中途點(反向就倒過來走)
const WEST_ROUTE := [Vector3(-9.0, 0, 3.6), Vector3(-11.4, 0, 2.5), Vector3(-14.2, 0, 2.5), Vector3(-22.2, 0, 2.0), Vector3(-25.0, 0, 2.0)]
# 旅行商人營地:村外東邊雪原(最東那塊擴建區 x 68.8 之外、空氣牆 90 之內)
const MERCHANT_CAMP := Vector3(80.0, 0, -6.0)
const MERCHANT_SPOT := Vector3(80.0, 0, -3.8)
const SHRINE_SPOT := Vector3(86.0, 0, -9.0)   # 故事終章:冰母的神龕(雪原東北角,「不下雪的地方」),牌 shrine 同位置
const REPAIRMAN_POST := Vector3(-10.5, 0, 2.4)   # 修理工沒事時站的崗位(西門內側走道)
const CUSTOMER_DOOR_Z := Vector2(9.2, 11.2)   # 每塊地東柵欄上的「顧客門」(只開視覺柵欄,隱形牆留著);顧客從門外走進來、買完走回門外
const CUSTOMER_DOOR_OUT := 1.5                # 顧客出生 / 離開點在柵欄外幾格
const MONEY_SPOT := Vector3(-4.0, 0, 10.7)
const TRASH_SPOT := Vector3(9.0, 0, 10.7)
const HELPER_SPAWN := Vector3(0.0, 0, -3.0)
const PLAYER_SPAWN := Vector3(0.0, 0, 7.0)
const GATE_Z := Vector2(1.2, 3.8)             # 西牆缺口(z 範圍),通往村外
const WEAPON_SHOP := Vector3(-19.5, 0, -1.4)  # 武器店店屋中心
const SHOPKEEPER_SPOT := Vector3(-19.5, 0, 0.6)

var player: Player
var fish_area: FishArea                 # 第一個水區(fish_areas[0])
var fish_areas: Array[FishArea] = []
var annex: StaticBatch = null           # 第一塊擴建區的布景(蓋了才有)
var annexes: Array[StaticBatch] = []    # 每塊擴建區的布景(依序)
var annex_east_walls: Array = []        # 每塊擴建區的東牆 [隱形牆, 柵欄](下一塊擴建時拆)
var east_gate: StaticBody3D = null      # 東門那段隱形牆(擴建時拆)
var east_gate_mesh: MeshInstance3D = null
var east_walls: Array[Node3D] = []      # 整面東牆:三段隱形牆 + 柵欄(擴建時全部拆掉)
var stations: Array[Station] = []
var counters: Array[Counter] = []
var money_pad: MoneyPad
var trash_pad: TrashPad
var price_pads := {}
var towers: Array[Tower] = []
var loot: Array[Loot] = []              # 地上的毛皮 / 熊王牙
var traps: Array[Trap] = []             # 捕熊夾(位置固定,買了才放好)
var baits: Array[Bait] = []             # 誘餌魚堆(位置固定,買了才放好)
var conveyors: Array[Conveyor] = []     # 蓋好的傳送帶
var shop_sign: Label3D = null           # 武器店招牌(升級後顯示等級)
var helpers: Array[Helper] = []
var bears: BearSpawner
var shopkeeper: Node3D = null
var camera: FollowCamera
var hud: Hud
var guide: Guide
var light: DirectionalLight3D
var scenery: StaticBatch   # 不會動的布景合併成一個網格
var world: Node3D
var autosave_sec := 10.0
var loaded_from_save := false
var offline: OfflineLogic               # 離線收益:在線記收入速率、讀檔時算離線收益
var king_logic: KingLogic               # 北極熊王獎勵循環
var south_walls: Array[Node3D] = []     # 主村南牆(隱形牆 + 柵欄),往南擴建時拆
var south_block: StaticBatch = null     # 南塊布景(蓋了才有)
var exit_east_walls: Array[Node3D] = [] # 目前最東那面牆上「探險缺口」兩側的牆段(換更東的牆時重做)
var trophies: Node3D = null             # 武器店屋頂的戰利品牆(每殺一次王一顆頭骨)
var king_eaten := 0                     # 這次王在村裡吃了幾個幫手(表現分)
var king_wrecked := 0                   # 這次王拆了幾棟建築
var pending_chest := {}                 # 打開的寶箱內容(三選一面板開著)
var _insured: Array = []                # 保險券:[{role, at}] 到時間重新生幫手
var orders: OrderLogic                  # 訂單(碼頭的貨船)
var dock: OrderDock = null              # 碼頭的交貨格
var dock_sign: Label3D = null           # 貨船上的訂單牌
var merchant: Node3D = null             # 旅行商人(人物)
var captain: Node3D = null              # 貨船的船長(人物,故事泡泡用)
var shrine: Node3D = null               # 冰母的神龕(外觀;地圖拼齊才顯示)
var story: Story = null
var tower_upgrading: Tower = null       # 升級面板目前對著哪座塔
var _order_text_shown := ""
var offline_sec := 0                    # 這次讀檔算出的離線秒數
var _offline_pending := 0               # 還沒領的離線收益(面板開著)

var _autosave_timer := 0.0
var _spawned_unlocks := {}


func _ready() -> void:
    world = Node3D.new()
    world.name = "World"
    add_child(world)
    _build_environment()
    scenery = StaticBatch.new()
    scenery.name = "Scenery"
    world.add_child(scenery)
    _build_terrain()
    _build_outside()
    _build_dock()
    _build_merchant_camp()
    _build_shrine()
    fish_area = FishArea.new()
    fish_area.name = "FishArea"
    fish_area.rect = Rect2(-8.0, -11.0, 16.0, 7.0)
    world.add_child(fish_area)
    fish_areas.append(fish_area)
    _build_pen_decoration()
    scenery.build()
    _apply_quality()
    Settings.changed.connect(_apply_quality)
    _add_station("station_1")
    money_pad = MoneyPad.new()
    money_pad.name = "MoneyPad"
    money_pad.position = MONEY_SPOT
    world.add_child(money_pad)
    trash_pad = TrashPad.new()
    trash_pad.name = "TrashPad"
    trash_pad.position = TRASH_SPOT
    world.add_child(trash_pad)
    orders = OrderLogic.from_config(GameData.section("orders"))
    dock = OrderDock.new()
    dock.name = "OrderDock"
    dock.level = self
    dock.logic = orders
    dock.position = DOCK_SPOT
    world.add_child(dock)
    _add_counter("fillet_counter")
    for def in GameData.shop():
        var id := str(def["id"])
        var pad := PricePad.create(def)
        pad.position = _pad_spot(id)
        world.add_child(pad)
        price_pads[id] = pad
        if id.begins_with("tooth_") and pad.label != null:
            pad.label.position.y = 6.4   # 牌子在塔底下,字要浮在塔頂上
    _build_towers()
    _build_traps()
    player = Player.new()
    player.name = "Player"
    player.position = PLAYER_SPAWN
    add_child(player)
    bears = BearSpawner.new()
    bears.name = "Bears"
    bears.level = self
    add_child(bears)
    camera = FollowCamera.new()
    camera.name = "Camera"
    camera.target = player
    add_child(camera)
    hud = Hud.new()
    hud.name = "Hud"
    hud.bind_player(player)
    hud.action.connect(_on_hud_action)
    hud.map_source = map_data
    add_child(hud)
    autosave_sec = maxf(float(GameData.config().get("autosaveSec", 10.0)), 1.0)
    _autosave_timer = autosave_sec
    offline = OfflineLogic.from_config(GameData.section("offline"))
    king_logic = KingLogic.from_config(GameData.section("bear").get("king", {}))
    bears.king_logic = king_logic
    _load_save()
    _refresh_trophies()
    _apply_shop_level()
    _refresh_tower_pads()
    EventBus.bear_defeated.connect(_on_bear_defeated)
    EventBus.bear_appeared.connect(func(b: Node3D) -> void:
        if b is Bear and (b as Bear).is_king:
            king_eaten = 0
            king_wrecked = 0)
    EventBus.king_warning.connect(func(left: int) -> void: hud.set_warning(tr("HUD_KING_WARNING") % left if left >= 0 else ""))
    EventBus.sale_made.connect(func(_item: String, _count: int, cash: int) -> void: offline.record(GameState.play_time, cash))
    if _offline_pending > 0:
        _show_offline()
    else:
        _maybe_show_changelog()
    guide = Guide.new()
    guide.name = "Guide"
    guide.level = self
    add_child(guide)
    story = Story.new()
    story.name = "Story"
    story.level = self
    story.silent_first = loaded_from_save   # 讀檔:舊進度的章節 / 日誌直接補進去,不一次彈一堆
    add_child(story)
    EventBus.purchased.connect(_on_purchased)
    EventBus.purchased.connect(func(_id: String, _effect: Dictionary) -> void: save_now())


## --- 場景 ---

func _build_environment() -> void:
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color(0.62, 0.74, 0.9)
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.75, 0.8, 0.9)
    e.ambient_light_energy = 0.9
    env.environment = e
    add_child(env)
    light = DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-52, -28, 0)
    light.light_energy = 1.1
    light.shadow_enabled = true
    light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS   # 場景小,兩層就夠,省一半陰影繪製
    light.directional_shadow_max_distance = 45.0
    add_child(light)


## 畫質(Settings):流暢 = 關即時陰影、顯示腳下圓影、3D 用 0.75 倍解析度;精細 = 相反
func _apply_quality() -> void:
    var smooth := Settings.is_smooth()
    if light != null:
        light.shadow_enabled = not smooth
    get_viewport().scaling_3d_scale = Settings.scaling_3d()
    get_tree().call_group("blob_shadow", "set_visible", smooth)


func _build_terrain() -> void:
    scenery.add_box(Vector3(160, 0.2, 110), Color(0.93, 0.95, 0.98), Vector3(25, -0.12, 14))   # 雪地蓋滿整個探險範圍(EXPLORE_RECT)
    _build_exploration()
    scenery.add_box(Vector3(25, 0.06, 16.5), Color(0.88, 0.76, 0.6), Vector3(0, -0.02, 4.0))
    # 西牆留缺口(GATE_Z)通往村外的武器店
    _wall(Vector3(-12.6, 1, (-13.0 + GATE_Z.x) / 2.0), Vector3(0.4, 2, GATE_Z.x + 13.0))
    _wall(Vector3(-12.6, 1, (GATE_Z.y + 13.0) / 2.0), Vector3(0.4, 2, 13.0 - GATE_Z.y))
    # 整面東牆(擴建村莊時全部拆掉,主村與 annex 連成一片)
    east_walls.append(_wall(Vector3(12.6, 1, (-13.0 + EAST_GATE_Z.x) / 2.0), Vector3(0.4, 2, EAST_GATE_Z.x + 13.0)))
    east_walls.append(_wall(Vector3(12.6, 1, (EAST_GATE_Z.y + 13.0) / 2.0), Vector3(0.4, 2, 13.0 - EAST_GATE_Z.y)))
    east_gate = null   # 東門那段改由 _set_east_exit 管(留探險缺口),擴建時一起拆
    for seg in _gap_segments(-13.0, 13.0, EXIT_SOUTH_X):   # 主村南牆留探險缺口,往南擴建時整面拆
        south_walls.append(_wall(Vector3((seg.x + seg.y) / 2.0, 1, 12.6), Vector3(seg.y - seg.x, 2, 0.4)))
    _wall(Vector3(0, 1, -11.2), Vector3(26, 2, 0.4))
    var fence := Color(0.8, 0.62, 0.42)
    east_gate_mesh = null
    for seg in _fence_segments(EAST_GATE_Z.y, 12.25):   # 顧客門那段留空
        var east_fence := VisualFactory.box(Vector3(0.25, 0.9, seg.y - seg.x), fence, Vector3(12.4, 0.45, (seg.x + seg.y) / 2.0))
        world.add_child(east_fence)
        east_walls.append(east_fence)
    _add_doormat(scenery, 12.6)
    scenery.add_box(Vector3(0.25, 0.9, GATE_Z.x + 4.25), fence, Vector3(-12.4, 0.45, (GATE_Z.x - 4.25) / 2.0))
    scenery.add_box(Vector3(0.25, 0.9, 12.25 - GATE_Z.y), fence, Vector3(-12.4, 0.45, (GATE_Z.y + 12.25) / 2.0))
    for seg in _gap_segments(-12.5, 12.5, EXIT_SOUTH_X):
        var sf := VisualFactory.box(Vector3(seg.y - seg.x, 0.9, 0.25), fence, Vector3((seg.x + seg.y) / 2.0, 0.45, 12.4))
        world.add_child(sf)
        south_walls.append(sf)
    _set_east_exit(12.6)
    for p in [Vector3(-25, 0, 8), Vector3(-15, 0, 9), Vector3(16, 0, -2), Vector3(15.5, 0, 9), Vector3(-17, 0, -6), Vector3(17, 0, -9)]:
        scenery.add_cylinder(0.2, 1.0, Color(0.45, 0.3, 0.2), p + Vector3(0, 0.5, 0))
        scenery.add_box(Vector3(1.6, 1.6, 1.6), Color(0.86, 0.92, 0.96), p + Vector3(0, 1.6, 0))
        scenery.add_box(Vector3(1.0, 1.2, 1.0), Color(0.86, 0.92, 0.96), p + Vector3(0, 2.8, 0))


## 村外的武器店院子:沙地、矮柵欄與隱形牆、店屋 + 招牌、櫃台、老闆(人物模型,面向 +Z)
func _build_outside() -> void:
    var sand := Color(0.88, 0.76, 0.6)
    scenery.add_box(Vector3(10.4, 0.05, 9.4), sand, Vector3(-18.0, -0.02, 2.0))
    scenery.add_box(Vector3(1.2, 0.05, GATE_Z.y - GATE_Z.x), sand, Vector3(-12.6, -0.02, (GATE_Z.x + GATE_Z.y) / 2.0))
    var fence := Color(0.8, 0.62, 0.42)
    for seg in _gap_segments(-2.7, 6.7, EXIT_WEST_Z):   # 院子西柵欄留探險缺口
        scenery.add_box(Vector3(0.25, 0.9, seg.y - seg.x), fence, Vector3(-23.2, 0.45, (seg.x + seg.y) / 2.0))
    scenery.add_box(Vector3(10.6, 0.9, 0.25), fence, Vector3(-18.0, 0.45, -2.7))
    scenery.add_box(Vector3(10.6, 0.9, 0.25), fence, Vector3(-18.0, 0.45, 6.7))
    for seg in _gap_segments(-3.0, 7.0, EXIT_WEST_Z):
        _wall(Vector3(-23.4, 1, (seg.x + seg.y) / 2.0), Vector3(0.4, 2, seg.y - seg.x))
    _wall(Vector3(-18.0, 1, -2.9), Vector3(11.2, 2, 0.4))
    _wall(Vector3(-18.0, 1, 6.9), Vector3(11.2, 2, 0.4))
    # 顏色盡量沿用既有布景(StaticBatch 每種顏色一個 surface)
    scenery.add_box(Vector3(4.2, 2.4, 2.6), Color(0.45, 0.3, 0.2), WEAPON_SHOP + Vector3(0, 1.2, 0))
    scenery.add_box(Vector3(4.8, 0.3, 3.2), Color(0.55, 0.18, 0.15), WEAPON_SHOP + Vector3(0, 2.55, 0))
    scenery.add_box(Vector3(3.2, 0.9, 0.6), fence, Vector3(WEAPON_SHOP.x, 0.45, 1.5))
    scenery.add_box(Vector3(3.4, 0.08, 0.8), sand, Vector3(WEAPON_SHOP.x, 0.94, 1.5))
    shop_sign = VisualFactory.label(tr("SIGN_WEAPON_SHOP"), WEAPON_SHOP + Vector3(0, 3.3, 0), 48, Color(1.0, 0.9, 0.7))
    world.add_child(shop_sign)
    # 熊王祭壇:石台 + 招牌,牌子(altar_insurance / altar_ice)在旁邊
    scenery.add_box(Vector3(1.4, 0.5, 1.0), Color(0.6, 0.6, 0.65), ALTAR_SIGN + Vector3(0, 0.25, 0))
    world.add_child(VisualFactory.label(tr("SIGN_ALTAR"), ALTAR_SIGN + Vector3(0, 1.4, 0), 40, Color(1.0, 0.95, 0.8)))
    trophies = Node3D.new()
    trophies.name = "Trophies"
    world.add_child(trophies)
    shopkeeper = Node3D.new()
    shopkeeper.name = "Shopkeeper"
    shopkeeper.position = SHOPKEEPER_SPOT
    world.add_child(shopkeeper)
    var scene := ModelLibrary.character(ModelLibrary.shopkeeper_model())
    if scene != null:
        shopkeeper.add_child(CharacterModel.create(scene, ModelLibrary.character_height()))
    else:
        shopkeeper.add_child(VisualFactory.capsule(0.4, 1.6, Color(0.5, 0.25, 0.2), Vector3(0, 0.9, 0)))
    shopkeeper.add_child(VisualFactory.blob_shadow(0.5, Settings.is_smooth()))


## 碼頭:棧橋 + 貨船(船身 / 船頭 / 桅杆 / 帆 / 旗)停在海邊(探險範圍北緣外的一片海),訂單牌掛在船上
func _build_dock() -> void:
    var wood := Color(0.45, 0.3, 0.2)
    var plank := Color(0.82, 0.62, 0.4)
    var sail := Color(0.86, 0.92, 0.96)
    scenery.add_box(Vector3(16.0, 0.12, 6.0), Color(0.2, 0.45, 0.85), Vector3(BOAT_SPOT.x, -0.04, -14.6))   # 海
    scenery.add_box(Vector3(6.0, 0.12, 3.2), plank, Vector3(DOCK_SPOT.x, 0.0, DOCK_SPOT.z - 1.2))        # 棧橋
    for x in [DOCK_SPOT.x - 2.6, DOCK_SPOT.x + 2.6]:
        scenery.add_cylinder(0.14, 1.0, wood, Vector3(x, 0.5, DOCK_SPOT.z - 2.6))
    scenery.add_box(Vector3(5.2, 1.0, 2.4), wood, BOAT_SPOT + Vector3(0, 0.5, 0))                         # 船身
    scenery.add_box(Vector3(5.6, 0.2, 2.8), plank, BOAT_SPOT + Vector3(0, 1.05, 0))                        # 甲板
    scenery.add_box(Vector3(1.0, 1.2, 1.4), wood, BOAT_SPOT + Vector3(-3.0, 0.6, 0))                      # 船頭
    scenery.add_cylinder(0.12, 3.6, wood, BOAT_SPOT + Vector3(0.4, 2.9, 0))                               # 桅杆
    scenery.add_box(Vector3(2.0, 1.8, 0.1), sail, BOAT_SPOT + Vector3(0.4, 2.8, 0.2))                     # 帆
    scenery.add_box(Vector3(0.6, 0.3, 0.06), Color(0.55, 0.18, 0.15), BOAT_SPOT + Vector3(0.7, 4.5, 0))   # 旗
    dock_sign = VisualFactory.label(tr("SIGN_DOCK"), BOAT_SPOT + Vector3(0, 5.2, 0), 44, Color(1.0, 0.95, 0.8))
    world.add_child(dock_sign)
    # 船長(破冰者):站在甲板上,只有外觀,故事的泡泡掛在他頭上
    captain = Node3D.new()
    captain.name = "Captain"
    captain.position = BOAT_SPOT + Vector3(-1.0, 1.15, 1.0)
    world.add_child(captain)
    var cmodels := ModelLibrary.customer_models()
    var cscene: PackedScene = ModelLibrary.character(str(cmodels[cmodels.size() - 1])) if not cmodels.is_empty() else null
    if cscene != null:
        captain.add_child(CharacterModel.create(cscene, ModelLibrary.character_height()))
    else:
        captain.add_child(VisualFactory.capsule(0.4, 1.6, Color(0.3, 0.35, 0.5), Vector3(0, 0.9, 0)))


## 旅行商人營地:帳篷 + 營火 + 商人(人物模型)+ 招牌;牌子(map_cash / map_fish / merchant_pelts)在帳篷前
func _build_merchant_camp() -> void:
    var wood := Color(0.45, 0.3, 0.2)
    var cloth := Color(0.55, 0.18, 0.15)
    var stone := Color(0.6, 0.6, 0.65)
    var c := MERCHANT_CAMP
    scenery.add_box(Vector3(3.4, 2.0, 3.0), cloth, c + Vector3(0, 1.0, 0))          # 帳篷
    scenery.add_box(Vector3(3.8, 0.3, 3.4), wood, c + Vector3(0, 2.15, 0))          # 帳篷頂
    scenery.add_cylinder(0.14, 2.9, wood, c + Vector3(0, 1.45, 1.6))                # 門柱
    scenery.add_cylinder(0.8, 0.2, stone, c + Vector3(3.5, 0.1, 1.5))               # 營火石圈
    scenery.add_box(Vector3(0.5, 0.5, 0.5), Color(0.9, 0.6, 0.3), c + Vector3(3.5, 0.45, 1.5))   # 火
    scenery.add_box(Vector3(0.9, 0.2, 0.2), wood, c + Vector3(3.5, 0.25, 1.5))
    scenery.add_box(Vector3(1.4, 0.8, 0.8), wood, c + Vector3(-3.0, 0.4, 1.2))     # 貨箱
    world.add_child(VisualFactory.label(tr("SIGN_MERCHANT"), c + Vector3(0, 3.2, 0), 44, Color(1.0, 0.95, 0.8)))
    merchant = Node3D.new()
    merchant.name = "Merchant"
    merchant.position = MERCHANT_SPOT
    world.add_child(merchant)
    var scene := ModelLibrary.character(ModelLibrary.shopkeeper_model())
    if scene != null:
        merchant.add_child(CharacterModel.create(scene, ModelLibrary.character_height()))
    else:
        merchant.add_child(VisualFactory.capsule(0.4, 1.6, Color(0.5, 0.25, 0.2), Vector3(0, 0.9, 0)))
    merchant.add_child(VisualFactory.blob_shadow(0.5, Settings.is_smooth()))


## 冰母的神龕(故事終章):冰台 + 一圈冰柱圍著一灘黑水;三片地圖拼齊才顯示(_refresh_shrine),牌 shrine 收 3 條稀有魚
func _build_shrine() -> void:
    shrine = Node3D.new()
    shrine.name = "Shrine"
    shrine.position = SHRINE_SPOT
    world.add_child(shrine)
    var ice := Color(0.8, 0.9, 1.0)
    var dark := Color(0.04, 0.07, 0.12)
    shrine.add_child(VisualFactory.cylinder(2.2, 0.12, ice.darkened(0.25), Vector3(0, 0.06, 0)))
    shrine.add_child(VisualFactory.cylinder(1.3, 0.08, dark, Vector3(0, 0.14, 0)))
    for i in 6:
        var a := TAU * float(i) / 6.0
        var h := 1.6 + float(i % 2) * 0.9
        shrine.add_child(VisualFactory.box(Vector3(0.35, h, 0.35), ice, Vector3(cos(a) * 2.6, h / 2.0, sin(a) * 2.6)))
    shrine.add_child(VisualFactory.label(tr("SIGN_SHRINE"), Vector3(0, 3.6, 0), 44, Color(0.85, 0.9, 1.0)))
    shrine.visible = false


## 神龕與它的牌只在三片地圖拼齊後出現;付清(結局)後牌消失、神龕留著
func _refresh_shrine() -> void:
    var full := GameState.has_full_map()
    if shrine != null:
        shrine.visible = full
    var sp: PricePad = price_pads.get("shrine", null)
    if sp != null:
        sp.set_open(full and not GameState.is_unlocked("shrine"))


## 擴建區(annex):第 k 塊(1 起)。拆掉它西邊那面牆(k = 1 是主村的整面東牆 east_walls,k >= 2 是前一塊的東牆),
## 往東蓋沙地、柵欄、隱形牆、新的水區與深水池;東牆(隱形牆 + 柵欄)另外記著,下一塊擴建時拆。建築由 _spawn_unlock 依 UNLOCKS 生。
func _build_annex(k: int = 1) -> void:
    if k == ANNEX_RECTS.size() + 1:
        _build_south_block()
        return
    if k < 1 or k > ANNEX_RECTS.size() or annexes.size() >= k:
        return
    if k == 1:
        for w in east_walls:
            if w != null and is_instance_valid(w):
                w.queue_free()
        east_walls.clear()
        east_gate = null
        east_gate_mesh = null
    else:
        for w in annex_east_walls[k - 2]:
            if w != null and is_instance_valid(w):
                w.queue_free()
        annex_east_walls[k - 2] = []
    var rect: Rect2 = ANNEX_RECTS[k - 1]
    var batch := StaticBatch.new()
    batch.name = "Annex%d" % k
    world.add_child(batch)
    var fence := Color(0.8, 0.62, 0.42)
    var cx := rect.get_center().x
    batch.add_box(Vector3(rect.size.x + 0.8, 0.06, 16.5), Color(0.88, 0.76, 0.6), Vector3(cx - 0.4, -0.02, 4.0))   # 沙地接到西邊那塊,中間沒縫
    batch.add_box(Vector3(rect.size.x, 0.9, 0.25), fence, Vector3(cx, 0.45, 12.4))
    batch.add_box(Vector3(ANNEX_WATER_W, 0.12, 5), Color(0.2, 0.45, 0.85), Vector3(cx, -0.04, -14.0))
    for i in int(ANNEX_WATER_W) + 1:
        var x := cx - ANNEX_WATER_W / 2.0 + float(i)
        if absf(x - cx) <= 1.5:
            continue
        batch.add_cylinder(0.14, 1.1, fence, Vector3(x, 0.55, -11.5))
    batch.add_box(Vector3(ANNEX_WATER_W, 0.3, 0.3), fence, Vector3(cx, 0.95, -11.5))
    _add_doormat(batch, rect.end.x)
    batch.build()
    while annex_east_walls.size() < k:
        annex_east_walls.append([])
    annex_east_walls[k - 1] = []
    for seg in _gap_segments(-13.0, 13.0, EXIT_EAST_Z):   # 東牆留探險缺口(下一塊擴建時整面拆)
        annex_east_walls[k - 1].append(_wall(Vector3(rect.end.x, 1, (seg.x + seg.y) / 2.0), Vector3(0.4, 2, seg.y - seg.x)))
    for seg in _fence_segments(-4.25, 12.25, true):   # 顧客門與探險缺口那兩段留空
        var east_fence := VisualFactory.box(Vector3(0.25, 0.9, seg.y - seg.x), fence, Vector3(rect.end.x - 0.2, 0.45, (seg.x + seg.y) / 2.0))
        world.add_child(east_fence)
        annex_east_walls[k - 1].append(east_fence)
    for w in exit_east_walls:
        if is_instance_valid(w):
            w.queue_free()
    exit_east_walls.clear()
    _wall(Vector3(cx, 1, 12.6), Vector3(rect.size.x + 0.4, 2, 0.4))
    _wall(Vector3(cx, 1, -11.2), Vector3(rect.size.x + 0.4, 2, 0.4))
    var fa := FishArea.new()
    fa.name = "FishArea%d" % (k + 1)
    fa.rect = Rect2(cx - ANNEX_WATER_W / 2.0, -11.0, ANNEX_WATER_W, 7.0)   # 擴建區只有 18.6 寬,水區比主村窄,四角塔 / 捕熊夾 / 誘餌才在沙地上
    world.add_child(fa)
    fish_areas.append(fa)
    annexes.append(batch)
    if k == 1:
        annex = batch
    _apply_quality()
    _refresh_tower_pads()
    _apply_customer_growth()


## 擴建了幾次(0 = 只有主村)
func expansion_level() -> int:
    return annexes.size()


## 牌子的位置:PAD_SPOTS 沒有就看塔 / 熊王牙牌(塔的位置)、捕熊夾、誘餌、傳送帶
func _pad_spot(id: String) -> Vector3:
    if PAD_SPOTS.has(id):
        return PAD_SPOTS[id]
    if TOWER_SPOTS.has(id.trim_prefix("tooth_")):
        return TOWER_SPOTS[id.trim_prefix("tooth_")]
    if TRAP_SPOTS.has(id):
        return TRAP_SPOTS[id]
    if BAIT_SPOTS.has(id):
        return BAIT_SPOTS[id]
    if CONVEYORS.has(id):
        return CONVEYORS[id]["pad"]
    return Vector3(0, 0, 12)


## 捕熊夾 / 誘餌屬於哪塊地:trap_1 / 2、bait_1 主村,之後每塊地兩個夾子、一個誘餌
static func trap_area(trap_id: String) -> int:
    return maxi((int(trap_id.trim_prefix("trap_")) - 1) / TRAPS_PER_AREA, 0)


static func bait_area(bait_id: String) -> int:
    return maxi(int(bait_id.trim_prefix("bait_")) - 1, 0)


## 這座塔屬於哪塊地:0 主村、1 第一塊擴建區、2 第二塊、3 第三塊
static func tower_area(tower_id: String) -> int:
    var n := int(tower_id.trim_prefix("tower_"))
    return maxi((n - 1) / TOWERS_PER_AREA, 0)


func is_expanded() -> bool:
    return annex != null


## 幫手從 from 走到 to 要經過的中途點(不含終點)。村裡(含擴建區)之間沒有牆,直線走;
## 要去村外西邊的碼頭(x < -23.4,搬運工送訂單)就先繞西門、穿過武器店院子的西缺口(WEST_ROUTE),回來倒著走。
func route(from: Vector3, to: Vector3) -> Array[Vector3]:
    var out: Array[Vector3] = []
    var from_zone := _west_zone(from)
    var to_zone := _west_zone(to)
    if from_zone == to_zone:
        return out
    var lo := mini(from_zone, to_zone)
    var hi := maxi(from_zone, to_zone)
    var order := range(WEST_ROUTE.size()) if to_zone > from_zone else range(WEST_ROUTE.size() - 1, -1, -1)
    for i in order:
        var p: Vector3 = WEST_ROUTE[i]
        var z := _west_zone(p)
        if z >= lo and z <= hi:
            out.append(p)
    return out


## 西邊三段:0 村裡(x >= -12.6)、1 武器店院子(-23.4 ~ -12.6)、2 村外雪原(x < -23.4)
static func _west_zone(p: Vector3) -> int:
    if p.x < -23.4:
        return 2
    if p.x < -12.6:
        return 1
    return 0


## 卡住時往哪邊滑(沒有門了,就回原點,Helper 改往目的地的 z 方向滑)
func gate_point(pos: Vector3) -> Vector3:
    return pos


## 離 pos 最近的水區(站在某個水區裡就是它)
func nearest_fish_area(pos: Vector3) -> FishArea:
    var best: FishArea = null
    var best_d := INF
    for fa in fish_areas:
        if fa.contains(pos):
            return fa
        var r := fa.rect
        var d := Vector2(clampf(pos.x, r.position.x, r.end.x) - pos.x, clampf(pos.z, r.position.y, r.end.y) - pos.z).length()
        if d < best_d:
            best_d = d
            best = fa
    return best


## 漁夫該去哪個水區:漁夫最少的那個,一樣多就最近的
func pick_fish_area(h: Helper) -> FishArea:
    if fish_areas.is_empty():
        return null
    var counts := {}
    for other in helpers:
        if other != h and other.role == "fisher" and other.fish_area != null:
            counts[other.fish_area] = int(counts.get(other.fish_area, 0)) + 1
    var best: FishArea = null
    var best_n := 1 << 30
    var best_d := INF
    for fa in fish_areas:
        var n := int(counts.get(fa, 0))
        var r := fa.rect
        var d := Vector2(r.get_center().x - h.global_position.x, r.get_center().y - h.global_position.z).length()
        if n < best_n or (n == best_n and d < best_d):
            best = fa
            best_n = n
            best_d = d
    return best


## 東柵欄分段:挖掉 CUSTOMER_DOOR_Z 的顧客門;with_exit 再挖掉 EXIT_EAST_Z 的探險缺口
static func _fence_segments(z0: float, z1: float, with_exit: bool = false, door: Vector2 = CUSTOMER_DOOR_Z) -> Array[Vector2]:
    var gaps: Array[Vector2] = [door]
    if with_exit:
        gaps.append(EXIT_EAST_Z)
    var out: Array[Vector2] = []
    for seg in _gap_segments(z0, z1, gaps[0]):
        if with_exit:
            out.append_array(_gap_segments(seg.x, seg.y, EXIT_EAST_Z))
        else:
            out.append(seg)
    return out


## 一段 [a, b] 挖掉 gap 之後剩下的段落
static func _gap_segments(a: float, b: float, gap: Vector2) -> Array[Vector2]:
    var out: Array[Vector2] = []
    if gap.x > a:
        out.append(Vector2(a, minf(gap.x, b)))
    if b > gap.y:
        out.append(Vector2(maxf(gap.y, a), b))
    return out


## 最東那面牆上的探險缺口:x 是那面牆的位置(主村 12.6;擴建後由 _build_annex 自己留缺口)。主村的東門段 EAST_GATE_Z 改成「缺口兩側各一小段牆」
func _set_east_exit(x: float) -> void:
    for w in exit_east_walls:
        if is_instance_valid(w):
            w.queue_free()
    exit_east_walls.clear()
    var fence := Color(0.8, 0.62, 0.42)
    for seg in _gap_segments(EAST_GATE_Z.x, EAST_GATE_Z.y, EXIT_EAST_Z):
        var w := _wall(Vector3(x, 1, (seg.x + seg.y) / 2.0), Vector3(0.4, 2, seg.y - seg.x))
        var m := VisualFactory.box(Vector3(0.25, 0.9, seg.y - seg.x), fence, Vector3(x - 0.2, 0.45, (seg.x + seg.y) / 2.0))
        world.add_child(m)
        exit_east_walls.append(w)
        exit_east_walls.append(m)
        east_walls.append(w)
        east_walls.append(m)
    east_gate = exit_east_walls[0] if not exit_east_walls.is_empty() else null


## 第四次擴建:主村南邊的南塊。拆主村南牆(含柵欄),蓋沙地、東 / 西 / 南的隱形牆與柵欄(東柵欄留顧客門、南牆留探險缺口)
func _build_south_block() -> void:
    if south_block != null:
        return
    for w in south_walls:
        if w != null and is_instance_valid(w):
            w.queue_free()
    south_walls.clear()
    var rect := SOUTH_RECT
    var batch := StaticBatch.new()
    batch.name = "SouthBlock"
    world.add_child(batch)
    var fence := Color(0.8, 0.62, 0.42)
    batch.add_box(Vector3(rect.size.x, 0.06, rect.size.y + 0.8), Color(0.88, 0.76, 0.6), Vector3(rect.get_center().x, -0.02, rect.get_center().y - 0.4))
    # 西柵欄整面、南柵欄留探險缺口、東柵欄留顧客門
    batch.add_box(Vector3(0.25, 0.9, rect.size.y), fence, Vector3(rect.position.x + 0.2, 0.45, rect.get_center().y))
    for seg in _gap_segments(rect.position.x, rect.end.x, EXIT_SOUTH_X):
        batch.add_box(Vector3(seg.y - seg.x, 0.9, 0.25), fence, Vector3((seg.x + seg.y) / 2.0, 0.45, rect.end.y - 0.2))
    for seg in _gap_segments(rect.position.y, rect.end.y, SOUTH_DOOR_Z):
        batch.add_box(Vector3(0.25, 0.9, seg.y - seg.x), fence, Vector3(rect.end.x - 0.2, 0.45, (seg.x + seg.y) / 2.0))
    _add_doormat(batch, rect.end.x, SOUTH_DOOR_Z)
    batch.build()
    _wall(Vector3(rect.position.x, 1, rect.get_center().y), Vector3(0.4, 2, rect.size.y))
    _wall(Vector3(rect.end.x, 1, rect.get_center().y), Vector3(0.4, 2, rect.size.y))
    for seg in _gap_segments(rect.position.x - 0.4, rect.end.x + 0.4, EXIT_SOUTH_X):
        _wall(Vector3((seg.x + seg.y) / 2.0, 1, rect.end.y), Vector3(seg.y - seg.x, 2, 0.4))
    south_block = batch
    annexes.append(batch)   # 算第四次擴建(expansion_level 4:tower_25 / 26 的牌、熊的南入口)
    _apply_quality()
    _refresh_tower_pads()
    _apply_customer_growth()


## 顧客成長:每座櫃台套上目前的擴建次數(顧客更多、來得更快、每人要得更多)
func _apply_customer_growth() -> void:
    for c in counters:
        c.apply_expansion(expansion_level())


func has_south_block() -> bool:
    return south_block != null


## 村外雪原:空氣牆圍住 EXPLORE_RECT(北邊貼著海),散幾個地標(岩石 / 枯樹 / 雪堆)當方向參考
func _build_exploration() -> void:
    var r := EXPLORE_RECT
    _wall(Vector3(r.position.x, 1, r.get_center().y), Vector3(0.4, 2, r.size.y + 0.4))
    _wall(Vector3(r.end.x, 1, r.get_center().y), Vector3(0.4, 2, r.size.y + 0.4))
    _wall(Vector3(r.get_center().x, 1, r.position.y), Vector3(r.size.x + 0.4, 2, 0.4))
    _wall(Vector3(r.get_center().x, 1, r.end.y), Vector3(r.size.x + 0.4, 2, 0.4))
    var stone := Color(0.6, 0.6, 0.65)
    var wood := Color(0.45, 0.3, 0.2)
    var snow := Color(0.86, 0.92, 0.96)
    for lm in LANDMARKS:
        var kind := str(lm[0])
        var p: Vector3 = lm[1]
        match kind:
            "rock":
                scenery.add_box(Vector3(2.2, 1.3, 1.8), stone, p + Vector3(0, 0.65, 0))
                scenery.add_box(Vector3(1.2, 0.8, 1.0), stone, p + Vector3(1.3, 0.4, 0.6))
            "tree":
                scenery.add_cylinder(0.25, 3.2, wood, p + Vector3(0, 1.6, 0))
                scenery.add_box(Vector3(1.6, 0.18, 0.18), wood, p + Vector3(0.6, 2.4, 0))
                scenery.add_box(Vector3(0.18, 0.18, 1.3), wood, p + Vector3(-0.4, 2.0, 0.4))
            "pile":
                scenery.add_box(Vector3(2.4, 1.2, 2.4), snow, p + Vector3(0, 0.6, 0))
                scenery.add_box(Vector3(1.4, 0.9, 1.4), snow, p + Vector3(0, 1.5, 0))


## 玩家在村裡(主村 / 武器店院子 / 擴建區 / 南塊)還是村外的雪原
func is_inside_village(pos: Vector3) -> bool:
    var xz := Vector2(pos.x, pos.z)
    if Rect2(-12.6, -11.2, 25.2, 23.8).has_point(xz) or Rect2(-23.4, -2.9, 10.8, 9.8).has_point(xz):
        return true
    for k in mini(expansion_level(), ANNEX_RECTS.size()):
        if (ANNEX_RECTS[k] as Rect2).has_point(xz):
            return true
    if south_block != null and SOUTH_RECT.has_point(xz):
        return true
    return false


func player_outside() -> bool:
    return player != null and is_instance_valid(player) and not is_inside_village(player.global_position)


## 村外要回村:離玩家最近的那個入口(缺口外側一點)
func home_point(pos: Vector3) -> Vector3:
    var east_x := 12.6
    var n := mini(expansion_level(), ANNEX_RECTS.size())
    if n > 0:
        east_x = (ANNEX_RECTS[n - 1] as Rect2).end.x
    var south_z := SOUTH_RECT.end.y if south_block != null else 12.6
    var exits := [Vector3(-23.4 - 1.5, 0, (EXIT_WEST_Z.x + EXIT_WEST_Z.y) / 2.0), Vector3(east_x + 1.5, 0, (EXIT_EAST_Z.x + EXIT_EAST_Z.y) / 2.0),
            Vector3((EXIT_SOUTH_X.x + EXIT_SOUTH_X.y) / 2.0, 0, south_z + 1.5)]
    var best: Vector3 = exits[0]
    for e in exits:
        if (e as Vector3).distance_to(pos) < best.distance_to(pos):
            best = e
    return best


## 顧客門外的小塊沙地路口(柵欄拆了之後也留著,顧客照樣從這裡走進來)
func _add_doormat(batch: StaticBatch, fence_x: float, door: Vector2 = CUSTOMER_DOOR_Z) -> void:
    batch.add_box(Vector3(2.6, 0.05, door.y - door.x + 0.4), Color(0.88, 0.76, 0.6), Vector3(fence_x + 1.1, -0.02, (door.x + door.y) / 2.0))


## 這個 x 屬於哪塊地:0 主村、1 ~ 3 擴建區
static func area_of_x(x: float) -> int:
    var area := 0
    for k in ANNEX_RECTS.size():
        if x >= (ANNEX_RECTS[k] as Rect2).position.x:
            area = k + 1
    return area


## 這個位置的櫃台用哪扇顧客門:南塊(z > 12.6)用南塊東柵欄的門,其他照分區
static func customer_door_for(pos: Vector3) -> Vector3:
    if pos.z > 12.6:
        return Vector3(SOUTH_RECT.end.x + CUSTOMER_DOOR_OUT, 0.0, (SOUTH_DOOR_Z.x + SOUTH_DOOR_Z.y) / 2.0)
    return customer_door(area_of_x(pos.x))


## 第 area 塊地的顧客門外:顧客出生 / 離開點(世界座標)
static func customer_door(area: int) -> Vector3:
    var fence_x := 12.6 if area <= 0 else (ANNEX_RECTS[mini(area, ANNEX_RECTS.size()) - 1] as Rect2).end.x
    return Vector3(fence_x + CUSTOMER_DOOR_OUT, 0.0, (CUSTOMER_DOOR_Z.x + CUSTOMER_DOOR_Z.y) / 2.0)


## --- 訂單(碼頭的貨船)---

## 可以要哪些貨:有櫃台在賣的 {item: 售價}
func order_menu() -> Dictionary:
    var menu := {}
    for c in counters:
        menu[c.logic.item_id] = c.logic.price
    return menu


## 貼一張新訂單(沒櫃台就不貼);回傳訂單
func post_order() -> Dictionary:
    var o := orders.generate(order_menu(), expansion_level(), randf())
    if o.is_empty():
        return {}
    EventBus.order_posted.emit(o)
    EventBus.notice.emit(tr("NOTICE_ORDER_NEW") % [order_text(), int(o["time_left"])])
    _refresh_order_text()
    return o


## 訂單內容文字:「魚片 2/6、烤魚 0/6」
func order_text() -> String:
    if not orders.has_order():
        return ""
    var parts: Array[String] = []
    for item in orders.order["lines"]:
        var l: Dictionary = orders.order["lines"][item]
        parts.append(tr("HUD_ORDER_LINE") % [GameData.item_name(str(item)), int(l["done"]), int(l["need"])])
    return "、".join(parts)


## 送齊了(OrderDock 叫):現金進錢包 + 附贈(毛皮 / 券)、通知、存檔
func order_completed() -> void:
    var r := orders.complete()
    if r.is_empty():
        return
    var reward := int(r["reward"])
    GameState.complete_order(reward)
    var bonus: Dictionary = r.get("bonus", {})
    var bonus_text := ""
    match str(bonus.get("kind", "")):
        "pelt":
            GameState.add_resource("pelt", int(bonus.get("amount", 0)))
            bonus_text = tr("BONUS_pelt") % int(bonus.get("amount", 0))
        "coupon":
            var key := str(bonus.get("coupon", "insurance"))
            if key == "calm":
                bears.calm(king_logic.calm_sec())
            else:
                GameState.add_coupon(key, 1)
            bonus_text = tr("BONUS_coupon")
    EventBus.items_moved.emit("cash", "cash", dock.global_position + Vector3(0, 1.6, 0), player.global_position, 1)
    EventBus.order_completed.emit(r)
    EventBus.notice.emit(tr("NOTICE_ORDER_DONE") % [reward, bonus_text])
    _refresh_order_text()
    save_now()


## 每幀:教學做完後才開始倒數;到時間貼新訂單 / 逾時消失
func _tick_orders(delta: float) -> void:
    if orders == null or GameState.tutorial_step < GuideLogic.tutorial_steps():
        return
    match orders.tick(delta, expansion_level()):
        "new":
            post_order()
        "expired":
            EventBus.order_expired.emit()
            EventBus.notice.emit(tr("NOTICE_ORDER_EXPIRED"))
            _refresh_order_text()
    if orders.has_order():
        var t := tr("HUD_ORDER") % [order_text(), int(ceil(float(orders.order["time_left"]))), int(orders.order["reward"])]
        if t != _order_text_shown:
            _order_text_shown = t
            hud.set_order(t)
    elif _order_text_shown != "":
        _order_text_shown = ""
        hud.set_order("")


func _refresh_order_text() -> void:
    if dock_sign != null:
        dock_sign.text = tr("SIGN_DOCK") + ("\n" + order_text() if orders.has_order() else "")


## --- 修理工 ---

## 這個建築(工作站 / 守衛塔)現在是不是廢墟
func is_wrecked(n: Node3D) -> bool:
    if n == null or not is_instance_valid(n):
        return false
    if n is Station:
        return (n as Station).is_broken()
    if n is Tower:
        return (n as Tower).is_broken()
    return false


## 離 pos 最近的廢墟(工作站或塔);沒有回 null
func nearest_wrecked(pos: Vector3) -> Node3D:
    var best: Node3D = null
    var best_d := INF
    for s in stations:
        if s.is_broken() and s.global_position.distance_to(pos) < best_d:
            best_d = s.global_position.distance_to(pos)
            best = s
    for t in towers:
        if t.is_broken() and t.global_position.distance_to(pos) < best_d:
            best_d = t.global_position.distance_to(pos)
            best = t
    return best


## 修理工站哪裡修:建築南側一格
func repair_spot(n: Node3D) -> Vector3:
    return n.global_position + Vector3(0, 0, 1.6)


## 修理工修好了:走修復牌的免費付清(同一套 purchased 流程蓋回去);回傳有沒有修成
func repair_free(n: Node3D, by: Node3D) -> bool:
    if not is_wrecked(n):
        return false
    var pad: PricePad = null
    var name_key := ""
    if n is Station:
        pad = repair_pad_for((n as Station).spot_id)
        name_key = (n as Station).display_name_key()
    elif n is Tower:
        pad = tower_pad_for((n as Tower).id)
        name_key = "STATION_tower"
    if pad == null or not pad.complete_free():
        return false
    EventBus.building_repaired.emit(n, by)
    EventBus.notice.emit(tr("NOTICE_REPAIRED_BY") % tr(name_key))
    return true


## --- 旅行商人 / 地圖 ---

## 地圖碎片的兩塊牌(現金 / 稀有魚)同步成已買的片數
func _sync_map_pads() -> void:
    for id in ["map_cash", "map_fish"]:
        var p: PricePad = price_pads.get(id, null)
        if p != null:
            p.sync_buys(GameState.map_pieces)


## 地圖頁的資料(Hud.show_map 用):世界矩形 / 地點 / 玩家位置 / 碎片數
func map_data() -> Dictionary:
    var rects := []
    rects.append({"rect": Rect2(-12.6, -11.2, 25.2, 23.8), "color": Color(0.88, 0.76, 0.6), "label": "MAP_VILLAGE"})
    rects.append({"rect": Rect2(-23.4, -2.9, 10.8, 9.8), "color": Color(0.8, 0.62, 0.42), "label": "MAP_SHOP"})
    for k in mini(expansion_level(), ANNEX_RECTS.size()):
        rects.append({"rect": ANNEX_RECTS[k], "color": Color(0.88, 0.76, 0.6), "label": ""})
    if south_block != null:
        rects.append({"rect": SOUTH_RECT, "color": Color(0.88, 0.76, 0.6), "label": ""})
    for fa in fish_areas:
        rects.append({"rect": fa.rect, "color": Color(0.35, 0.65, 0.95), "label": ""})
    var points := []
    points.append({"pos": Vector2(DOCK_SPOT.x, DOCK_SPOT.z), "color": Color(0.45, 0.3, 0.2), "label": "MAP_DOCK"})
    points.append({"pos": Vector2(MERCHANT_CAMP.x, MERCHANT_CAMP.z), "color": Color(0.55, 0.18, 0.15), "label": "MAP_MERCHANT"})
    if GameState.has_full_map():
        points.append({"pos": Vector2(SHRINE_SPOT.x, SHRINE_SPOT.z), "color": Color(0.04, 0.07, 0.12), "label": "MAP_SHRINE"})
    var pp := player.global_position if player != null and is_instance_valid(player) else PLAYER_SPAWN
    return {"world": EXPLORE_RECT, "rects": rects, "points": points, "player": Vector2(pp.x, pp.z), "pieces": GameState.map_pieces,
            "total": GameState.MAP_PIECES, "unknown": [Rect2(90.0, -12.0, 30.0, 62.0), Rect2(-40.0, 50.0, 160.0, 14.0)]}


## 地圖頁的「回村」:拼齊三片才有;把玩家傳回主村出生點
func map_home() -> bool:
    if not GameState.has_full_map() or player == null:
        return false
    player.global_position = PLAYER_SPAWN
    player.velocity = Vector3.ZERO
    EventBus.notice.emit(tr("NOTICE_MAP_HOME"))
    return true


## 新版內容:更新後第一次開(有存檔的老玩家)彈面板;新玩家直接記成看過
func _maybe_show_changelog() -> void:
    var latest := GameData.latest_version()
    if latest == "":
        return
    if loaded_from_save and Settings.seen_version != latest:
        hud.show_changelog()
    Settings.mark_version_seen(latest)


## --- 熊王祭壇:戰利品牆 ---

## 武器店屋頂一排熊頭骨:打死王幾次放幾顆(最多 trophyCap)
func _refresh_trophies() -> void:
    if trophies == null:
        return
    for c in trophies.get_children():
        c.queue_free()
    var n := mini(GameState.king_kills, king_logic.trophy_cap())
    for i in n:
        var x := WEAPON_SHOP.x - 2.0 + 0.45 * float(i)
        trophies.add_child(VisualFactory.box(Vector3(0.32, 0.28, 0.3), Color(1.0, 0.97, 0.88), Vector3(x, 2.85, WEAPON_SHOP.z + 1.2)))
        trophies.add_child(VisualFactory.box(Vector3(0.34, 0.08, 0.12), Color(0.1, 0.1, 0.12), Vector3(x, 2.8, WEAPON_SHOP.z + 1.36)))


func _wall(pos: Vector3, size: Vector3) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.collision_layer = 1 << (Carrier.TERRAIN_LAYER - 1)
    body.collision_mask = 0
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = size
    shape.shape = box
    body.add_child(shape)
    body.position = pos
    world.add_child(body)
    return body


## 魚欄裝飾:北邊的深水池 + 柵欄 + 閘門(併進 scenery)+ 幾條裝飾魚(抓不到;會動所以是獨立節點,數量少一點)
func _build_pen_decoration() -> void:
    scenery.add_box(Vector3(16, 0.12, 5), Color(0.2, 0.45, 0.85), Vector3(0, -0.04, -14.0))
    for i in 17:
        var x := -8.0 + float(i)
        if absf(x) <= 1.5:
            continue
        scenery.add_cylinder(0.14, 1.1, Color(0.82, 0.62, 0.4), Vector3(x, 0.55, -11.5))
    scenery.add_box(Vector3(3.2, 1.0, 0.3), Color(0.9, 0.6, 0.3), Vector3(0, 0.5, -11.5))
    scenery.add_box(Vector3(16, 0.3, 0.3), Color(0.82, 0.62, 0.4), Vector3(0, 0.95, -11.5))
    for i in 6:
        var f := Fish.new()
        f.rect = Rect2(-7.5, -16.0, 15.0, 4.0)
        f.position = f.random_point()
        world.add_child(f)


## --- 建築 ---

func _add_station(spot_id: String) -> Station:
    var def := GameData.station(str(STATION_DEFS.get(spot_id, "cutting_table")))
    var s := Station.create(def)
    s.spot_id = spot_id
    s.level = self
    s.name = "Station_%s" % spot_id
    s.position = STATION_SPOTS.get(spot_id, Vector3.ZERO)
    world.add_child(s)
    stations.append(s)
    # 修復牌:就在桌子的位置,完好時藏著(當作已買),被王拆了 on_lost 才出現
    var rdef := GameData.repair_station()
    var pad := PricePad.create({"id": "repair_%s" % spot_id, "name": s.display_name_key(), "cost": int(rdef.get("cost", 200)),
            "rebuyMult": 1.0, "effect": {"type": "repair", "target": spot_id}})
    pad.position = s.position
    world.add_child(pad)
    pad.restore_state(1, 0)
    price_pads[pad.logic.id] = pad
    return s


func _add_counter(id: String) -> Counter:
    var c := Counter.create(GameData.counter(id))
    c.position = COUNTER_SPOTS.get(id, Vector3(0, 0, 8.5))
    c.money_pad = money_pad
    c.door = customer_door_for(c.position)
    c.expansion = expansion_level()   # 擴建後才蓋的櫃台一出生就套顧客成長
    world.add_child(c)
    counters.append(c)
    _assign_cashiers()
    return c


func _spawn_unlock(target: String) -> void:
    if _spawned_unlocks.has(target) or not UNLOCKS.has(target):
        return
    _spawned_unlocks[target] = true
    var spec: Dictionary = UNLOCKS[target]
    if int(spec.get("annex", 0)) > 0:
        _build_annex(int(spec.get("annex", 0)))
    for sid in spec.get("stations", []):
        _add_station(str(sid))
    for cid in spec.get("counters", []):
        _add_counter(str(cid))
    if bool(spec.get("expandShop", false)):
        for id in price_pads:
            (price_pads[id] as PricePad).expand()
    _refresh_tower_pads()   # 建築都生好了才知道哪些傳送帶牌 / 塔牌該開


func station_at(spot_id: String) -> Station:
    for s in stations:
        if s.spot_id == spot_id:
            return s
    return null


func counter_by_id(id: String) -> Counter:
    for c in counters:
        if c.def_id == id:
            return c
    return null


## 這座工作站的修復牌(效果 repair、target = spot_id)
func repair_pad_for(spot_id: String) -> PricePad:
    return price_pads.get("repair_%s" % spot_id, null) as PricePad


## 工作站被北極熊王拆了:修復牌出現、通知、存檔
func station_destroyed(s: Station, by: Node3D) -> void:
    if by is Bear and (by as Bear).is_king:
        king_wrecked += 1
    var pad := repair_pad_for(s.spot_id)
    if pad != null:
        pad.on_lost()
        EventBus.notice.emit(tr("NOTICE_STATION_DESTROYED") % [tr(s.display_name_key()), pad.logic.current_cost()])
    save_now()


## --- 守衛塔 ---

## 四座塔一開始就在(state none 只有牌子),買了牌才蓋起來
func _build_towers() -> void:
    for id in TOWER_SPOTS:
        var t := Tower.new()
        t.id = str(id)
        t.name = "Tower_%s" % id
        t.level = self
        t.position = TOWER_SPOTS[id]
        world.add_child(t)
        towers.append(t)


func tower_by_id(id: String) -> Tower:
    for t in towers:
        if t.id == id:
            return t
    return null


## 衛兵巡邏點:每塊地四個角落內側(避開北邊的水區)、南塊四角
func patrol_points() -> Array[Vector3]:
    var out: Array[Vector3] = []
    var rects: Array[Rect2] = [Rect2(-12.6, -11.2, 25.2, 23.8)]
    for k in mini(expansion_level(), ANNEX_RECTS.size()):
        rects.append(ANNEX_RECTS[k])
    for r in rects:
        out.append(Vector3(r.position.x + 3.0, 0, -2.6))
        out.append(Vector3(r.end.x - 3.0, 0, -2.6))
        out.append(Vector3(r.position.x + 3.0, 0, 6.8))
        out.append(Vector3(r.end.x - 3.0, 0, 6.8))
    if south_block != null:
        out.append(Vector3(-9.0, 0, 14.5))
        out.append(Vector3(9.0, 0, 14.5))
        out.append(Vector3(-9.0, 0, 29.0))
        out.append(Vector3(9.0, 0, 29.0))
    return out


## 衛兵要打的熊:活著的、最近的(含王);沒有回 null
func guard_target(pos: Vector3) -> Bear:
    if bears == null:
        return null
    var best: Bear = null
    var best_d := INF
    for b in bears.bears:
        if b == null or not is_instance_valid(b) or not b.alive():
            continue
        var dd := b.planar_distance_to(pos)
        if dd < best_d:
            best_d = dd
            best = b
    return best


## 玩家站在塔旁滿 5 秒(Tower._check_player):開升級面板(別的面板開著就不開)
func tower_upgrade_prompt(t: Tower) -> void:
    if t == null or not t.is_alive() or hud == null or hud.tower_open() or hud.menu_open():
        return
    tower_upgrading = t
    hud.show_tower_upgrade(tower_upgrade_data(t))


func tower_upgrade_data(t: Tower) -> Dictionary:
    return {"id": t.id, "rate": t.rate_level, "damage": t.damage_level, "max": t.logic.max_upgrades(), "cost": t.logic.upgrade_cost(),
            "wallet": GameState.wallet, "interval": t.current_interval(), "dmg": t.current_damage()}


## 面板上按了射速 / 傷害:錢包夠就扣 $500 升一級(各最多 10 次),面板留著並更新;回傳有沒有升成
func tower_stat_upgrade(kind: String) -> bool:
    var t := tower_upgrading
    if t == null or not is_instance_valid(t) or not t.is_alive():
        hud.panel_action("tower_close")
        return false
    var cost := t.logic.upgrade_cost()
    if t.upgrades_left(kind) <= 0:
        return false
    if GameState.wallet < cost:
        EventBus.notice.emit(tr("NOTICE_TOWER_UP_NO_CASH") % cost)
        return false
    GameState.spend_resource("cash", cost)
    t.apply_upgrade(kind)
    var level_now := t.rate_level if kind == "rate" else t.damage_level
    EventBus.tower_stat_upgraded.emit(t, kind, level_now)
    EventBus.notice.emit(tr("NOTICE_TOWER_UP_RATE" if kind == "rate" else "NOTICE_TOWER_UP_DAMAGE") % [level_now, t.current_interval() if kind == "rate" else t.current_damage()])
    hud.show_tower_upgrade(tower_upgrade_data(t))
    save_now()
    return true


## 蓋 / 修這座塔的牌(效果 tower、target = 塔 id)
func tower_pad_for(tower_id: String) -> PricePad:
    for id in price_pads:
        var p: PricePad = price_pads[id]
        if p.is_tower_pad() and str(p.logic.effect.get("target", "")) == tower_id:
            return p
    return null


func alive_towers() -> Array[Tower]:
    var out: Array[Tower] = []
    for t in towers:
        if t.is_alive():
            out.append(t)
    return out


## 塔被熊拆了:牌子重新出現(修復價)、通知、存檔
func tower_destroyed(t: Tower, by: Node3D) -> void:
    if by is Bear and (by as Bear).is_king:
        king_wrecked += 1
    var pad := tower_pad_for(t.id)
    if pad != null:
        pad.on_lost()
        EventBus.notice.emit(tr("NOTICE_TOWER_DESTROYED") % pad.logic.current_cost())
    _refresh_tower_pads()
    save_now()


## 這座塔的熊王牙強化牌(tooth_<塔 id>)
func tooth_pad_for(tower_id: String) -> PricePad:
    return price_pads.get("tooth_%s" % tower_id, null) as PricePad


## 擴建區的塔牌只在那塊地擴建後出現;熊王牙牌只在塔完好、還沒強化時出現;第 k 次擴建的牌(expand_village_k)要擴建 k - 1 次後才出現;
## 捕熊夾 / 誘餌牌跟著那塊地開放;傳送帶牌只在兩端(工作站、櫃台)都蓋好、帶子還沒蓋時出現
func _refresh_tower_pads() -> void:
    for t in towers:
        var area := tower_area(t.id)
        if area > 0:
            var tp := tower_pad_for(t.id)
            if tp != null:
                tp.set_open(area <= expansion_level())
        var pad := tooth_pad_for(t.id)
        if pad != null:
            pad.set_open(t.is_alive() and not t.is_strong())
    for k in range(2, ANNEX_RECTS.size() + 1):
        var ev: PricePad = price_pads.get("expand_village_%d" % k, null)
        if ev != null:
            ev.set_open(expansion_level() >= k - 1)
    for t in traps:
        var tp: PricePad = price_pads.get(t.id, null)
        if tp != null:
            tp.set_open(trap_area(t.id) <= expansion_level())
    for b in baits:
        var bp: PricePad = price_pads.get(b.id, null)
        if bp != null:
            bp.set_open(bait_area(b.id) <= expansion_level())
    var ev4: PricePad = price_pads.get("expand_village_4", null)
    if ev4 != null:
        ev4.set_open(expansion_level() >= ANNEX_RECTS.size() and south_block == null)
    for id in CONVEYORS:
        var cp: PricePad = price_pads.get(id, null)
        if cp != null:
            var spec: Dictionary = CONVEYORS[id]
            cp.set_open(conveyor_by_id(str(id)) == null and station_at(str(spec["from"])) != null and counter_by_id(str(spec["to"])) != null)
    _refresh_shrine()
    var hg: PricePad = price_pads.get("hire_guard", null)
    if hg != null:
        hg.set_open(south_block != null)   # 衛兵:擴建四次(南塊)後才能僱


## --- 捕熊夾 / 誘餌 / 傳送帶 ---

## 夾子與誘餌一開始就在(沒買是空的),牌子就是位置
func _build_traps() -> void:
    for id in TRAP_SPOTS:
        var t := Trap.new()
        t.id = str(id)
        t.name = "Trap_%s" % id
        t.level = self
        t.position = TRAP_SPOTS[id]
        world.add_child(t)
        traps.append(t)
    for id in BAIT_SPOTS:
        var b := Bait.new()
        b.id = str(id)
        b.name = "Bait_%s" % id
        b.level = self
        b.position = BAIT_SPOTS[id]
        world.add_child(b)
        baits.append(b)


func trap_by_id(id: String) -> Trap:
    for t in traps:
        if t.id == id:
            return t
    return null


func bait_by_id(id: String) -> Bait:
    for b in baits:
        if b.id == id:
            return b
    return null


func conveyor_by_id(id: String) -> Conveyor:
    for c in conveyors:
        if c.id == id:
            return c
    return null


## 夾子夾到熊:牌子同價重新出現、通知、存檔
func trap_used(t: Trap, _bear: Node3D) -> void:
    var pad: PricePad = price_pads.get(t.id, null)
    if pad != null:
        pad.on_lost()
    EventBus.notice.emit(tr("NOTICE_TRAP_TRIGGERED") % int(t.logic.damage(false)))
    save_now()


## 誘餌被吃光:牌子重新出現、通知、存檔
func bait_eaten(b: Bait, _bear: Node3D) -> void:
    var pad: PricePad = price_pads.get(b.id, null)
    if pad != null:
        pad.on_lost()
    EventBus.notice.emit(tr("NOTICE_BAIT_EATEN"))
    save_now()


## 蓋傳送帶(CONVEYORS[id]:工作站 -> 櫃台);兩端沒蓋好或已經有了回 null
func build_conveyor(id: String, silent: bool = false) -> Conveyor:
    if not CONVEYORS.has(id) or conveyor_by_id(id) != null:
        return null
    var spec: Dictionary = CONVEYORS[id]
    var s := station_at(str(spec["from"]))
    var c := counter_by_id(str(spec["to"]))
    if s == null or c == null:
        return null
    var belt := Conveyor.new()
    belt.name = "Conveyor_%s" % id
    belt.level = self
    belt.setup(id, s, c)
    world.add_child(belt)
    conveyors.append(belt)
    if not silent:
        EventBus.conveyor_built.emit(belt)
    _refresh_tower_pads()
    return belt


## --- 武器店等級 ---

## 武器牌可買到的等級 = 基本 3 級 + 武器店等級(GameState.shop_level);招牌跟著換
func _apply_shop_level() -> void:
    var wp: PricePad = price_pads.get("weapon", null)
    if wp != null and bears != null and bears.logic != null:
        wp.raise_max(bears.logic.weapon_levels_for_sale(GameState.shop_level))
    if shop_sign != null:
        shop_sign.text = tr("SIGN_WEAPON_SHOP_LV") % GameState.shop_level if GameState.shop_level > 0 else tr("SIGN_WEAPON_SHOP")


## --- 掉落物 ---

## 熊被打跑 / 王被打死:在原地掉毛皮 / 熊王牙
func _on_bear_defeated(bear: Node3D, _by: Node3D) -> void:
    if bear == null or not is_instance_valid(bear) or bears == null or bears.logic == null:
        return
    var king := bear is Bear and (bear as Bear).is_king
    if king:
        _king_slain(bear as Bear)
        return
    var kind := bears.logic.drop(king)
    if kind == "":
        return
    var n := bears.logic.drop_count(king, randf())
    for i in n:
        var off := Vector3.ZERO
        if i > 0:
            var a := TAU * float(i) / float(n)
            off = Vector3(cos(a), 0.0, sin(a)) * 0.8
        drop_loot(kind, bear.global_position + off)


## 打死王:算表現分與連勝、升級、里程碑,掉一個寶箱(走過去開 -> 三選一)
func _king_slain(b: Bear) -> void:
    var g := king_logic.grade(king_eaten, king_wrecked)
    var reward := king_logic.chest(g, GameState.king_streak, GameState.king_level, offline.rate(GameState.play_time), randf())
    reward["streak"] = king_logic.next_streak(GameState.king_streak, g)
    var milestone := GameState.king_slain(int(reward["streak"]), king_logic)
    drop_loot("chest", b.global_position, reward)
    _refresh_trophies()
    EventBus.king_leveled.emit(GameState.king_level)
    EventBus.notice.emit(tr("NOTICE_KING_LEVEL") % GameState.king_level)
    if milestone:
        EventBus.notice.emit(tr("NOTICE_KING_MILESTONE") % GameState.king_kills)
    save_now()


## 寶箱打開(Loot kind chest):保底熊王牙進資源,三選一面板開著時遊戲暫停
func chest_opened(l: Loot) -> void:
    loot.erase(l)
    pending_chest = l.data.duplicate(true)
    GameState.add_resource("tooth", int(pending_chest.get("teeth", 0)))
    EventBus.items_moved.emit("loot", "tooth", l.global_position + Vector3(0, 0.6, 0), player.stack_top(), int(pending_chest.get("teeth", 0)))
    EventBus.chest_opened.emit(pending_chest)
    var cards: Array = []
    for c in pending_chest.get("cards", []):
        cards.append({"title": card_text(c), "desc": card_desc(c), "color": card_color(c)})
    var g := str(pending_chest.get("grade", "normal"))
    var streak := int(pending_chest.get("streak", 0))
    var lvl := GameState.king_level - 1   # 寶箱倍率用的是打死前的等級
    var body: String = tr("CHEST_BODY_%s" % g) % [int(pending_chest.get("teeth", 0))] + "\n" + tr("CHEST_MULT") % [
            tr("GRADE_%s" % g), king_logic.grade_mult(g), streak, int(round(king_logic.streak_bonus(streak) * 100.0)),
            maxi(lvl, 0), int(round((king_logic.reward_level_mult(maxi(lvl, 0)) - 1.0) * 100.0)), float(pending_chest.get("mult", 1.0))]
    hud.process_mode = Node.PROCESS_MODE_ALWAYS
    hud.show_choice(tr("CHEST_TITLE"), body, cards)
    get_tree().paused = true


func card_text(c: Dictionary) -> String:
    match str(c.get("kind", "")):
        "cash":
            return tr("CARD_cash") % int(c.get("amount", 0))
        "pelt":
            return tr("CARD_pelt") % int(c.get("amount", 0))
    return tr("CARD_coupon_%s" % str(c.get("coupon", "insurance")))


## 卡片說明:這個數字怎麼來的 / 券有什麼用
func card_desc(c: Dictionary) -> String:
    match str(c.get("kind", "")):
        "cash":
            return tr("CARD_DESC_cash") % [int(round(offline.rate(GameState.play_time) * 60.0)), int(king_logic.cfg.get("cashSec", 90)), int(king_logic.cfg.get("cashMin", 100))]
        "pelt":
            return tr("CARD_DESC_pelt") % int(king_logic.cfg.get("pelts", 5))
    return tr("CARD_DESC_coupon_%s" % str(c.get("coupon", "insurance")))


static func card_color(c: Dictionary) -> Color:
    match str(c.get("kind", "")):
        "cash":
            return Color(1.0, 0.82, 0.25)
        "pelt":
            return Color(0.85, 0.9, 1.0)
    return Color(0.45, 0.9, 0.55)


## 選了第 i 張卡
func _claim_chest(i: int) -> void:
    get_tree().paused = false
    hud.process_mode = Node.PROCESS_MODE_INHERIT
    var cards: Array = pending_chest.get("cards", [])
    pending_chest = {}
    if i < 0 or i >= cards.size():
        return
    var c: Dictionary = cards[i]
    match str(c.get("kind", "")):
        "cash":
            GameState.add_wallet(int(c.get("amount", 0)))
            EventBus.items_moved.emit("cash", "cash", player.global_position + Vector3(0, 1.6, 0), player.global_position, 1)
            EventBus.notice.emit(tr("NOTICE_CHEST_cash") % int(c.get("amount", 0)))
        "pelt":
            GameState.add_resource("pelt", int(c.get("amount", 0)))
            EventBus.notice.emit(tr("NOTICE_CHEST_pelt") % int(c.get("amount", 0)))
        "coupon":
            var key := str(c.get("coupon", "insurance"))
            if key == "calm":
                bears.calm(king_logic.calm_sec())
                EventBus.notice.emit(tr("NOTICE_CALM") % int(king_logic.calm_sec()))
            else:
                GameState.add_coupon(key, 1)
                EventBus.notice.emit(tr("NOTICE_CHEST_coupon"))
    EventBus.chest_claimed.emit(c)
    save_now()


func drop_loot(kind: String, pos: Vector3, data: Dictionary = {}) -> Loot:
    var l := Loot.new()
    l.kind = kind
    l.data = data
    l.level = self
    l.name = "Loot_%s_%d" % [kind, loot.size() + 1]
    l.position = Vector3(pos.x, 0.0, pos.z)
    world.add_child(l)
    loot.append(l)
    EventBus.loot_dropped.emit(kind, l.position)
    return l


## Loot 撿起來時叫:從名單移除、通知
func loot_collected(l: Loot) -> void:
    loot.erase(l)
    EventBus.notice.emit(tr("NOTICE_LOOT_%s" % l.kind) % GameState.resource(l.kind))


## --- 幫手 ---

func spawn_helper(role: String, silent: bool = false) -> Helper:
    var h := Helper.new()
    h.role = role
    h.name = "Helper_%s_%d" % [role, helpers.size() + 1]
    h.level = self
    h.fish_area = fish_area
    h.position = HELPER_SPAWN + Vector3(randf_range(-1.0, 1.0), 0, randf_range(-0.5, 0.5))
    add_child(h)
    helpers.append(h)
    _assign_cashiers()
    if not silent:
        _spawn_flash(h.global_position)
        EventBus.notice.emit(tr("NOTICE_HIRED_%s" % role))
    EventBus.helper_hired.emit(role, h)
    return h


## 每個櫃台一個收銀員;沒櫃台可去的收銀員等新櫃台
func _assign_cashiers() -> void:
    for h in helpers:
        if h.role != "cashier":
            continue
        if h.assigned_counter != null and is_instance_valid(h.assigned_counter):
            continue
        for c in counters:
            if c.cashier == null or not is_instance_valid(c.cashier):
                c.cashier = h
                h.assigned_counter = c
                break


## 幫手被北極熊吃掉:從名單移除、收銀員的櫃台空出來、GameState 角色計數 -1、僱用牌退一個名額(買回價 ×1.5)、外觀縮小消失
func helper_eaten(h: Helper, bear: Node3D) -> void:
    if h == null or not is_instance_valid(h) or h.eaten:
        return
    helpers.erase(h)
    for c in counters:
        if c.cashier == h:
            c.cashier = null
    if bear is Bear and (bear as Bear).is_king:
        king_eaten += 1
    var insured := GameState.use_coupon("insurance")
    if insured:
        # 保險券:名額不扣、牌子不漲,幾秒後同角色的幫手自己回來
        _insured.append({"role": h.role, "at": GameState.play_time + king_logic.insurance_return_sec()})
        EventBus.helper_insured.emit(h.role)
        EventBus.notice.emit(tr("NOTICE_INSURANCE") % [tr("ROLE_%s" % h.role), int(king_logic.insurance_return_sec())])
    else:
        GameState.lose_helper(h.role)
        var pad := hire_pad_for(h.role)
        if pad != null:
            pad.on_lost()
    h.be_eaten()
    EventBus.helper_eaten.emit(h.role, h)
    if bears != null:
        bears.on_helper_eaten(bear)   # 整群吃滿 packMaxEats 個就撤退
    if not insured:
        EventBus.notice.emit(tr("NOTICE_BEAR_ATE") % tr("ROLE_%s" % h.role))
    _assign_cashiers()
    save_now()


## 北極熊王吃掉水裡的魚:從它的水區移除
func fish_eaten(f: Fish, bear: Node3D) -> void:
    if f == null or not is_instance_valid(f):
        return
    for fa in fish_areas:
        if fa.fish.has(f):
            fa.remove_fish(f)
            EventBus.fish_eaten.emit(bear)
            return
    f.queue_free()


## 僱用 role 的那塊牌(沒有回 null)
func hire_pad_for(role: String) -> PricePad:
    for id in price_pads:
        var p: PricePad = price_pads[id]
        if str(p.logic.effect.get("type", "")) == "hire" and str(p.logic.effect.get("role", "")) == role:
            return p
    return null


func _spawn_flash(pos: Vector3) -> void:
    var ring := VisualFactory.cylinder(0.9, 0.08, Color(0.75, 0.45, 1.0, 0.8), pos + Vector3(0, 0.1, 0))
    ring.material_override = VisualFactory.material(Color(0.75, 0.45, 1.0, 0.8), Color(0.6, 0.3, 1.0), true)
    world.add_child(ring)
    var tw := create_tween()
    tw.set_parallel(true)
    tw.tween_property(ring, "scale", Vector3(2.5, 1.0, 2.5), 0.5)
    tw.tween_property(ring, "transparency", 1.0, 0.5)
    tw.chain().tween_callback(ring.queue_free)


## 收 item 的工作站裡,輸入堆最空的(都滿了回 null)
func find_station_accepting(item: String) -> Station:
    var best: Station = null
    var best_space := 0
    for s in stations:
        if not s.is_broken() and s.logic.accepts(item) and s.logic.input_space_of(item) > best_space:
            best = s
            best_space = s.logic.input_space_of(item)
    return best


func find_station_with_input(item: String) -> Station:
    for s in stations:
        if not s.is_broken() and s.logic.accepts(item):
            return s
    return null


## 產 item 且輸出堆還有空位的工作站(搬運工把送不出去的貨放回去用)
func find_station_with_output(item: String) -> Station:
    for s in stations:
        if not s.is_broken() and s.logic.output_id == item and s.logic.output_count < s.logic.output_cap:
            return s
    return null


## 給 PorterPlanner 的目的地清單:櫃台(賣什麼)+ 工作站原料(吃什麼、產什麼、成品堆滿停工沒)+ 碼頭的訂單(每種貨一筆,當作櫃台),
## 帶 node 方便對回去;被拆的工作站不算
func porter_dests() -> Array:
    var out := []
    for c in counters:
        out.append({"id": c.get_instance_id() * 4, "node": c, "kind": "counter", "item": c.logic.item_id, "stock": c.logic.stock, "cap": c.logic.stock_cap})
    if dock != null and orders != null and orders.has_order():
        var i := 0
        for item in orders.wanted_items():
            if str(item) == OrderLogic.RARE_ITEM:
                continue   # 稀有魚是玩家的資源,搬運工搬不了
            var l: Dictionary = orders.order["lines"][item]
            out.append({"id": dock.get_instance_id() * 4 + i, "node": dock, "kind": "counter", "item": str(item), "stock": int(l["done"]), "cap": int(l["need"])})
            i += 1
    for s in stations:
        if s.is_broken():
            continue
        for i in s.logic.inputs.size():   # 多原料的工作站每種原料一個目的地(id 用整數:instance id 乘 4 加序號,PorterPlanner 用 == 比)
            var item: String = s.logic.inputs[i]
            out.append({"id": s.get_instance_id() * 4 + i, "node": s, "kind": "station", "item": item, "stock": s.logic.input_count_of(item),
                    "cap": s.logic.input_cap, "out": s.logic.output_id, "blocked": s.logic.is_blocked()})
    return out


## 給 PorterPlanner 的來源清單:工作站輸出堆
func porter_sources() -> Array:
    var out := []
    for s in stations:
        if s.is_broken():
            continue
        out.append({"id": s.get_instance_id() * 4, "node": s, "item": s.logic.output_id, "count": s.logic.output_count})   # id 與 porter_dests 同一套(×4)
    return out


## 手上已經有 item 時該送去哪:收它且有空位、需求最高的櫃台或工作站;沒地方放回 null
func find_dest_for(item: String, exclude: Node3D) -> Node3D:
    var exclude_id = null
    if exclude != null and is_instance_valid(exclude):
        exclude_id = exclude.get_instance_id()
    var d := PorterPlanner.best_dest(porter_dests(), item, exclude_id)
    return d.get("node", null) if not d.is_empty() else null


## 搬運工的工作:哪裡最缺貨就先補哪裡(規則在 PorterPlanner);回 {"from": Station, "to": Node3D, "item", "amount"},沒事做回空字典
func find_porter_job(capacity: int) -> Dictionary:
    var p := PorterPlanner.plan(porter_dests(), porter_sources(), capacity)
    if p.is_empty():
        return {}
    return {"from": p["from"]["node"], "to": p["to"]["node"], "item": str(p["item"]), "amount": int(p["amount"])}


func _on_purchased(_id: String, effect: Dictionary) -> void:
    match str(effect.get("type", "")):
        "hire":
            spawn_helper(str(effect.get("role", "fisher")))
        "unlock":
            _spawn_unlock(str(effect.get("target", "")))
        "weapon":
            if player != null:
                player._refresh_weapon()
        "tower":
            var t := tower_by_id(str(effect.get("target", "")))
            if t != null:
                var repaired := t.is_broken()
                t.build()
                EventBus.notice.emit(tr("NOTICE_TOWER_REPAIRED" if repaired else "NOTICE_TOWER_BUILT"))
            _refresh_tower_pads()
        "tower_upgrade":
            var t := tower_by_id(str(effect.get("target", "")))
            if t != null and t.upgrade():
                EventBus.notice.emit(tr("NOTICE_TOWER_STRONG") % [int(t.hp_max), int(t.logic.damage(t.tier))])
            _refresh_tower_pads()
        "shop_upgrade":
            _apply_shop_level()
            EventBus.shop_upgraded.emit(GameState.shop_level)
            EventBus.notice.emit(tr("NOTICE_SHOP_UPGRADED") % GameState.shop_level)
        "repair":
            var s := station_at(str(effect.get("target", "")))
            if s != null:
                s.repair()
                EventBus.notice.emit(tr("NOTICE_STATION_REPAIRED") % tr(s.display_name_key()))
        "trap":
            var t := trap_by_id(str(effect.get("target", "")))
            if t != null:
                t.arm()
                EventBus.notice.emit(tr("NOTICE_TRAP_SET"))
        "bait":
            var b := bait_by_id(str(effect.get("target", "")))
            if b != null:
                b.place()
                EventBus.notice.emit(tr("NOTICE_BAIT_SET"))
        "conveyor":
            var belt := build_conveyor(str(effect.get("target", "")))
            if belt != null:
                EventBus.notice.emit(tr("NOTICE_CONVEYOR_BUILT"))
        "coupon":
            pass   # GameState.apply_purchase 已經加券
        "map_piece":
            _sync_map_pads()
            _refresh_shrine()
            EventBus.map_piece_bought.emit(GameState.map_pieces)
            EventBus.notice.emit(tr("NOTICE_MAP_FULL") if GameState.has_full_map() else tr("NOTICE_MAP_PIECE") % [GameState.map_pieces, GameState.MAP_PIECES])
        "shrine":
            _refresh_shrine()
            EventBus.shrine_offered.emit()
            EventBus.notice.emit(tr("NOTICE_SHRINE"))
            if story != null:
                story.refresh()
        "resource":
            EventBus.items_moved.emit("loot", str(effect.get("kind", "pelt")), merchant.global_position + Vector3(0, 1.4, 0) if merchant != null else player.global_position,
                    player.stack_top(), int(effect.get("amount", 1)))
    if str(effect.get("type", "")) == "unlock" and str(effect.get("target", "")) == "ice_traps":
        EventBus.notice.emit(tr("NOTICE_ICE_TRAPS"))


## --- 存檔 ---

## 世界狀態(GameState 之外的):玩家背上、錢格、各工作站堆 / 是否被拆、各櫃台庫存、各價格牌進度(含修復牌)、守衛塔狀態 / 血量 / 強化、地上的掉落物、
## 捕熊夾 / 誘餌放好沒、傳送帶上的貨、北極熊冷卻
func snapshot() -> Dictionary:
    var stations_d := {}
    for s in stations:
        var sd := {"input": s.logic.input_count, "output": s.logic.output_count, "broken": s.is_broken()}
        if s.logic.is_multi_input():
            sd["inputs"] = s.logic.counts.duplicate()
        stations_d[s.spot_id] = sd
    var counters_d := {}
    for c in counters:
        counters_d[c.def_id] = {"stock": c.logic.stock}
    var pads_d := {}
    for id in price_pads:
        var p: PricePad = price_pads[id]
        pads_d[str(id)] = {"remaining": p.logic.remaining, "buys": p.logic.buys, "lost": p.logic.lost}
    var towers_d := {}
    for t in towers:
        towers_d[t.id] = t.snapshot()
    var loot_d := []
    for l in loot:
        if l != null and is_instance_valid(l):
            loot_d.append(l.snapshot())
    var traps_d := {}
    for t in traps:
        traps_d[t.id] = t.snapshot()
    var baits_d := {}
    for b in baits:
        baits_d[b.id] = b.snapshot()
    var belts_d := {}
    for c in conveyors:
        belts_d[c.id] = c.snapshot()
    return {
        "player": {"item": player.stack.item_id, "count": player.stack.count, "x": player.global_position.x, "z": player.global_position.z},
        "money": money_pad.cash, "stations": stations_d, "counters": counters_d, "pads": pads_d, "towers": towers_d,
        "loot": loot_d, "traps": traps_d, "baits": baits_d, "belts": belts_d, "bear": bears.snapshot() if bears != null else {},
        "income_rate": offline.rate(GameState.play_time) if offline != null else 0.0,
        "orders": orders.snapshot() if orders != null else {},
    }


func restore_world(d: Dictionary) -> void:
    var pl = d.get("player", {})
    if typeof(pl) == TYPE_DICTIONARY:
        if pl.has("x") and pl.has("z"):   # 存檔時站哪(村外探險也記)
            var px := Vector3(float(pl["x"]), 0.0, float(pl["z"]))
            if EXPLORE_RECT.has_point(Vector2(px.x, px.z)):
                player.global_position = px
        player.stack.clear()
        var item := str(pl.get("item", ""))
        for i in int(pl.get("count", 0)):
            if item == "" or not player.stack.push(item):
                break
    money_pad.set_cash(int(d.get("money", 0)))
    var st = d.get("stations", {})
    if typeof(st) == TYPE_DICTIONARY:
        for spot in st:
            var s := station_at(str(spot))
            if s != null and typeof(st[spot]) == TYPE_DICTIONARY:
                s.logic.input_count = clampi(int(st[spot].get("input", 0)), 0, s.logic.input_cap)
                var ins = st[spot].get("inputs", null)
                if typeof(ins) == TYPE_DICTIONARY:
                    for item in ins:
                        if s.logic.accepts(str(item)):
                            s.logic.counts[str(item)] = clampi(int(ins[item]), 0, s.logic.input_cap)
                s.logic.output_count = clampi(int(st[spot].get("output", 0)), 0, s.logic.output_cap)
                s.refresh_piles()
                s.set_broken(bool(st[spot].get("broken", false)))
    var ct = d.get("counters", {})
    if typeof(ct) == TYPE_DICTIONARY:
        for id in ct:
            var c := counter_by_id(str(id))
            if c != null and typeof(ct[id]) == TYPE_DICTIONARY:
                c.logic.stock = clampi(int(ct[id].get("stock", 0)), 0, c.logic.stock_cap)
                c.refresh_pile()
    var pads = d.get("pads", {})
    if typeof(pads) == TYPE_DICTIONARY:
        for id in pads:
            if price_pads.has(str(id)) and typeof(pads[id]) == TYPE_DICTIONARY:
                (price_pads[str(id)] as PricePad).restore_state(int(pads[id].get("buys", 0)), int(pads[id].get("remaining", 0)),
                        int(pads[id].get("lost", 0)))
    for s in stations:
        # 廢墟的修復牌一定要開著(存檔沒記到牌子也一樣)
        var rp := repair_pad_for(s.spot_id)
        if s.is_broken() and rp != null and rp.logic.is_exhausted():
            rp.on_lost()
    var towers_d = d.get("towers", {})
    for t in towers:
        if typeof(towers_d) == TYPE_DICTIONARY and typeof(towers_d.get(t.id, null)) == TYPE_DICTIONARY:
            t.restore(towers_d[t.id])
        else:
            # 存檔沒記這座塔(舊檔):牌買過就當完好
            var pad := tower_pad_for(t.id)
            if pad != null and pad.logic.buys >= 1:
                t.build(true)
    var loot_d = d.get("loot", [])
    if typeof(loot_d) == TYPE_ARRAY:
        for e in loot_d:
            if typeof(e) == TYPE_DICTIONARY and e.has("kind"):
                var dd = e.get("data", {})
                drop_loot(str(e["kind"]), Vector3(float(e.get("x", 0.0)), 0.0, float(e.get("z", 0.0))), dd if typeof(dd) == TYPE_DICTIONARY else {})
    # 捕熊夾 / 誘餌:存檔記放好沒;牌子買過卻沒放好(舊檔、或用掉的瞬間沒存到)就讓牌子重新出現
    var traps_d = d.get("traps", {})
    for t in traps:
        if typeof(traps_d) == TYPE_DICTIONARY and typeof(traps_d.get(t.id, null)) == TYPE_DICTIONARY:
            t.restore(traps_d[t.id])
        var tp: PricePad = price_pads.get(t.id, null)
        if tp != null and tp.logic.is_exhausted() and not t.is_armed():
            tp.on_lost()
    var baits_d = d.get("baits", {})
    for b in baits:
        if typeof(baits_d) == TYPE_DICTIONARY and typeof(baits_d.get(b.id, null)) == TYPE_DICTIONARY:
            b.restore(baits_d[b.id])
        var bp: PricePad = price_pads.get(b.id, null)
        if bp != null and bp.logic.is_exhausted() and not b.is_set():
            bp.on_lost()
    var belts_d = d.get("belts", {})
    if typeof(belts_d) == TYPE_DICTIONARY:
        for c in conveyors:
            if typeof(belts_d.get(c.id, null)) == TYPE_ARRAY:
                c.restore(belts_d[c.id])
    _refresh_tower_pads()
    _sync_map_pads()
    var od = d.get("orders", {})
    if orders != null and typeof(od) == TYPE_DICTIONARY:
        orders.restore(od)
        _refresh_order_text()
    var bear_d = d.get("bear", {})
    if bears != null and typeof(bear_d) == TYPE_DICTIONARY:
        bears.restore(bear_d)


func save_now() -> bool:
    if player == null or not is_instance_valid(player):
        return false
    return SaveManager.write({"state": GameState.to_dict(), "world": snapshot()})


## 有存檔就還原:GameState -> 依解鎖重建建築 -> 依僱用數重生幫手 -> 世界數量
func _load_save() -> void:
    var data := SaveManager.read()
    if data.is_empty():
        return
    var state = data.get("state", {})
    if typeof(state) == TYPE_DICTIONARY:
        GameState.from_dict(state)
        Sfx.set_enabled(GameState.sound_on)
    for target in UNLOCKS:
        if GameState.is_unlocked(str(target)):
            _spawn_unlock(str(target))
    _apply_shop_level()   # 要在 restore_world 之前,武器牌的 buys 才不會被夾回 3
    for id in CONVEYORS:
        if GameState.is_unlocked(str(id)):
            build_conveyor(str(id), true)
    for role in GameState.hired:
        for i in GameState.hired_count(str(role)):
            spawn_helper(str(role), true)
    var world_d = data.get("world", {})
    var prev_rate := 0.0
    if typeof(world_d) == TYPE_DICTIONARY:
        restore_world(world_d)
        prev_rate = maxf(float(world_d.get("income_rate", 0.0)), 0.0)
    loaded_from_save = true
    offline.begin(GameState.play_time, prev_rate)
    # 離線收益:教學做完才算;金額 > 0 才彈面板(_ready 最後 _show_offline)
    if GameState.tutorial_step >= GuideLogic.tutorial_steps():
        offline_sec = OfflineLogic.offline_seconds(int(data.get("savedAt", 0)), int(Time.get_unix_time_from_system()))
        _offline_pending = offline.earnings(prev_rate, float(offline_sec))


## 彈出離線收益面板並暫停遊戲(HUD 設成 ALWAYS 才收得到按鈕);領取走 _on_hud_action "offline_claim"
func _show_offline() -> void:
    hud.process_mode = Node.PROCESS_MODE_ALWAYS
    hud.show_offline(_offline_pending, offline_sec, offline.counted_seconds(float(offline_sec)))
    get_tree().paused = true


func _claim_offline() -> void:
    var cash := _offline_pending
    _offline_pending = 0
    get_tree().paused = false
    hud.process_mode = Node.PROCESS_MODE_INHERIT
    if cash <= 0:
        return
    GameState.claim_offline(cash)
    EventBus.offline_claimed.emit(cash, offline_sec)
    EventBus.items_moved.emit("cash", "cash", player.global_position + Vector3(0, 1.6, 0), player.global_position, 1)
    EventBus.notice.emit(tr("NOTICE_OFFLINE") % cash)
    save_now()


func _physics_process(delta: float) -> void:
    GameState.play_time += delta
    hud.income_rate = offline.rate(GameState.play_time)
    _tick_orders(delta)
    if not _insured.is_empty() and GameState.play_time >= float(_insured[0].get("at", 0.0)):
        var e: Dictionary = _insured.pop_front()
        spawn_helper(str(e.get("role", "fisher")))
    _autosave_timer -= delta
    if _autosave_timer <= 0.0:
        _autosave_timer = autosave_sec
        save_now()


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        save_now()   # 網頁版切到背景 / 自動更新重新整理前也存


## HUD 選單:提示箭頭開關、重新開始(手機沒有 H / F9)
func _on_hud_action(id: String) -> void:
    match id:
        "hints":
            if guide != null:
                guide.toggle_hints()
        "new_game":
            new_game()
        "offline_claim":
            _claim_offline()
        "map_home":
            map_home()
        "journal":
            if story != null:
                hud.show_journal(story.chapter_entries(), story.journal_entries())
        "tower_up:rate", "tower_up:damage":
            tower_stat_upgrade(id.trim_prefix("tower_up:"))
        _:
            if id.begins_with("choice:"):
                _claim_chest(int(id.trim_prefix("choice:")))


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("new_game"):
        new_game()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("toggle_hints") and guide != null:
        guide.toggle_hints()
        get_viewport().set_input_as_handled()


func clear_save_and_state() -> void:
    SaveManager.delete()
    GameState.reset()


func _exit_tree() -> void:
    if get_tree() != null and get_tree().paused:
        get_tree().paused = false   # 面板開著時換場景 / 測試拆關卡,別讓新關卡卡在暫停


## F9:刪存檔、清狀態、重載場景
func new_game() -> void:
    clear_save_and_state()
    get_tree().reload_current_scene()
