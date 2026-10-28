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
## 守衛塔(Tower):村莊四角各一座(tower_1 ~ 4)+ 村中央水邊兩座(tower_5 / 6,在切魚台輸入格之間,補四角射程 9 照不到的中間),
## 牌子($200)就是地基;蓋好會朝靠近的熊射箭,被熊拆掉後站回地基花 $200 修。
## 北極熊王會拆工作站(切魚台 / 烤魚攤):_add_station 時順便生一塊藏著的修復牌(repair_<spot_id>,shop.json repairStation $200)在桌子位置,
## 被拆(station_destroyed)才出現,付清 _on_purchased "repair" 修好。
## 掉落物(Loot):熊被打跑掉毛皮、王被打死掉熊王牙(_on_bear_defeated -> drop_loot),玩家走過去撿(GameState.pelts / teeth)。
## 武器店升級牌(shop_upgrade,收毛皮 5 / 10 / 20)在院子裡:每級讓武器牌多賣一級(_apply_shop_level -> raise_max,武器 Lv4 ~ 6);
## 熊王牙牌(tooth_tower_n,收 1 顆)就在塔下,塔完好且還沒強化才出現(_refresh_tower_pads),付清 tower.upgrade() 變強力守衛塔。

const STATION_SPOTS := {"station_1": Vector3(-6.0, 0, 0), "station_2": Vector3(0.0, 0, 0), "grill": Vector3(6.0, 0, 0),
    "station_3": Vector3(18.0, 0, 0), "grill_2": Vector3(25.0, 0, 0)}
const STATION_DEFS := {"station_1": "cutting_table", "station_2": "cutting_table", "grill": "grill", "station_3": "cutting_table", "grill_2": "grill"}
const COUNTER_SPOTS := {"fillet_counter": Vector3(-9.0, 0, 8.5), "grill_counter": Vector3(3.0, 0, 8.5),
    "fillet_counter_2": Vector3(15.0, 0, 8.5), "grill_counter_2": Vector3(25.0, 0, 8.5)}
const PAD_SPOTS := {
    "hire_fisher": Vector3(-10.0, 0, 5.0), "hire_porter": Vector3(-6.0, 0, 5.0), "hire_cashier": Vector3(-2.0, 0, 5.0),
    "capacity_1": Vector3(2.0, 0, 5.0), "upgrade_worker_speed": Vector3(6.0, 0, 5.0), "upgrade_pile_cap": Vector3(10.0, 0, 5.0),
    "expand_table": Vector3(0.0, 0, 0), "unlock_grill": Vector3(6.0, 0, 0),
    "weapon": Vector3(-19.5, 0, 4.0), "expand_village": Vector3(10.0, 0, 0.0),
    "tower_1": Vector3(-11.0, 0, -9.5), "tower_2": Vector3(11.0, 0, -9.5), "tower_3": Vector3(-11.0, 0, 11.0), "tower_4": Vector3(11.0, 0, 11.0),
    "tower_5": Vector3(-3.0, 0, -2.9), "tower_6": Vector3(3.0, 0, -2.9),
    "shop_upgrade": Vector3(-15.5, 0, 4.6),
    "tooth_tower_1": Vector3(-11.0, 0, -9.5), "tooth_tower_2": Vector3(11.0, 0, -9.5), "tooth_tower_3": Vector3(-11.0, 0, 11.0), "tooth_tower_4": Vector3(11.0, 0, 11.0),
    "tooth_tower_5": Vector3(-3.0, 0, -2.9), "tooth_tower_6": Vector3(3.0, 0, -2.9),
}
# 守衛塔(= 牌子的位置,牌是地基):四角 + 村中央水邊兩座(x ±3 是切魚台輸入格之間的空地,z -2.9 貼著淺水區南緣,屋頂只遮到水面)
const TOWER_SPOTS := {"tower_1": Vector3(-11.0, 0, -9.5), "tower_2": Vector3(11.0, 0, -9.5),
    "tower_3": Vector3(-11.0, 0, 11.0), "tower_4": Vector3(11.0, 0, 11.0),
    "tower_5": Vector3(-3.0, 0, -2.9), "tower_6": Vector3(3.0, 0, -2.9)}
