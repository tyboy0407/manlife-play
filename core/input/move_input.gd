class_name MoveInput
extends RefCounted
## 每個物理幀的移動輸入快照:dir 是螢幕方向(x 右、y 下),world_dir() 轉成世界 XZ(相機固定朝 -Z 看,螢幕上 = -Z)。
## 來源:鍵盤 / 手把(Input 動作)、觸控搖桿(TouchJoystick 寫進 touch_dir)、測試的合成輸入(toward)。
## touch_dir 是純資料,放在這裡讓 core 不依賴 UI 節點。

static var touch_dir := Vector2.ZERO   # 觸控搖桿目前的方向(長度 <= 1),沒按是零

var dir := Vector2.ZERO


## 鍵盤 / 手把 + 觸控搖桿(有在推搖桿就以搖桿為準)
static func from_actions() -> MoveInput:
    var m := MoveInput.new()
    if touch_dir.length_squared() > 0.0001:
        m.dir = touch_dir.limit_length(1.0)
    else:
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
