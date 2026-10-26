class_name Customer
extends Node3D
## 顧客:走到排隊位、等待;輪到自己且櫃台有貨就買走,然後走向出口消失。頭上泡泡顯示需求。沒有物理(互相穿過)。

var speed := 3.5
var want := 1
var item_name := ""   # 泡泡上顯示要買什麼(由櫃台在 add_child 前設定)
var target := Vector3.ZERO
var arrived := false
var leaving := false
var served := false

var _bubble: Label3D
var _bob := 0.0


func _ready() -> void:
    add_to_group("customer")
    speed = float(GameData.section("customers").get("speed", 3.5))
    add_child(VisualFactory.capsule(0.35, 1.4, Color(0.95, 0.75, 0.2), Vector3(0, 0.8, 0)))
    add_child(VisualFactory.box(Vector3(0.5, 0.25, 0.5), Color(0.15, 0.12, 0.1), Vector3(0, 1.6, 0)))
    _bubble = VisualFactory.label(tr("CUSTOMER_WANT") % [item_name, want], Vector3(0, 2.3, 0), 40, Color(1.0, 0.9, 0.7))
    add_child(_bubble)


func set_target(p: Vector3) -> void:
    target = p
    arrived = planar_distance(p) < 0.15


## 買到了:泡泡換成道謝、半秒後收起,走向出口
func leave(exit_point: Vector3) -> void:
    leaving = true
    served = true
    _bubble.text = tr("CUSTOMER_THANKS")
    _bubble.modulate = Color(0.7, 1.0, 0.7)
    var bubble := _bubble
    get_tree().create_timer(0.6).timeout.connect(func() -> void:
        if is_instance_valid(bubble):
            bubble.visible = false)
    set_target(exit_point)


func planar_distance(p: Vector3) -> float:
    return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _physics_process(delta: float) -> void:
    _bob += delta
    var d := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
    if d.length() < 0.15:
        arrived = true
        if leaving:
            queue_free()
        return
    arrived = false
    var step := minf(speed * delta, d.length())
    global_position += d.normalized() * step
    rotation.y = atan2(d.x, d.z)