const UNLOCKS := {
    "station_2": {"stations": ["station_2"], "counters": []},
    "grill_complex": {"stations": ["grill"], "counters": ["grill_counter"]},
    "village_2": {"stations": ["station_3", "grill_2"], "counters": ["fillet_counter_2", "grill_counter_2"], "annex": true, "expandShop": true},
}
const EAST_GATE_Z := Vector2(-4.0, 4.0)     # 東牆中段的門(柵欄缺口的外觀;擴建時整面東牆都拆)
const ANNEX_RECT := Rect2(13.0, -11.0, 18.6, 23.6)   # 擴建區(x 13 ~ 31.6)
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
var annex: StaticBatch = null           # 擴建區的布景(蓋了才有)
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
    _add_counter("fillet_counter")
    for def in GameData.shop():
        var id := str(def["id"])
        var pad := PricePad.create(def)
        pad.position = PAD_SPOTS.get(id, Vector3(0, 0, 12))
        world.add_child(pad)
        price_pads[id] = pad
        if id.begins_with("tooth_") and pad.label != null:
            pad.label.position.y = 6.4   # 牌子在塔底下,字要浮在塔頂上
    _build_towers()
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
    add_child(hud)
    autosave_sec = maxf(float(GameData.config().get("autosaveSec", 10.0)), 1.0)
    _autosave_timer = autosave_sec
    _load_save()
    _apply_shop_level()
    _refresh_tower_pads()
    EventBus.bear_defeated.connect(_on_bear_defeated)
    guide = Guide.new()
    guide.name = "Guide"
    guide.level = self
    add_child(guide)
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
    scenery.add_box(Vector3(70, 0.2, 80), Color(0.93, 0.95, 0.98), Vector3(0, -0.12, -3))
    scenery.add_box(Vector3(25, 0.06, 16.5), Color(0.88, 0.76, 0.6), Vector3(0, -0.02, 4.0))
    # 西牆留缺口(GATE_Z)通往村外的武器店
    _wall(Vector3(-12.6, 1, (-13.0 + GATE_Z.x) / 2.0), Vector3(0.4, 2, GATE_Z.x + 13.0))
    _wall(Vector3(-12.6, 1, (GATE_Z.y + 13.0) / 2.0), Vector3(0.4, 2, 13.0 - GATE_Z.y))
    # 整面東牆(擴建村莊時全部拆掉,主村與 annex 連成一片)
    east_walls.append(_wall(Vector3(12.6, 1, (-13.0 + EAST_GATE_Z.x) / 2.0), Vector3(0.4, 2, EAST_GATE_Z.x + 13.0)))
    east_walls.append(_wall(Vector3(12.6, 1, (EAST_GATE_Z.y + 13.0) / 2.0), Vector3(0.4, 2, 13.0 - EAST_GATE_Z.y)))
    east_gate = _wall(Vector3(12.6, 1, (EAST_GATE_Z.x + EAST_GATE_Z.y) / 2.0), Vector3(0.4, 2, EAST_GATE_Z.y - EAST_GATE_Z.x))
    east_walls.append(east_gate)
    _wall(Vector3(0, 1, 12.6), Vector3(26, 2, 0.4))
    _wall(Vector3(0, 1, -11.2), Vector3(26, 2, 0.4))
    var fence := Color(0.8, 0.62, 0.42)
    east_gate_mesh = VisualFactory.box(Vector3(0.25, 0.9, EAST_GATE_Z.y - EAST_GATE_Z.x + 0.25), fence,
            Vector3(12.4, 0.45, (EAST_GATE_Z.x + EAST_GATE_Z.y) / 2.0))
    world.add_child(east_gate_mesh)
    east_walls.append(east_gate_mesh)
    var east_fence := VisualFactory.box(Vector3(0.25, 0.9, 12.25 - EAST_GATE_Z.y), fence, Vector3(12.4, 0.45, (EAST_GATE_Z.y + 12.25) / 2.0))
    world.add_child(east_fence)
    east_walls.append(east_fence)
    scenery.add_box(Vector3(0.25, 0.9, GATE_Z.x + 4.25), fence, Vector3(-12.4, 0.45, (GATE_Z.x - 4.25) / 2.0))
    scenery.add_box(Vector3(0.25, 0.9, 12.25 - GATE_Z.y), fence, Vector3(-12.4, 0.45, (GATE_Z.y + 12.25) / 2.0))
    scenery.add_box(Vector3(25, 0.9, 0.25), fence, Vector3(0, 0.45, 12.4))
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
    scenery.add_box(Vector3(0.25, 0.9, 9.4), fence, Vector3(-23.2, 0.45, 2.0))
    scenery.add_box(Vector3(10.6, 0.9, 0.25), fence, Vector3(-18.0, 0.45, -2.7))
    scenery.add_box(Vector3(10.6, 0.9, 0.25), fence, Vector3(-18.0, 0.45, 6.7))
    _wall(Vector3(-23.4, 1, 2.0), Vector3(0.4, 2, 10.0))
    _wall(Vector3(-18.0, 1, -2.9), Vector3(11.2, 2, 0.4))
    _wall(Vector3(-18.0, 1, 6.9), Vector3(11.2, 2, 0.4))
    # 顏色盡量沿用既有布景(StaticBatch 每種顏色一個 surface)
    scenery.add_box(Vector3(4.2, 2.4, 2.6), Color(0.45, 0.3, 0.2), WEAPON_SHOP + Vector3(0, 1.2, 0))
    scenery.add_box(Vector3(4.8, 0.3, 3.2), Color(0.55, 0.18, 0.15), WEAPON_SHOP + Vector3(0, 2.55, 0))
    scenery.add_box(Vector3(3.2, 0.9, 0.6), fence, Vector3(WEAPON_SHOP.x, 0.45, 1.5))
    scenery.add_box(Vector3(3.4, 0.08, 0.8), sand, Vector3(WEAPON_SHOP.x, 0.94, 1.5))
    shop_sign = VisualFactory.label(tr("SIGN_WEAPON_SHOP"), WEAPON_SHOP + Vector3(0, 3.3, 0), 48, Color(1.0, 0.9, 0.7))
    world.add_child(shop_sign)
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


