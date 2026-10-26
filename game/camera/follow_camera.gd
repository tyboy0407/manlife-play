class_name FollowCamera
extends Camera3D
## 跟隨相機:固定偏移(等角俯視,從 +Z 側往 -Z 看,所以螢幕上 = 世界 -Z),平滑跟著目標。
## 直式畫面(手機)以寬為準、視角開大一點,橫式以高為準;視窗轉向時重算。

var target: Node3D = null
var offset := Vector3(0, 17.0, 11.5)
var smoothing := 6.0
var offset_landscape := Vector3(0, 17.0, 11.5)   # 桌機橫式:看得到整張地圖寬
var offset_portrait := Vector3(0, 13.5, 9.5)     # 手機直式:靠近一點,角色與格子在手機上才夠大
var fov_landscape := 42.0
var fov_portrait := 40.0


func _ready() -> void:
    _apply_aspect()
    get_viewport().size_changed.connect(_apply_aspect)
    current = true
    if target != null:
        global_position = target.global_position + offset
        look_at(target.global_position + Vector3(0, 0.5, 0), Vector3.UP)


## 高 >= 寬就當直式(正方形也算,headless 的 100 × 100 測試視窗才會走直式分支)
func is_portrait() -> bool:
    var size := get_viewport().get_visible_rect().size
    return size.y >= size.x


func _apply_aspect() -> void:
    if is_portrait():
        keep_aspect = Camera3D.KEEP_WIDTH
        fov = fov_portrait
        offset = offset_portrait
    else:
        keep_aspect = Camera3D.KEEP_HEIGHT
        fov = fov_landscape
        offset = offset_landscape


func _physics_process(delta: float) -> void:
    if target == null or not is_instance_valid(target):
        return
    var want := target.global_position + offset
    global_position = global_position.lerp(want, minf(1.0, smoothing * delta))
    look_at(target.global_position + Vector3(0, 0.5, 0), Vector3.UP)
