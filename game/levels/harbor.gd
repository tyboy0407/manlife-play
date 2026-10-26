class_name Harbor
extends Node3D
## 星港漁市原型關卡:雪地 + 沙灘 + 淺水區(抓魚)+ 魚欄裝飾、工作站、櫃台與排隊顧客、錢格、垃圾桶、價格牌(shop.json),
## 玩家、跟隨相機、HUD。全部用程式碼擺放(座標在這裡,規則與數值在 data/)。
## 世界座標:x 右、-z 螢幕上(水在上面)、+z 螢幕下(顧客從右邊來)。價格牌一排在 z = 5、間距 4(牌寬 2),中間留 2 格寬的走道,
## 帶著現金穿過走道才不會順手付進別的牌。
## 解鎖:unlock 效果的 target 查 UNLOCKS 生工作站 / 櫃台;僱用生 Helper。存檔:GameState + snapshot(),自動存、關閉存、F9 重來。

const STATION_SPOTS := {"station_1": Vector3(-6.0, 0, 0), "station_2": Vector3(0.0, 0, 0), "grill": Vector3(6.0, 0, 0)}
const STATION_DEFS := {"station_1": "cutting_table", "station_2": "cutting_table", "grill": "grill"}
const COUNTER_SPOTS := {"fillet_counter": Vector3(-9.0, 0, 8.5), "grill_counter": Vector3(3.0, 0, 8.5)}
const PAD_SPOTS := {
    "hire_fisher": Vector3(-10.0, 0, 5.0), "hire_porter": Vector3(-6.0, 0, 5.0), "hire_cashier": Vector3(-2.0, 0, 5.0),
    "capacity_1": Vector3(2.0, 0, 5.0), "upgrade_worker_speed": Vector3(6.0, 0, 5.0), "upgrade_pile_cap": Vector3(10.0, 0, 5.0),
    "expand_table": Vector3(0.0, 0, 0), "unlock_grill": Vector3(6.0, 0, 0),
}
const UNLOCKS := {
    "station_2": {"stations": ["station_2"], "counters": []},
    "grill_complex": {"stations": ["grill"], "counters": ["grill_counter"]},
}
const MONEY_SPOT := Vector3(-4.0, 0, 10.7)
const TRASH_SPOT := Vector3(9.0, 0, 10.7)
const HELPER_SPAWN := Vector3(0.0, 0, -3.0)
const PLAYER_SPAWN := Vector3(0.0, 0, 7.0)
const HUD_SCRIPT := preload("res://game/ui/hud.gd")

var player: Player
var fish_area: FishArea
var stations: Array[Station] = []
var counters: Array[Counter] = []
var money_pad: MoneyPad
var trash_pad: TrashPad
var price_pads := {}
var helpers: Array[Helper] = []
var camera: FollowCamera
var hud: CanvasLayer
var guide: Guide
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
    _build_terrain()
    fish_area = FishArea.new()
    fish_area.name = "FishArea"
    fish_area.rect = Rect2(-8.0, -11.0, 16.0, 7.0)
    world.add_child(fish_area)
    _build_pen_decoration()
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
    player = Player.new()
    player.name = "Player"
    player.position = PLAYER_SPAWN
    add_child(player)
    camera = FollowCamera.new()
    camera.name = "Camera"
    camera.target = player
    add_child(camera)
    hud = HUD_SCRIPT.new()
    hud.name = "Hud"
    hud.bind_player(player)
    add_child(hud)
    autosave_sec = maxf(float(GameData.config().get("autosaveSec", 10.0)), 1.0)
    _autosave_timer = autosave_sec
    _load_save()
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
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-52, -28, 0)
    light.light_energy = 1.1
    light.shadow_enabled = true
    add_child(light)


func _build_terrain() -> void:
    world.add_child(VisualFactory.box(Vector3(70, 0.2, 80), Color(0.93, 0.95, 0.98), Vector3(0, -0.12, -3)))
    world.add_child(VisualFactory.box(Vector3(25, 0.06, 16.5), Color(0.88, 0.76, 0.6), Vector3(0, -0.02, 4.0)))
    _wall(Vector3(-12.6, 1, 0), Vector3(0.4, 2, 26))
    _wall(Vector3(12.6, 1, 0), Vector3(0.4, 2, 26))
    _wall(Vector3(0, 1, 12.6), Vector3(26, 2, 0.4))
    _wall(Vector3(0, 1, -11.2), Vector3(26, 2, 0.4))
    for x in [-12.4, 12.4]:
        world.add_child(VisualFactory.box(Vector3(0.25, 0.9, 16.5), Color(0.8, 0.62, 0.42), Vector3(x, 0.45, 4.0)))
    world.add_child(VisualFactory.box(Vector3(25, 0.9, 0.25), Color(0.8, 0.62, 0.42), Vector3(0, 0.45, 12.4)))
    for p in [Vector3(-16, 0, 2), Vector3(-15, 0, 9), Vector3(16, 0, -2), Vector3(15.5, 0, 9), Vector3(-17, 0, -6), Vector3(17, 0, -9)]:
        world.add_child(VisualFactory.cylinder(0.2, 1.0, Color(0.45, 0.3, 0.2), p + Vector3(0, 0.5, 0)))
        world.add_child(VisualFactory.box(Vector3(1.6, 1.6, 1.6), Color(0.86, 0.92, 0.96), p + Vector3(0, 1.6, 0)))
        world.add_child(VisualFactory.box(Vector3(1.0, 1.2, 1.0), Color(0.86, 0.92, 0.96), p + Vector3(0, 2.8, 0)))