## 擴建區(annex):整面東牆拆掉(隱形牆 + 柵欄),往東蓋沙地、柵欄、隱形牆、第二個水區與深水池;建築由 _spawn_unlock 依 UNLOCKS 生
func _build_annex() -> void:
    if annex != null:
        return
    for w in east_walls:
        if w != null and is_instance_valid(w):
            w.queue_free()
    east_walls.clear()
    east_gate = null
    east_gate_mesh = null
    annex = StaticBatch.new()
    annex.name = "Annex"
    world.add_child(annex)
    var fence := Color(0.8, 0.62, 0.42)
    var cx := ANNEX_RECT.get_center().x
    annex.add_box(Vector3(ANNEX_RECT.size.x + 0.8, 0.06, 16.5), Color(0.88, 0.76, 0.6), Vector3(cx - 0.4, -0.02, 4.0))   # 沙地接到主村,中間沒縫
    annex.add_box(Vector3(0.25, 0.9, 16.5), fence, Vector3(ANNEX_RECT.end.x - 0.2, 0.45, 4.0))
    annex.add_box(Vector3(ANNEX_RECT.size.x, 0.9, 0.25), fence, Vector3(cx, 0.45, 12.4))
    annex.add_box(Vector3(16, 0.12, 5), Color(0.2, 0.45, 0.85), Vector3(cx, -0.04, -14.0))
    for i in 17:
        var x := cx - 8.0 + float(i)
        if absf(x - cx) <= 1.5:
            continue
        annex.add_cylinder(0.14, 1.1, fence, Vector3(x, 0.55, -11.5))
    annex.add_box(Vector3(16, 0.3, 0.3), fence, Vector3(cx, 0.95, -11.5))
    annex.build()
    _wall(Vector3(ANNEX_RECT.end.x, 1, 0), Vector3(0.4, 2, 26))
    _wall(Vector3(cx, 1, 12.6), Vector3(ANNEX_RECT.size.x + 0.4, 2, 0.4))
    _wall(Vector3(cx, 1, -11.2), Vector3(ANNEX_RECT.size.x + 0.4, 2, 0.4))
    var fa := FishArea.new()
    fa.name = "FishArea2"
    fa.rect = Rect2(cx - 8.0, -11.0, 16.0, 7.0)
    world.add_child(fa)
    fish_areas.append(fa)
    _apply_quality()


func is_expanded() -> bool:
    return annex != null


## 幫手從 from 走到 to 要經過的中途點(不含終點)。擴建後東牆整段拆掉,主村與 annex 之間沒有牆,所以目前永遠是空陣列;
## 留著給 Helper.go_to 用,以後若加了要繞的牆在這裡補規則。
func route(_from: Vector3, _to: Vector3) -> Array[Vector3]:
    var out: Array[Vector3] = []
    return out


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
    world.add_child(c)
    counters.append(c)
    _assign_cashiers()
    return c


func _spawn_unlock(target: String) -> void:
    if _spawned_unlocks.has(target) or not UNLOCKS.has(target):
        return
    _spawned_unlocks[target] = true
    var spec: Dictionary = UNLOCKS[target]
    if bool(spec.get("annex", false)):
        _build_annex()
    for sid in spec.get("stations", []):
        _add_station(str(sid))
    for cid in spec.get("counters", []):
        _add_counter(str(cid))
    if bool(spec.get("expandShop", false)):
        for id in price_pads:
            (price_pads[id] as PricePad).expand()


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
func station_destroyed(s: Station, _by: Node3D) -> void:
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
func tower_destroyed(t: Tower, _by: Node3D) -> void:
    var pad := tower_pad_for(t.id)
    if pad != null:
        pad.on_lost()
        EventBus.notice.emit(tr("NOTICE_TOWER_DESTROYED") % pad.logic.current_cost())
    _refresh_tower_pads()
    save_now()


