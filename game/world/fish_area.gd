class_name FishArea
extends Node3D
## 淺水區:rect(世界 XZ)範圍的水面 + Area3D;定期生魚到上限,魚在範圍內漫游。
## 站在水裡、能抓魚、背包裝得下魚的 Carrier,離魚夠近(catch_radius)就自動捕獲(每幀每人一條)。
## 最近的一條會發黃光當作「要被抓到」的提示。

var rect := Rect2(-8, -11, 16, 7)
var max_fish := 12
var spawn_interval := 0.8
var catch_radius := 1.1
var swim_speed := 1.6
var fish: Array[Fish] = []
var area: Area3D
var catchable := true

var _spawn_timer := 0.0


func _ready() -> void:
    add_to_group("fish_area")
    var cfg := GameData.section("fish")
    max_fish = int(cfg.get("maxInWater", max_fish))
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


## 位置(世界 XZ)在不在水裡
func contains(pos: Vector3) -> bool:
    return rect.has_point(Vector2(pos.x, pos.z))


## 離 pos 最近的魚(沒有回 null);引導箭頭用
func nearest_fish_to(pos: Vector3) -> Fish:
    return _nearest_fish(pos)
