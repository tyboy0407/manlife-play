class_name Loot
extends Node3D
## 掉落物(北極熊毛皮 pelt / 熊王牙 tooth):熊被打跑時掉在原地,玩家走到 pickupRadius 內就撿起來(進 GameState 的資源計數,不佔背包)。
## 沒有物理;外觀用方塊 / 圓錐占位,上下浮動慢慢轉。存檔記 {kind, x, z}(Harbor.snapshot "loot")。

var kind := "pelt"
var data := {}               # 寶箱(kind chest)的內容(KingLogic.chest 的字典),存檔一起記
var level: Harbor = null
var pickup_radius := 1.3
var _t := 0.0
var _body: Node3D = null


func _ready() -> void:
    add_to_group("loot")
    pickup_radius = maxf(float(GameData.config().get("lootPickupRadius", 1.3)), 0.2)
    _body = Node3D.new()
    _body.name = "Body"
    add_child(_body)
    if kind == "chest":
        var wood := Color(0.55, 0.35, 0.18)
        var trim := Color(1.0, 0.82, 0.2) if str(data.get("grade", "")) == "perfect" else (Color(0.8, 0.82, 0.88) if str(data.get("grade", "")) == "good" else Color(0.45, 0.3, 0.18))
        _body.add_child(VisualFactory.box(Vector3(1.1, 0.6, 0.8), wood, Vector3(0, 0.3, 0)))
        _body.add_child(VisualFactory.box(Vector3(1.16, 0.3, 0.86), wood.darkened(0.2), Vector3(0, 0.75, 0)))
        _body.add_child(VisualFactory.box(Vector3(1.2, 0.08, 0.2), trim, Vector3(0, 0.6, 0)))
        _body.add_child(VisualFactory.box(Vector3(0.2, 0.3, 0.1), trim, Vector3(0, 0.55, 0.42)))
    elif kind == "tooth":
        var ivory := Color(1.0, 0.97, 0.88)
        _body.add_child(VisualFactory.cone(0.22, 0.55, ivory, Vector3(0, 0.3, 0)))
        _body.add_child(VisualFactory.cylinder(0.24, 0.1, Color(1.0, 0.82, 0.2), Vector3(0, 0.05, 0)))
    else:
        var fur := Color(0.95, 0.96, 0.98)
        _body.add_child(VisualFactory.box(Vector3(0.95, 0.05, 0.75), Color(0.75, 0.72, 0.7), Vector3(0, 0.03, 0)))
        _body.add_child(VisualFactory.box(Vector3(0.9, 0.12, 0.7), fur, Vector3(0, 0.11, 0)))
        _body.add_child(VisualFactory.box(Vector3(0.3, 0.14, 0.26), fur.darkened(0.06), Vector3(0.25, 0.12, 0.3)))
    _body.rotation.y = randf() * TAU
    add_child(VisualFactory.blob_shadow(0.45, Settings.is_smooth()))


func _physics_process(delta: float) -> void:
    _t += delta
    _body.position.y = 0.15 + sin(_t * 3.0) * 0.08
    _body.rotation.y += delta * 0.9
    if level == null or level.player == null or not is_instance_valid(level.player):
        return
    var p := level.player.global_position
    if Vector2(p.x - global_position.x, p.z - global_position.z).length() <= pickup_radius:
        collect(level.player)


## 撿起來:資源 +1、飛向玩家、通知;回傳撿到幾個(0 = 已經被撿走)
func collect(by: Node3D) -> int:
    if not is_physics_processing():
        return 0
    set_physics_process(false)
    if kind == "chest":
        if level != null:
            level.chest_opened(self)
        queue_free()
        return 1
    var total := GameState.add_resource(kind, 1)
    var to := global_position + Vector3(0, 1.5, 0)
    if by != null and is_instance_valid(by) and by is Carrier:
        to = (by as Carrier).stack_top()
    EventBus.items_moved.emit("loot", kind, global_position + Vector3(0, 0.3, 0), to, 1)
    EventBus.loot_collected.emit(kind, total)
    if level != null:
        level.loot_collected(self)
    queue_free()
    return 1


func snapshot() -> Dictionary:
    var d := {"kind": kind, "x": global_position.x, "z": global_position.z}
    if not data.is_empty():
        d["data"] = data.duplicate(true)
    return d
