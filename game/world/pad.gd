class_name Pad
extends Area3D
## 地板格基底:Area3D 偵測站在上面的 Carrier(物理層 2),每個物理幀對每個 carrier 呼叫 _on_carrier_stay。
## 搬運速率用每個 carrier 的累加器(每秒 n 件,最多多攢 1 件)。外觀:薄方塊 + 可選的 Label3D 文字。

const CARRIER_LAYER := 2

var size := Vector3(2.0, 1.0, 2.0)
var color := Color(0.32, 0.28, 0.24)
var label_text := ""
var mesh: MeshInstance3D
var label: Label3D = null

var _acc := {}   # carrier instance id -> 累積的搬運量
var _highlight := false


func _ready() -> void:
    add_to_group("pad")
    monitoring = true
    monitorable = false
    collision_layer = 0
    collision_mask = 1 << (CARRIER_LAYER - 1)
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = size
    shape.shape = box
    shape.position = Vector3(0, size.y / 2.0, 0)
    add_child(shape)
    mesh = VisualFactory.box(Vector3(size.x, 0.1, size.z), color, Vector3(0, 0.05, 0))
    add_child(mesh)
    add_child(VisualFactory.box(Vector3(size.x + 0.2, 0.04, size.z + 0.2), color.darkened(0.35), Vector3(0, 0.02, 0)))
    if label_text != "":
        label = VisualFactory.label(label_text, Vector3(0, 1.6, 0), 40)
        add_child(label)


func set_label(text: String) -> void:
    label_text = text
    if label == null:
        label = VisualFactory.label(text, Vector3(0, 1.6, 0), 40)
        add_child(label)
    else:
        label.text = text


func set_highlight(on: bool) -> void:
    if on == _highlight:
        return
    _highlight = on
    mesh.material_override = VisualFactory.material(color, Color(0.9, 0.75, 0.2) if on else Color.BLACK)


func _physics_process(delta: float) -> void:
    if not monitoring:
        return   # 關掉偵測(付清的價格牌)後 get_overlapping_bodies 會報錯
    for b in get_overlapping_bodies():
        var c := b as Carrier
        if c != null:
            _on_carrier_stay(c, delta)


## 子類別覆寫:carrier 站在格子上的每一幀
func _on_carrier_stay(_c: Carrier, _delta: float) -> void:
    pass


## 以每秒 rate 件的速度,回傳本幀可以搬幾件(累加器最多多攢 1 件,離開再回來不會爆量)
func _budget(c: Carrier, rate: float, delta: float) -> int:
    var key := c.get_instance_id()
    var v := minf(float(_acc.get(key, 0.0)) + rate * delta, 1.0 + rate * delta)
    var n := int(floor(v))
    _acc[key] = v - float(n)
    return n
