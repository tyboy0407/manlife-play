class_name Bear
extends Node3D
## 北極熊:從地圖邊緣(entry)走進村裡,盯上最近的幫手,走到旁邊咬 biteSec 秒就把幫手吃掉(永久消失),
## 接著找下一個,直到被趕跑(帶武器的玩家靠到 scareRadius 內)或村裡沒幫手了才走。沒有物理(穿過一切)。
## 規則在 BearLogic;吃掉幫手由 Harbor.helper_eaten 結算。外觀:白色方塊占位(models.bear 有模型就用模型),咬的時候頭上下動。

signal left(reason: String)   # "fled" 被趕跑 / "no_prey" 沒人可吃

var level: Harbor = null
var logic: BearLogic = null
var entry := Vector3(-16, 0, -8)
var state := "hunting"        # hunting / biting / fleeing / leaving
var target: Helper = null
var bite := 0.0
var eaten_total := 0
var scared_at_dist := -1.0    # 被嚇跑時玩家離多遠(測試用)

var _head: Node3D = null
var _t := 0.0


func _ready() -> void:
    add_to_group("bear")
    if logic == null:
        logic = BearLogic.from_config(GameData.section("bear"), GameData.section("weapon"))
    _build_visual()


func _build_visual() -> void:
    var scene := ModelLibrary.bear()
    if scene != null:
        var inst := scene.instantiate() as Node3D
        add_child(inst)
        var box := ModelLibrary.scene_aabb(inst)
        var s := float(GameData.section("bear").get("length", 2.6)) / maxf(maxf(box.size.x, box.size.z), 0.01)
        inst.scale = Vector3(s, s, s)
        var c := box.get_center() * s
        inst.position = Vector3(-c.x, -box.position.y * s, -c.z)
        var anim := ModelLibrary.find_anim(inst)
        if anim != null and anim.get_animation_list().size() > 0:
            var n: String = anim.get_animation_list()[0]
            anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
            anim.play(n)
    else:
        # 占位:矮而寬的身體(相機從上往下看,太長的方塊會像冰箱)、肩膀隆起、前面一顆大頭、四隻短腿、小尾巴
        var fur := Color(0.95, 0.96, 0.98)
        add_child(VisualFactory.box(Vector3(1.8, 0.9, 2.0), fur, Vector3(0, 0.85, -0.2)))
        add_child(VisualFactory.box(Vector3(1.5, 0.35, 1.0), fur, Vector3(0, 1.45, 0.3)))
        add_child(VisualFactory.box(Vector3(0.35, 0.3, 0.3), fur.darkened(0.06), Vector3(0, 1.0, -1.3)))
        for x in [-0.6, 0.6]:
            for z in [-0.85, 0.65]:
                add_child(VisualFactory.box(Vector3(0.5, 0.6, 0.55), fur.darkened(0.08), Vector3(x, 0.3, z)))
        _head = Node3D.new()
        _head.position = Vector3(0, 1.3, 1.05)
        add_child(_head)
        _head.add_child(VisualFactory.box(Vector3(1.0, 0.85, 0.95), fur, Vector3(0, 0, 0.25)))
        _head.add_child(VisualFactory.box(Vector3(0.5, 0.4, 0.35), fur.darkened(0.04), Vector3(0, -0.2, 0.85)))
        _head.add_child(VisualFactory.box(Vector3(0.3, 0.22, 0.2), Color(0.08, 0.08, 0.1), Vector3(0, -0.12, 1.05)))
        for x in [-0.33, 0.33]:
            _head.add_child(VisualFactory.box(Vector3(0.26, 0.26, 0.18), fur.darkened(0.1), Vector3(x, 0.5, 0.05)))
            _head.add_child(VisualFactory.box(Vector3(0.14, 0.14, 0.05), Color(0.08, 0.08, 0.1), Vector3(x * 0.75, 0.15, 0.73)))
    add_child(VisualFactory.blob_shadow(1.0, Settings.is_smooth()))


