class_name BonfirePad
extends Pad
## 火堆(主村東南角):傳承 / 過冬的觸發點。玩家站上來滿 dwellSec 就開過冬面板(Harbor.legacy_prompt),
## 走開再站才會再開一次;選單裡的「火種 / 過冬」鈕也能開同一個面板。外觀:石圈 + 木柴 + 火焰(會閃)。

const DWELL_SEC := 1.0

var level: Node = null
var _dwell := 0.0
var _opened := false
var _standing := false
var _flame: MeshInstance3D
var _flame_t := 0.0


func _init() -> void:
    size = Vector3(1.8, 1.0, 1.8)
    color = Color(0.36, 0.3, 0.26)
    label_text = tr("PAD_BONFIRE")


func _ready() -> void:
    super()
    name = "Bonfire"
    var stone := Color(0.55, 0.55, 0.58)
    for i in 8:
        var a := TAU * float(i) / 8.0
        add_child(VisualFactory.box(Vector3(0.3, 0.22, 0.3), stone, Vector3(cos(a) * 0.62, 0.21, sin(a) * 0.62)))
    var log_c := Color(0.42, 0.28, 0.16)
    var l1 := VisualFactory.box(Vector3(0.9, 0.16, 0.16), log_c, Vector3(0, 0.25, 0))
    l1.rotation.y = 0.6
    add_child(l1)
    var l2 := VisualFactory.box(Vector3(0.9, 0.16, 0.16), log_c, Vector3(0, 0.25, 0))
    l2.rotation.y = -0.7
    add_child(l2)
    _flame = VisualFactory.cone(0.3, 0.8, Color(1.0, 0.6, 0.15), Vector3(0, 0.72, 0))
    add_child(_flame)
    add_child(VisualFactory.cone(0.16, 0.45, Color(1.0, 0.9, 0.4), Vector3(0, 0.55, 0)))


func _physics_process(delta: float) -> void:
    super(delta)
    _flame_t += delta
    if _flame != null:
        var s := 0.9 + 0.12 * sin(_flame_t * 9.0) + 0.06 * sin(_flame_t * 23.0)
        _flame.scale = Vector3(s, 1.0 + 0.2 * sin(_flame_t * 7.0), s)
    if not _standing:
        _dwell = 0.0
        _opened = false
    _standing = false


func _on_carrier_stay(c: Carrier, delta: float) -> void:
    if not c.collects_cash:
        return   # 只有玩家
    _standing = true
    if _opened:
        return
    _dwell += delta
    if _dwell >= DWELL_SEC and level != null and level.has_method("legacy_prompt"):
        _opened = true
        level.legacy_prompt()
