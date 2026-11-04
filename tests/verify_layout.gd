extends Node3D
## 版面重疊 headless 驗證:把關卡擴建三次後,蒐集每個會占地的東西(格子、工作站桌子、櫃台本體與排隊位、守衛塔、捕熊夾、誘餌、水區、牆)
## 的 XZ 占地矩形,兩兩檢查不能重疊(同一位置「牌子就是地基」的組合除外);顧客排隊位要留在自己那塊地裡(下一塊可能還沒擴建)。
## 跑法:godot --headless --path . res://tests/verify_layout.tscn(先 --import)

const HARBOR := preload("res://game/levels/harbor.tscn")
const CUSTOMER_HALF := 0.3   # 排隊顧客占地半寬

var _fails := 0
var _level: Harbor


func _check(cond: bool, label: String) -> void:
    if cond:
        print("  OK   %s" % label)
    else:
        _fails += 1
        print("  FAIL %s" % label)


func _step(frames: int) -> void:
    for i in frames:
        await get_tree().physics_frame


func _rect(center: Vector3, size_x: float, size_z: float) -> Rect2:
    return Rect2(center.x - size_x / 2.0, center.z - size_z / 2.0, size_x, size_z)


## 兩個矩形真的重疊(只是邊貼邊不算)
static func _overlaps(a: Rect2, b: Rect2) -> bool:
    return a.position.x < b.end.x - 0.001 and b.position.x < a.end.x - 0.001 \
            and a.position.y < b.end.y - 0.001 and b.position.y < a.end.y - 0.001


## 牌子就是地基:牌與它蓋的東西同一位置,允許重疊
static func _allowed(a: Dictionary, b: Dictionary) -> bool:
    var ids := [str(a["id"]), str(b["id"])]
    if ids[0].begins_with("wall:") and ids[1].begins_with("wall:"):
        return true   # 牆角相接
    for k in 2:
        if ids[k].begins_with("counter:") and ids[1 - k].begins_with("pad:Counter_" + ids[k].trim_prefix("counter:") + "/"):
            return true   # 櫃台本體與自己的收銀格貼著
    for pair in [["pad:tower_", "tower:"], ["pad:tooth_tower_", "tower:"], ["pad:tower_", "pad:tooth_tower_"], ["pad:trap_", "trap:"],
            ["pad:bait_", "bait:"], ["pad:unlock_grill", "station:grill"], ["pad:expand_table", "station:station_2"], ["pad:repair_", "station:"],
            ["pad:repair_", "pad:unlock_grill"], ["pad:repair_", "pad:expand_table"]]:
        for k in 2:
            if ids[k].begins_with(pair[0]) and ids[1 - k].begins_with(pair[1]):
                return true
    return false


func _footprints() -> Array:
    var out := []
    for n in _level.world.get_children():
        _collect(n, out)
    return out


func _collect(n: Node, out: Array) -> void:
    if n is Pad:
        var p := n as Pad
        var id := "pad:%s" % ((p as PricePad).logic.id if p is PricePad else p.name)
        if p.get_parent() is Counter or p.get_parent() is Station:
            id = "pad:%s/%s" % [p.get_parent().name, p.name]
        out.append({"id": id, "rect": _rect(p.global_position, p.size.x, p.size.z)})
    elif n is Station:
        var s := n as Station
        out.append({"id": "station:%s" % s.spot_id, "rect": _rect(s.global_position, 2.2, 1.0)})
    elif n is Counter:
        var c := n as Counter
        out.append({"id": "counter:%s" % c.def_id, "rect": _rect(c.global_position, 1.2, 2.8)})
        for i in c.max_customers:
            out.append({"id": "queue:%s/%d" % [c.def_id, i + 1], "rect": _rect(c.slot_position(i), CUSTOMER_HALF * 2.0, CUSTOMER_HALF * 2.0)})
    elif n is Tower:
        out.append({"id": "tower:%s" % (n as Tower).id, "rect": _rect(n.global_position, 1.9, 1.9)})
    elif n is Trap:
        out.append({"id": "trap:%s" % (n as Trap).id, "rect": _rect(n.global_position, 1.8, 1.8)})
    elif n is Bait:
        out.append({"id": "bait:%s" % (n as Bait).id, "rect": _rect(n.global_position, 2.0, 2.0)})
    elif n is FishArea:
        out.append({"id": "water:%s" % n.name, "rect": (n as FishArea).rect})
    elif n is StaticBody3D:
        for c in n.get_children():
            if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
                var sz: Vector3 = ((c as CollisionShape3D).shape as BoxShape3D).size
                out.append({"id": "wall:%s" % n.name, "rect": _rect(c.global_position, sz.x, sz.z)})
        return
    for c in n.get_children():
        if c is Pad or c is Counter or c is Station:
            _collect(c, out)


