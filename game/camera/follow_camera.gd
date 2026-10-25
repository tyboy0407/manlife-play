class_name FollowCamera
extends Camera3D
## 跟隨相機:固定偏移(等角俯視,從 +Z 側往 -Z 看,所以螢幕上 = 世界 -Z),平滑跟著目標。

var target: Node3D = null
var offset := Vector3(0, 13.0, 9.5)
var smoothing := 6.0


func _ready() -> void:
    fov = 42.0
    current = true
    if target != null:
        global_position = target.global_position + offset
        look_at(target.global_position + Vector3(0, 0.5, 0), Vector3.UP)


func _physics_process(delta: float) -> void:
    if target == null or not is_instance_valid(target):
        return
    var want := target.global_position + offset
    global_position = global_position.lerp(want, minf(1.0, smoothing * delta))
    look_at(target.global_position + Vector3(0, 0.5, 0), Vector3.UP)