func planar_distance_to(p: Vector3) -> float:
    return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _physics_process(delta: float) -> void:
    _t += delta
    match state:
        "fleeing", "leaving":
            var spd := logic.flee_speed() if state == "fleeing" else logic.speed()
            if _move_to(entry, spd, delta, 0.6):
                var reason := "fled" if state == "fleeing" else "no_prey"
                left.emit(reason)
                queue_free()
        _:
            _hunt(delta)


func _hunt(delta: float) -> void:
    if level == null:
        return
    var p := level.player
    if p != null and is_instance_valid(p) and logic.can_scare(GameState.weapon_level, planar_distance_to(p.global_position)):
        scare(p)
        return
    if target == null or not is_instance_valid(target) or target.eaten:
        target = null
        _retarget()
        if target == null:
            _leave()
            return
    var d := planar_distance_to(target.global_position)
    if state == "biting":
        if d > logic.bite_radius() * 1.6:
            state = "hunting"   # 幫手被拉開了(不該發生,保險)
            return
        bite += delta
        if _head != null:
            _head.rotation.x = sin(_t * 18.0) * 0.25
        _face(target.global_position)
        if bite >= logic.bite_sec():
            _eat()
        return
    if d <= logic.panic_radius():
        target.set_panic(true)
    if d <= logic.bite_radius():
        state = "biting"
        bite = 0.0
        target.set_panic(true)
        EventBus.bear_biting.emit(target)
        return
    _move_to(target.global_position, logic.speed(), delta, logic.bite_radius() * 0.9)


## 最近的、還沒被吃的幫手;一群熊時先避開別隻熊已經盯上的(都被盯了才搶)
func _retarget() -> void:
    var taken := level.bears.targeted_ids(self) if level.bears != null else {}
    var prey := []
    var free := []
    for h in level.helpers:
        if h != null and is_instance_valid(h) and not h.eaten:
            var e := {"id": h.get_instance_id(), "pos": h.global_position}
            prey.append(e)
            if not taken.has(h.get_instance_id()):
                free.append(e)
    var id := BearLogic.pick_target(global_position, free if not free.is_empty() else prey)
    if id < 0:
        return
    var obj := instance_from_id(id)
    if obj is Helper:
        target = obj as Helper


func _eat() -> void:
    var h := target
    target = null
    state = "hunting"
    bite = 0.0
    if _head != null:
        _head.rotation.x = 0.0
    eaten_total += 1
    if level != null and h != null and is_instance_valid(h):
        level.helper_eaten(h, self)


## 被帶武器的玩家嚇跑:放開正在咬的幫手,往來的方向逃
func scare(by: Carrier) -> void:
    if state == "fleeing" or state == "leaving":
        return
    scared_at_dist = planar_distance_to(by.global_position)
    _release()
    state = "fleeing"
    if _head != null:
        _head.rotation.x = 0.0
    if by.model != null:
        by.model.set_action("attack-melee-right", false)
    EventBus.bear_scared.emit(self, by)


## 沒人可吃:慢慢走掉
func _leave() -> void:
    if state == "leaving":
        return
    _release()
    state = "leaving"


func _release() -> void:
    if target != null and is_instance_valid(target):
        target.set_panic(false)
    target = null
    bite = 0.0


func _face(p: Vector3) -> void:
    var d := Vector3(p.x - global_position.x, 0.0, p.z - global_position.z)
    if d.length_squared() > 0.0001:
        rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), 0.2)


## 朝 p 走;到了(平面距離 < stop)回 true
func _move_to(p: Vector3, spd: float, delta: float, stop: float) -> bool:
    var d := Vector3(p.x - global_position.x, 0.0, p.z - global_position.z)
    var dist := d.length()
    if dist < stop:
        return true
    global_position += d / dist * minf(spd * delta, dist)
    global_position.y = 0.0
    rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), minf(1.0, 10.0 * delta))
    if _head != null:
        _head.position.y = 1.3 + sin(_t * 9.0) * 0.04
    return false