func _ready() -> void:
    print("VERIFY LAYOUT: begin")
    SaveManager.save_path = "user://_verify_layout_save.json"
    SaveManager.delete()
    GameState.reset()
    Settings.path = "user://_verify_layout_settings.json"
    _level = HARBOR.instantiate()
    add_child(_level)
    await _step(3)
    _level.bears.enabled = false
    _level.player.input_provider = func() -> MoveInput: return MoveInput.new()
    GameState.tutorial_step = GuideLogic.tutorial_steps()
    for u in [["expand_table", "station_2"], ["unlock_grill", "grill_complex"], ["expand_village", "village_2"],
            ["expand_village_2", "village_3"], ["expand_village_3", "village_4"]]:
        GameState.apply_purchase(str(u[0]), {"type": "unlock", "target": str(u[1])})
        await _step(2)
    await _step(3)
    _check(_level.expansion_level() == 3 and _level.stations.size() == 12 and _level.counters.size() == 7 and _level.towers.size() == 24,
            "關卡擴建三次:十二座工作站、七座櫃台、二十四座塔(擴建 %d 次、%d 站、%d 櫃台、%d 塔)" % [_level.expansion_level(), _level.stations.size(), _level.counters.size(), _level.towers.size()])
    var fps := _footprints()
    _check(fps.size() > 150, "蒐集到 %d 個占地" % fps.size())
    var bad := 0
    for i in fps.size():
        for j in range(i + 1, fps.size()):
            var a: Dictionary = fps[i]
            var b: Dictionary = fps[j]
            if _overlaps(a["rect"], b["rect"]) and not _allowed(a, b):
                bad += 1
                print("    overlap: %s %s  <->  %s %s" % [a["id"], str(a["rect"]), b["id"], str(b["rect"])])
    _check(bad == 0, "沒有占地重疊(%d 處)" % bad)
    # 顧客排隊位要留在自己那塊地裡(東邊的下一塊可能還沒擴建,柵欄在 rect.end.x - 0.2)
    var outside := 0
    for c in _level.counters:
        var area := 0
        for k in Harbor.ANNEX_RECTS.size():
            if c.global_position.x >= (Harbor.ANNEX_RECTS[k] as Rect2).position.x:
                area = k + 1
        var limit := 12.6 - 0.4 if area == 0 else (Harbor.ANNEX_RECTS[area - 1] as Rect2).end.x - 0.4
        for i in c.max_customers:
            var x := c.slot_position(i).x + CUSTOMER_HALF
            if x > limit:
                outside += 1
                print("    queue outside: %s slot %d x %.1f > %.1f" % [c.def_id, i + 1, x, limit])
    _check(outside == 0, "排隊位都在自己那塊地的柵欄內(%d 個超出)" % outside)
    _level.queue_free()
    await _step(2)
    if _fails == 0:
        print("VERIFY LAYOUT: ALL OK")
    else:
        print("VERIFY LAYOUT: %d FAILURES" % _fails)
    Sfx.stop_all()
    for i in 30:
        await get_tree().physics_frame
    SaveManager.delete()
    SaveManager.save_path = SaveManager.DEFAULT_PATH
    get_tree().quit(1 if _fails > 0 else 0)
