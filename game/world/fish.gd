class_name Fish
extends Node3D
## 魚:在 rect(世界 XZ)裡漫游,被 FishArea 抓走就消失。純外觀 + 位置,沒有物理。

var rect := Rect2(-5, -5, 10, 10)
var swim_speed := 1.6
var target := Vector3.ZERO
var highlighted := false

var _retarget := 0.0
var _bob := 0.0
var _hl_timer := 0.0
var _body: MeshInstance3D


func _ready() -> void:
    add_to_group("fish")
    _body = VisualFactory.box(GameData.item_size("fish"), GameData.item_color("fish"), Vector3(0, 0.12, 0))
    add_child(_body)
    add_child(VisualFactory.box(Vector3(0.12, 0.25, 0.22), GameData.item_color("fish").darkened(0.2), Vector3(0, 0.12, -0.42)))
    _bob = randf() * TAU
    _pick_target()


func random_point() -> Vector3:
    return Vector3(randf_range(rect.position.x, rect.end.x), 0.0, randf_range(rect.position.y, rect.end.y))


func _pick_target() -> void:
    target = random_point()
    _retarget = randf_range(1.0, 3.0)


## 亮起 0.25 秒(每幀被 FishArea 重新點亮就持續),沒人靠近自動熄
func set_highlight(on: bool) -> void:
    if on:
        _hl_timer = 0.25
    if on == highlighted:
        return
    highlighted = on
    _body.material_override = VisualFactory.material(GameData.item_color("fish"),
            Color(0.9, 0.85, 0.2) if on else Color.BLACK)


func _physics_process(delta: float) -> void:
    _retarget -= delta
    _bob += delta
    if highlighted:
        _hl_timer -= delta
        if _hl_timer <= 0.0:
            set_highlight(false)
    var d := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
    if _retarget <= 0.0 or d.length() < 0.3:
        _pick_target()
        return
    global_position += d.normalized() * minf(swim_speed * delta, d.length())
    global_position.y = sin(_bob * 2.0) * 0.04
    rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), minf(1.0, 6.0 * delta))
