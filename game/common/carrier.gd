class_name Carrier
extends CharacterBody3D
## 會搬東西的角色(玩家 / 幫手)基底:浮動模式(平面世界,不算重力)、物理層 2、只撞地形(層 1,互相穿過)。
## 身上一疊 ItemStack,背後 StackVisual 顯示並隨加速度微晃;旗標決定能不能抓魚 / 取成品 / 收錢(格子依此判斷)。
## 面向:local +Z 是前方(rotation.y = atan2(dir.x, dir.z)),背上的堆疊在 -Z。

const CARRIER_LAYER := 2
const TERRAIN_LAYER := 1

var stack := ItemStack.new()
var speed := 6.0
var accel := 40.0
var can_fish := true
var takes_output := true
var collects_cash := true     # 收錢:錢格的現金收進錢包(GameState.wallet)、站價格牌付錢(玩家)
var can_serve := false        # 站在櫃台收銀格上能讓櫃台賣東西(玩家、收銀員)
var can_use_trash := false    # 能用垃圾桶(玩家)
var color := Color(0.4, 0.6, 1.0)
var caught_total := 0
var stack_visual: StackVisual
var body_mesh: MeshInstance3D


func _ready() -> void:
    motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
    collision_layer = 1 << (CARRIER_LAYER - 1)
    collision_mask = 1 << (TERRAIN_LAYER - 1)
    var shape := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.4
    cap.height = 1.6
    shape.shape = cap
    shape.position = Vector3(0, 0.9, 0)
    add_child(shape)
    body_mesh = VisualFactory.capsule(0.4, 1.6, color, Vector3(0, 0.9, 0))
    add_child(body_mesh)
    add_child(VisualFactory.box(Vector3(0.22, 0.18, 0.18), Color(0.1, 0.1, 0.15), Vector3(0, 1.35, 0.38)))
    stack_visual = StackVisual.new()
    stack_visual.position = Vector3(0, 1.75, -0.32)
    add_child(stack_visual)
    stack.changed.connect(_on_stack_changed)
    _on_stack_changed()


func _on_stack_changed() -> void:
    stack_visual.show_items(stack.item_id, stack.count)


## 朝 dir(世界 XZ,長度 <= 1)加速移動;dir 為零就減速停下
func move_toward_dir(dir: Vector3, delta: float) -> void:
    var target := dir.limit_length(1.0) * speed
    velocity.x = move_toward(velocity.x, target.x, accel * delta)
    velocity.z = move_toward(velocity.z, target.z, accel * delta)
    velocity.y = 0.0
    if dir.length_squared() > 0.0001:
        rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, 14.0 * delta))
    move_and_slide()
    _sway(delta)


## 背上的堆疊依前進速度往後傾
func _sway(delta: float) -> void:
    var forward := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
    var fs := velocity.dot(forward)
    var want := clampf(-fs * 0.035, -0.35, 0.1)
    stack_visual.rotation.x = lerpf(stack_visual.rotation.x, want, minf(1.0, 10.0 * delta))


## 背上那疊的頂端(世界座標),飛行動畫的起點 / 終點
func stack_top() -> Vector3:
    return stack_visual.global_position + Vector3(0.0, stack_visual.top_height(), 0.0)


func planar_distance_to(p: Vector3) -> float:
    return Vector2(p.x - global_position.x, p.z - global_position.z).length()


## 走向 p;到了(距離 < stop)回 true 並停下
func go_to(p: Vector3, delta: float, stop: float = 0.35) -> bool:
    var d := Vector3(p.x - global_position.x, 0.0, p.z - global_position.z)
    if d.length() < stop:
        move_toward_dir(Vector3.ZERO, delta)
        return true
    move_toward_dir(d.normalized(), delta)
    return false
