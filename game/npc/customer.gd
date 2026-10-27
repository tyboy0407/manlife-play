class_name Customer
extends Node3D
## 顧客:走到排隊位、等待;輪到自己且櫃台有貨就買走,然後走向出口消失。頭上泡泡顯示需求。沒有物理(互相穿過)。
## 外觀:有人物模型就輪流用 models.customers 裡的人物(走路 / 待機動畫,買到時原地比個 emote-yes 再走),沒有就膠囊占位。

const THANKS_SEC := 0.6   # 買到後原地道謝多久再走

static var _next_model := 0   # 輪流用不同的顧客模型

var speed := 3.5
var want := 1
var item_name := ""   # 泡泡上顯示要買什麼(由櫃台在 add_child 前設定)
var target := Vector3.ZERO
var arrived := false
var leaving := false
var served := false
var model: CharacterModel = null

var _bubble: Label3D
var _bob := 0.0
var _thanks := 0.0


func _ready() -> void:
    add_to_group("customer")
    speed = float(GameData.section("customers").get("speed", 3.5))
    var top := 1.75
    var models := ModelLibrary.customer_models()
    var scene: PackedScene = null
    if not models.is_empty():
        scene = ModelLibrary.character(str(models[_next_model % models.size()]))
        _next_model += 1
    if scene != null:
        model = CharacterModel.create(scene, ModelLibrary.customer_height())
        add_child(model)
        top = model.height
    else:
        add_child(VisualFactory.capsule(0.35, 1.4, Color(0.95, 0.75, 0.2), Vector3(0, 0.8, 0)))
        add_child(VisualFactory.box(Vector3(0.5, 0.25, 0.5), Color(0.15, 0.12, 0.1), Vector3(0, 1.6, 0)))
    add_child(VisualFactory.blob_shadow(0.42, Settings.is_smooth()))
    _bubble = VisualFactory.label(tr("CUSTOMER_WANT") % [item_name, want], Vector3(0, top + 0.6, 0), 40, Color(1.0, 0.9, 0.7))
    add_child(_bubble)


func set_target(p: Vector3) -> void:
    target = p
    arrived = planar_distance(p) < 0.15


## 買到了:泡泡換成道謝、原地比個手勢,半秒後收起泡泡並走向出口
func leave(exit_point: Vector3) -> void:
    leaving = true
    served = true
    _thanks = THANKS_SEC
    if model != null:
        model.set_action("emote-yes", false)
    _bubble.text = tr("CUSTOMER_THANKS")
    _bubble.modulate = Color(0.7, 1.0, 0.7)
    set_target(exit_point)


func planar_distance(p: Vector3) -> float:
    return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _physics_process(delta: float) -> void:
    _bob += delta
    if _thanks > 0.0:
        _thanks -= delta
        _animate(0.0)
        if _thanks <= 0.0:
            _bubble.visible = false   # 道謝完收起泡泡、開始走(不用計時器,關卡換場景時不會留下懸空的回呼)
        return
    var d := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
    if d.length() < 0.15:
        arrived = true
        _animate(0.0)
        if leaving:
            queue_free()
        return
    arrived = false
    var step := minf(speed * delta, d.length())
    global_position += d.normalized() * step
    rotation.y = atan2(d.x, d.z)
    _animate(1.0)


func _animate(ratio: float) -> void:
    if model != null:
        model.set_moving(ratio)