## 這座塔的熊王牙強化牌(tooth_<塔 id>)
func tooth_pad_for(tower_id: String) -> PricePad:
    return price_pads.get("tooth_%s" % tower_id, null) as PricePad


## 熊王牙牌只在塔完好、還沒強化時出現
func _refresh_tower_pads() -> void:
    for t in towers:
        var pad := tooth_pad_for(t.id)
        if pad != null:
            pad.set_open(t.is_alive() and not t.is_strong())


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


func drop_loot(kind: String, pos: Vector3) -> Loot:
    var l := Loot.new()
    l.kind = kind
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
    GameState.lose_helper(h.role)
    var pad := hire_pad_for(h.role)
    if pad != null:
        pad.on_lost()
    h.be_eaten()
    EventBus.helper_eaten.emit(h.role, h)
    if bears != null:
        bears.on_helper_eaten(bear)   # 整群吃滿 packMaxEats 個就撤退
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
        if not s.is_broken() and s.logic.input_id == item and s.logic.input_space() > best_space:
            best = s
            best_space = s.logic.input_space()
    return best


func find_station_with_input(item: String) -> Station:
    for s in stations:
        if not s.is_broken() and s.logic.input_id == item:
            return s
    return null


## 產 item 且輸出堆還有空位的工作站(搬運工把送不出去的貨放回去用)
func find_station_with_output(item: String) -> Station:
    for s in stations:
        if not s.is_broken() and s.logic.output_id == item and s.logic.output_count < s.logic.output_cap:
            return s
    return null


## 給 PorterPlanner 的目的地清單:櫃台(賣什麼)+ 工作站原料(吃什麼、產什麼),帶 node 方便對回去;被拆的工作站不算
func porter_dests() -> Array:
    var out := []
    for c in counters:
        out.append({"id": c.get_instance_id(), "node": c, "kind": "counter", "item": c.logic.item_id, "stock": c.logic.stock, "cap": c.logic.stock_cap})
    for s in stations:
        if s.is_broken():
            continue
        out.append({"id": s.get_instance_id(), "node": s, "kind": "station", "item": s.logic.input_id, "stock": s.logic.input_count,
                "cap": s.logic.input_cap, "out": s.logic.output_id})
    return out


## 給 PorterPlanner 的來源清單:工作站輸出堆
func porter_sources() -> Array:
    var out := []
    for s in stations:
        if s.is_broken():
            continue
        out.append({"id": s.get_instance_id(), "node": s, "item": s.logic.output_id, "count": s.logic.output_count})
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


## --- 存檔 ---

## 世界狀態(GameState 之外的):玩家背上、錢格、各工作站堆 / 是否被拆、各櫃台庫存、各價格牌進度(含修復牌)、守衛塔狀態 / 血量 / 強化、地上的掉落物、北極熊冷卻
func snapshot() -> Dictionary:
    var stations_d := {}
    for s in stations:
        stations_d[s.spot_id] = {"input": s.logic.input_count, "output": s.logic.output_count, "broken": s.is_broken()}
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
    return {
        "player": {"item": player.stack.item_id, "count": player.stack.count},
        "money": money_pad.cash, "stations": stations_d, "counters": counters_d, "pads": pads_d, "towers": towers_d,
        "loot": loot_d, "bear": bears.snapshot() if bears != null else {},
    }


func restore_world(d: Dictionary) -> void:
    var pl = d.get("player", {})
    if typeof(pl) == TYPE_DICTIONARY:
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
                drop_loot(str(e["kind"]), Vector3(float(e.get("x", 0.0)), 0.0, float(e.get("z", 0.0))))
    _refresh_tower_pads()
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
    for role in GameState.hired:
        for i in GameState.hired_count(str(role)):
            spawn_helper(str(role), true)
    var world_d = data.get("world", {})
    if typeof(world_d) == TYPE_DICTIONARY:
        restore_world(world_d)
    loaded_from_save = true


func _physics_process(delta: float) -> void:
    GameState.play_time += delta
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


## F9:刪存檔、清狀態、重載場景
func new_game() -> void:
    clear_save_and_state()
    get_tree().reload_current_scene()
