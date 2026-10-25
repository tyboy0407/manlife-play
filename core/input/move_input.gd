class_name MoveInput
extends RefCounted
## 每個物理幀的移動輸入快照:dir 是螢幕方向(x 右、y 下),world_dir() 轉成世界 XZ(相機固定朝 -Z 看,螢幕上 = -Z)。
## 來源可以是鍵盤 / 手把(from_actions)、測試的合成輸入(toward),之後加觸控虛擬搖桿只要再多一個來源。

var dir := Vector2.ZERO


static func from_actions() -> MoveInput:
    var m := MoveInput.new()
    m.dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    return m


## 從 from 朝 to 的輸入(平面);距離小於 stop_distance 就不動
static func toward(from: Vector3, to: Vector3, stop_distance: float = 0.2) -> MoveInput:
    var m := MoveInput.new()
    var d := Vector2(to.x - from.x, to.z - from.z)
    if d.length() > stop_distance:
        m.dir = d.normalized()
    return m


func world_dir() -> Vector3:
    return Vector3(dir.x, 0.0, dir.y).limit_length(1.0)


func is_moving() -> bool:
    return dir.length_squared() > 0.0001
