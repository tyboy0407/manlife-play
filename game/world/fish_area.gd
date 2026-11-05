class_name FishArea
extends Node3D
## 淺水區:rect(世界 XZ)範圍的水面 + Area3D;定期生魚到上限,魚在範圍內漫游。
## 站在水裡、能抓魚、背包裝得下魚的 Carrier,離魚夠近(catch_radius)就自動捕獲(每幀每人一條)。
## 最近的一條會發黃光當作「要被抓到」的提示。
## 稀有魚(金魚,RareFishLogic):每 intervalSec 偶爾生一條(不算在 fish 裡,漁夫 / 王 / 提示都不理它),lifetimeSec 沒抓到就游走;
## 只有玩家(collects_cash)靠到 catchRadius 內站滿 catchSec 才抓到(頭上進度環),走開歸零;抓到進 GameState 的稀有魚資源。

var rect := Rect2(-8, -11, 16, 7)
var max_fish := 12
var spawn_interval := 0.8
var catch_radius := 1.1
var swim_speed := 1.6
var fish: Array[Fish] = []
var area: Area3D
var catchable := true

const BASE_WATER_AREA := 112.0   # 主村水面 16 × 7,maxInWater 以它為準
static var rare_auto := true     # 金魚自動出現(測試關掉,改用 spawn_rare 強制)

var _spawn_timer := 0.0
var rare_logic: RareFishLogic
var rare: Fish = null          # 水裡的金魚(最多一條)
var rare_caught_total := 0
var _rare_timer := 0.0
var _rare_life := 0.0
var _rare_progress := 0.0
var _rare_ring: ProgressRing = null


func _ready() -> void:
    add_to_group("fish_area")
    var cfg := GameData.section("fish")
    # maxInWater 是主村水面(BASE_WATER_AREA)的數量,其他水區按面積等比(擴建區 11 × 7 -> 12 條),密度一樣
    max_fish = maxi(int(round(float(cfg.get("maxInWater", max_fish)) * rect.get_area() / BASE_WATER_AREA)), 1)
    spawn_interval = maxf(float(cfg.get("spawnIntervalSec", spawn_interval)), 0.05)
    catch_radius = float(cfg.get("catchRadius", catch_radius))
    swim_speed = float(cfg.get("swimSpeed", swim_speed))
    var center := Vector3(rect.get_center().x, 0.0, rect.get_center().y)
    var water := VisualFactory.box(Vector3(rect.size.x, 0.12, rect.size.y), Color(0.35, 0.65, 0.95, 0.85), center + Vector3(0, -0.05, 0))
    water.material_override = VisualFactory.material(Color(0.35, 0.65, 0.95, 0.85), Color.BLACK, true)
    add_child(water)
    area = Area3D.new()
    area.monitoring = true
    area.monitorable = false
    area.collision_layer = 0
    area.collision_mask = 1 << (Carrier.CARRIER_LAYER - 1)
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(rect.size.x, 2.0, rect.size.y)
    shape.shape = box
    shape.position = center + Vector3(0, 1.0, 0)
    area.add_child(shape)
    add_child(area)
    for i in int(max_fish / 2.0):
        _spawn_fish()
    rare_logic = RareFishLogic.from_config(GameData.section("rareFish"))
    _rare_timer = rare_logic.next_interval(randf())


func random_point() -> Vector3:
    return Vector3(randf_range(rect.position.x + 0.5, rect.end.x - 0.5), 0.0, randf_range(rect.position.y + 0.5, rect.end.y - 0.5))


func _spawn_fish() -> Fish:
    var f := Fish.new()
    f.rect = rect
    f.swim_speed = swim_speed
    f.position = random_point()
    f.rotation.y = randf() * TAU
    add_child(f)
    fish.append(f)
    return f


func _physics_process(delta: float) -> void:
    _spawn_timer -= delta
    if _spawn_timer <= 0.0 and fish.size() < max_fish:
        _spawn_fish()
        _spawn_timer = spawn_interval
    _tick_rare(delta)
    if not catchable:
        return
    for b in area.get_overlapping_bodies():
        var c := b as Carrier
        if c == null or not c.can_fish or not c.stack.can_push("fish"):
            continue
        var nearest := _nearest_fish(c.global_position)
        if nearest == null:
            continue
        var dist := Vector2(nearest.global_position.x - c.global_position.x, nearest.global_position.z - c.global_position.z).length()
        if dist <= catch_radius:
            _catch(c, nearest)
        else:
            nearest.set_highlight(dist <= catch_radius * 2.5)