func _wall(pos: Vector3, size: Vector3) -> void:
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


## 魚欄裝飾:北邊的深水池 + 柵欄 + 閘門 + 幾條裝飾魚(抓不到)
func _build_pen_decoration() -> void:
    world.add_child(VisualFactory.box(Vector3(16, 0.12, 5), Color(0.2, 0.45, 0.85), Vector3(0, -0.04, -14.0)))
    for i in 17:
        var x := -8.0 + float(i)
        if absf(x) <= 1.5:
            continue
        world.add_child(VisualFactory.cylinder(0.14, 1.1, Color(0.82, 0.62, 0.4), Vector3(x, 0.55, -11.5)))
    world.add_child(VisualFactory.box(Vector3(3.2, 1.0, 0.3), Color(0.9, 0.6, 0.3), Vector3(0, 0.5, -11.5)))
    world.add_child(VisualFactory.box(Vector3(16, 0.3, 0.3), Color(0.82, 0.62, 0.4), Vector3(0, 0.95, -11.5)))
    for i in 14:
        var f := Fish.new()
        f.rect = Rect2(-7.5, -16.0, 15.0, 4.0)
        f.position = f.random_point()
        world.add_child(f)


## --- 建築 ---

func _add_station(spot_id: String) -> Station:
    var def := GameData.station(str(STATION_DEFS.get(spot_id, "cutting_table")))
    var s := Station.create(def)
    s.spot_id = spot_id
    s.name = "Station_%s" % spot_id
    s.position = STATION_SPOTS.get(spot_id, Vector3.ZERO)
    world.add_child(s)
    stations.append(s)
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
    for sid in spec.get("stations", []):
        _add_station(str(sid))
    for cid in spec.get("counters", []):
        _add_counter(str(cid))


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
        if s.logic.input_id == item and s.logic.input_space() > best_space:
            best = s
            best_space = s.logic.input_space()
    return best


func find_station_with_input(item: String) -> Station:
    for s in stations:
        if s.logic.input_id == item:
            return s
    return null


## 產 item 且輸出堆還有空位的工作站(搬運工把送不出去的貨放回去用)
func find_station_with_output(item: String) -> Station:
    for s in stations:
        if s.logic.output_id == item and s.logic.output_count < s.logic.output_cap:
            return s
    return null


## 給 PorterPlanner 的目的地清單:櫃台(賣什麼)+ 工作站原料(吃什麼、產什麼),帶 node 方便對回去
func porter_dests() -> Array:
    var out := []
    for c in counters:
        out.append({"id": c.get_instance_id(), "node": c, "kind": "counter", "item": c.logic.item_id, "stock": c.logic.stock, "cap": c.logic.stock_cap})
    for s in stations:
        out.append({"id": s.get_instance_id(), "node": s, "kind": "station", "item": s.logic.input_id, "stock": s.logic.input_count,
                "cap": s.logic.input_cap, "out": s.logic.output_id})
    return out


## 給 PorterPlanner 的來源清單:工作站輸出堆
func porter_sources() -> Array:
    var out := []
    for s in stations:
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


## --- 存檔 ---

## 世界狀態(GameState 之外的):玩家背上、錢格、各工作站堆、各櫃台庫存、各價格牌進度
func snapshot() -> Dictionary:
    var stations_d := {}
    for s in stations:
        stations_d[s.spot_id] = {"input": s.logic.input_count, "output": s.logic.output_count}
    var counters_d := {}
    for c in counters:
        counters_d[c.def_id] = {"stock": c.logic.stock}
    var pads_d := {}
    for id in price_pads:
        var p: PricePad = price_pads[id]
        pads_d[str(id)] = {"remaining": p.logic.remaining, "buys": p.logic.buys}
    return {
        "player": {"item": player.stack.item_id, "count": player.stack.count},
        "money": money_pad.cash, "stations": stations_d, "counters": counters_d, "pads": pads_d,
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
                (price_pads[str(id)] as PricePad).restore_state(int(pads[id].get("buys", 0)), int(pads[id].get("remaining", 0)))


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
    for target in UNLOCKS:
        if GameState.is_unlocked(str(target)):
            _spawn_unlock(str(target))
    for role in GameState.hired:
        for i in GameState.hired_count(str(role)):
            spawn_helper(str(role), true)
    var world_d = data.get("world", {})
    if typeof(world_d) == TYPE_DICTIONARY:
        restore_world(world_d)
    loaded_from_save = true


func _physics_process(delta: float) -> void:
    _autosave_timer -= delta
    if _autosave_timer <= 0.0:
        _autosave_timer = autosave_sec
        save_now()


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        save_now()


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
