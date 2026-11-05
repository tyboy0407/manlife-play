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


## 線段 a -> b(XZ)有沒有穿過矩形:每 0.2 取樣一點
static func _segment_hits(r: Rect2, a: Vector3, b: Vector3) -> bool:
    var n := maxi(int(ceil(a.distance_to(b) / 0.2)), 1)
    for i in n + 1:
        var p := a.lerp(b, float(i) / float(n))
        if r.has_point(Vector2(p.x, p.z)):
            return true
    return false


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
            ["expand_village_2", "village_3"], ["expand_village_3", "village_4"], ["expand_village_4", "village_5"]]:
        GameState.apply_purchase(str(u[0]), {"type": "unlock", "target": str(u[1])})
        await _step(2)
    await _step(3)
    _check(_level.expansion_level() == 4 and _level.stations.size() == 13 and _level.counters.size() == 8 and _level.towers.size() == 26 and _level.has_south_block()
            and _level.south_walls.is_empty(),
            "關卡擴建四次(含南塊):十三座工作站、八座櫃台、二十六座塔、主村南牆拆了(擴建 %d 次、%d 站、%d 櫃台、%d 塔)" % [_level.expansion_level(), _level.stations.size(), _level.counters.size(), _level.towers.size()])
    var kitchen := _level.station_at("kitchen")
    _check(kitchen != null and kitchen.input_pads.size() == 2 and kitchen.input_pad_for("grilled") != kitchen.input_pad_for("fillet")
            and kitchen.input_pad_for("fillet").global_position.x < kitchen.input_pad_for("grilled").global_position.x,
            "廚房有兩個輸入格(魚片在左、烤魚在右)")
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
    # 傳送帶路線(輸出格 -> 上架格)不經過守衛塔;架高 belt_h 要高過牌子標籤頂(1.85)才准從牌子上方經過(主村的牌子排在 z 5,帶子一定跨過)
    var belt_h := float(GameData.section("conveyor").get("height", 0.0))
    _check(belt_h >= 2.05, "傳送帶架高 %.1f:高過人物(1.5)與牌子標籤(1.85)" % belt_h)
    var crossed := 0
    for id in Harbor.CONVEYORS:
        var spec: Dictionary = Harbor.CONVEYORS[id]
        var st := _level.station_at(str(spec["from"]))
        var ct := _level.counter_by_id(str(spec["to"]))
        if st == null or ct == null:
            continue
        var a := st.output_pad.global_position
        var b := ct.deposit_pad.global_position
        for f in fps:
            var fid := str(f["id"])
            if not (fid.begins_with("pad:") and not fid.contains("/")) and not fid.begins_with("tower:"):
                continue
            if fid.begins_with("pad:") and belt_h >= 2.05:
                continue
            if _segment_hits(f["rect"], a, b):
                crossed += 1
                print("    belt %s crosses %s" % [id, fid])
    _check(crossed == 0, "傳送帶不穿過守衛塔(%d 條)" % crossed)
    # 顧客門:每塊地的櫃台都從自己那塊地的東柵欄外進來、走回同一點;門在顧客那排、柵欄外 1.5 格(南塊的櫃台用南塊東柵欄的門)
    var door_bad := 0
    for c in _level.counters:
        var d := c.spawn_point()
        var ok := d == c.exit_point() and d.x > c.global_position.x
        if c.global_position.z > 12.6:
            ok = ok and is_equal_approx(d.x, Harbor.SOUTH_RECT.end.x + 1.5) and absf(d.z - 28.5) < 0.01
        else:
            var area := Harbor.area_of_x(c.global_position.x)
            var fence_x := 12.6 if area == 0 else (Harbor.ANNEX_RECTS[area - 1] as Rect2).end.x
            ok = ok and is_equal_approx(d.x, fence_x + 1.5) and absf(d.z - 10.2) < 0.01
        if not ok:
            door_bad += 1
            print("    door: %s -> %s" % [c.def_id, str(d)])
    _check(door_bad == 0, "八座櫃台的顧客都從自己那塊地的門外出生與離開(南塊用南塊東柵欄的門)")
    # 探險:空氣牆圍住 EXPLORE_RECT 四邊;西 / 東 / 南三個缺口沒有牆;村裡 / 村外判斷
    var r := Harbor.EXPLORE_RECT
    var bounds := 0
    for f in fps:
        if not str(f["id"]).begins_with("wall:"):
            continue
        var wr: Rect2 = f["rect"]
        if absf(wr.get_center().x - r.position.x) < 0.3 and wr.size.y > r.size.y - 1.0:
            bounds += 1
        if absf(wr.get_center().x - r.end.x) < 0.3 and wr.size.y > r.size.y - 1.0:
            bounds += 1
        if absf(wr.get_center().y - r.position.y) < 0.3 and wr.size.x > r.size.x - 1.0:
            bounds += 1
        if absf(wr.get_center().y - r.end.y) < 0.3 and wr.size.x > r.size.x - 1.0:
            bounds += 1
    _check(bounds == 4, "探險範圍四面空氣牆都在(%d)" % bounds)
    var exits := [Vector2(-23.4, 2.0), Vector2((Harbor.ANNEX_RECTS[2] as Rect2).end.x, 0.5), Vector2(0.0, Harbor.SOUTH_RECT.end.y)]
    var blocked := 0
    for e in exits:
        for f in fps:
            if str(f["id"]).begins_with("wall:") and (f["rect"] as Rect2).grow(0.35).has_point(e):
                blocked += 1
                print("    exit blocked: %s by %s" % [str(e), str(f["rect"])])
    _check(blocked == 0, "西 / 東 / 南三個探險缺口都沒有牆擋著")
    _check(_level.is_inside_village(Vector3(0, 0, 0)) and _level.is_inside_village(Vector3(-18, 0, 2)) and _level.is_inside_village(Vector3(60, 0, 5))
            and _level.is_inside_village(Vector3(0, 0, 25)) and not _level.is_inside_village(Vector3(-30, 0, 2)) and not _level.is_inside_village(Vector3(0, 0, 40))
            and _level.home_point(Vector3(-30, 0, 2)).x < -23.4 and _level.home_point(Vector3(0, 0, 45)).z > Harbor.SOUTH_RECT.end.y,
            "村裡 / 村外判斷與最近的回村入口")
    _check(Harbor.customer_door(0) == Vector3(14.1, 0, 10.2) and Harbor.customer_door(3) == Vector3(70.3, 0, 10.2)
            and Harbor.area_of_x(12.0) == 0 and Harbor.area_of_x(13.0) == 1 and Harbor.area_of_x(60.0) == 3, "顧客門座標與分區")
    # 魚群上限按水面面積:主村 16 × 7 = 18 條,擴建區 11 × 7 = 12 條
    _check(_level.fish_areas.size() == 4 and _level.fish_areas[0].max_fish == 18 and _level.fish_areas[1].max_fish == 12 and _level.fish_areas[3].max_fish == 12,
            "魚群上限按面積:主村 %d、擴建區 %d" % [_level.fish_areas[0].max_fish, _level.fish_areas[1].max_fish])
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