func _nearest_fish(pos: Vector3) -> Fish:
    var best: Fish = null
    var best_d := 1e9
    for f in fish:
        if not is_instance_valid(f):
            continue
        var d := Vector2(f.global_position.x - pos.x, f.global_position.z - pos.z).length()
        if d < best_d:
            best_d = d
            best = f
    return best


func _catch(c: Carrier, f: Fish) -> void:
    if not c.stack.push("fish"):
        return
    c.caught_total += 1
    fish.erase(f)
    var from := f.global_position
    f.queue_free()
    EventBus.fish_caught.emit(c)
    EventBus.items_moved.emit("catch", "fish", from, c.stack_top(), 1)


## 把一條魚拿掉(北極熊王吃掉)
func remove_fish(f: Fish) -> void:
    fish.erase(f)
    if is_instance_valid(f):
        f.queue_free()


## 位置(世界 XZ)在不在水裡
func contains(pos: Vector3) -> bool:
    return rect.has_point(Vector2(pos.x, pos.z))


## 離 pos 最近的魚(沒有回 null);引導箭頭用
func nearest_fish_to(pos: Vector3) -> Fish:
    return _nearest_fish(pos)


## --- 稀有魚 ---

## 生一條金魚(測試 / 關卡可強制叫);已經有就回它
func spawn_rare() -> Fish:
    if rare != null and is_instance_valid(rare):
        return rare
    var f := Fish.new()
    f.rare = true
    f.rect = rect
    f.swim_speed = swim_speed * rare_logic.speed_mult()
    f.position = random_point()
    f.rotation.y = randf() * TAU
    add_child(f)
    rare = f
    _rare_life = rare_logic.lifetime()
    _rare_progress = 0.0
    if _rare_ring == null:
        _rare_ring = ProgressRing.new()
        _rare_ring.inner = 0.5
        _rare_ring.outer = 0.68
        _rare_ring.color = Color(1.0, 0.8, 0.2)
        add_child(_rare_ring)
    _rare_ring.visible = false
    EventBus.rare_fish_spawned.emit(f)
    EventBus.notice.emit(tr("NOTICE_RARE_FISH"))
    return f


func has_rare() -> bool:
    return rare != null and is_instance_valid(rare)


func rare_progress() -> float:
    return _rare_progress


func _tick_rare(delta: float) -> void:
    if not has_rare():
        rare = null
        if _rare_ring != null:
            _rare_ring.visible = false
        _rare_timer -= delta
        if _rare_timer <= 0.0:
            _rare_timer = rare_logic.next_interval(randf())
            if catchable and rare_auto:
                spawn_rare()
        return
    _rare_life -= delta
    if _rare_life <= 0.0:
        _despawn_rare()
        return
    var in_range := false
    var who: Carrier = null
    if catchable:
        for b in area.get_overlapping_bodies():
            var c := b as Carrier
            if c == null or not c.collects_cash:
                continue   # 只有玩家抓得到金魚
            var d := Vector2(rare.global_position.x - c.global_position.x, rare.global_position.z - c.global_position.z).length()
            if d <= rare_logic.catch_radius():
                in_range = true
                who = c
                break
    _rare_progress = rare_logic.tick_catch(_rare_progress, delta, in_range)
    if _rare_ring != null:
        _rare_ring.visible = _rare_progress > 0.0
        _rare_ring.global_position = rare.global_position + Vector3(0, 0.3, 0)
        _rare_ring.set_progress(_rare_progress / rare_logic.catch_sec())
    if rare_logic.is_caught(_rare_progress):
        _catch_rare(who)


func _despawn_rare() -> void:
    if has_rare():
        rare.queue_free()
    rare = null
    _rare_progress = 0.0
    if _rare_ring != null:
        _rare_ring.visible = false
    _rare_timer = rare_logic.next_interval(randf())


func _catch_rare(c: Carrier) -> void:
    var from := rare.global_position
    rare_caught_total += 1
    var total := GameState.add_resource(RareFishLogic.ITEM, 1)
    _despawn_rare()
    var to := from + Vector3(0, 1.5, 0)
    if c != null and is_instance_valid(c):
        to = c.stack_top()
    EventBus.items_moved.emit("loot", RareFishLogic.ITEM, from + Vector3(0, 0.3, 0), to, 1)
    EventBus.rare_fish_caught.emit(total)
    EventBus.notice.emit(tr("NOTICE_RARE_CAUGHT") % total)
