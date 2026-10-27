class_name Bear
extends Node3D
## 北極熊:從地圖邊緣(entry)走進村裡,盯上最近的幫手,走到旁邊咬 biteSec 秒就把幫手吃掉(永久消失),
## 接著找下一個,直到被玩家打到血條歸零(逃回 entry)或村裡沒幫手了才走。沒有物理(穿過一切)。
## 血量 = BearLogic.hp(遊戲時間):越晚越厚;玩家帶武器靠近會自動攻擊(Player._attack -> take_hit),頭上有血條,被打閃紅。
## 北極熊王(is_king):更大更厚,連水裡的魚也吃,每吃一口回血並變大;不會自己走,只能打死。
## 規則在 BearLogic;吃掉幫手 / 魚由 Harbor.helper_eaten / fish_eaten 結算。外觀:白色方塊占位(models.bear 有模型就用模型)。

signal left(reason: String)   # "fled" 被打跑 / "no_prey" 沒人可吃

var level: Harbor = null
var logic: BearLogic = null
var entry := Vector3(-16, 0, -8)
var state := "hunting"        # hunting / biting / fleeing / leaving
var target: Node3D = null     # Helper(或王才會盯的 Fish)
var bite := 0.0
var eaten_total := 0
var hp := 30.0
var hp_max := 30.0
var is_king := false
var size_scale := 1.0         # 體型倍率(王吃東西會變大)
var hits_taken := 0

var _body: Node3D = null      # 全部外觀掛這裡,體型用它縮放
var _head: Node3D = null
var _meshes: Array[MeshInstance3D] = []
var _hp_bar: Node3D = null
var _hp_fill: MeshInstance3D = null
var _flash := 0.0
var _t := 0.0

static var _hit_overlay: StandardMaterial3D = null


func _ready() -> void:
    add_to_group("bear")
    if logic == null:
        logic = BearLogic.from_config(GameData.section("bear"), GameData.section("weapon"))
    hp_max = logic.hp(GameState.play_time) * (logic.king_hp_mult() if is_king else 1.0)
    hp = hp_max
    size_scale = logic.king_scale() if is_king else 1.0
    _body = Node3D.new()
    _body.name = "Body"
    add_child(_body)
    _build_visual()
    _meshes = ModelLibrary.mesh_instances(_body)
    _body.scale = Vector3(size_scale, size_scale, size_scale)
    _build_hp_bar()


func _build_visual() -> void:
    var scene := ModelLibrary.bear()
    if scene != null:
        var inst := scene.instantiate() as Node3D
        _body.add_child(inst)
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
        # 占位:矮而寬的身體(相機從上往下看,太長的方塊會像冰箱)、肩膀隆起、前面一顆大頭、四隻短腿、小尾巴;王偏藍白、戴金冠
        var fur := Color(0.82, 0.9, 1.0) if is_king else Color(0.95, 0.96, 0.98)
        _body.add_child(VisualFactory.box(Vector3(1.8, 0.9, 2.0), fur, Vector3(0, 0.85, -0.2)))
        _body.add_child(VisualFactory.box(Vector3(1.5, 0.35, 1.0), fur, Vector3(0, 1.45, 0.3)))
        _body.add_child(VisualFactory.box(Vector3(0.35, 0.3, 0.3), fur.darkened(0.06), Vector3(0, 1.0, -1.3)))
        for x in [-0.6, 0.6]:
            for z in [-0.85, 0.65]:
                _body.add_child(VisualFactory.box(Vector3(0.5, 0.6, 0.55), fur.darkened(0.08), Vector3(x, 0.3, z)))
        _head = Node3D.new()
        _head.position = Vector3(0, 1.3, 1.05)
        _body.add_child(_head)
        _head.add_child(VisualFactory.box(Vector3(1.0, 0.85, 0.95), fur, Vector3(0, 0, 0.25)))
        _head.add_child(VisualFactory.box(Vector3(0.5, 0.4, 0.35), fur.darkened(0.04), Vector3(0, -0.2, 0.85)))
        _head.add_child(VisualFactory.box(Vector3(0.3, 0.22, 0.2), Color(0.08, 0.08, 0.1), Vector3(0, -0.12, 1.05)))
        for x in [-0.33, 0.33]:
            _head.add_child(VisualFactory.box(Vector3(0.26, 0.26, 0.18), fur.darkened(0.1), Vector3(x, 0.5, 0.05)))
            _head.add_child(VisualFactory.box(Vector3(0.14, 0.14, 0.05), Color(0.08, 0.08, 0.1), Vector3(x * 0.75, 0.15, 0.73)))
        if is_king:
            var gold := Color(1.0, 0.82, 0.2)
            _head.add_child(VisualFactory.box(Vector3(0.7, 0.18, 0.7), gold, Vector3(0, 0.5, 0.25)))
            for x in [-0.25, 0.0, 0.25]:
                _head.add_child(VisualFactory.box(Vector3(0.14, 0.3, 0.14), gold, Vector3(x, 0.72, 0.5)))
    _body.add_child(VisualFactory.blob_shadow(1.0, Settings.is_smooth()))


func _build_hp_bar() -> void:
    _hp_bar = Node3D.new()
    _hp_bar.name = "HpBar"
    add_child(_hp_bar)
    var bg := VisualFactory.box(Vector3(1.7, 0.22, 0.06), Color(0.12, 0.1, 0.12), Vector3(0, 0, 0))
    _hp_bar.add_child(bg)
    _hp_fill = VisualFactory.box(Vector3(1.6, 0.14, 0.08), Color(0.9, 0.2, 0.2), Vector3(0, 0, 0))
    _hp_fill.material_override = VisualFactory.material(Color(0.9, 0.2, 0.2), Color(0.5, 0.05, 0.05))
    _hp_bar.add_child(_hp_fill)
    _update_hp_bar()


func _update_hp_bar() -> void:
    if _hp_fill == null:
        return
    var ratio := hp_ratio()
    _hp_fill.scale = Vector3(maxf(ratio, 0.001), 1.0, 1.0)
    _hp_fill.position.x = -(1.0 - ratio) * 0.8
    _hp_bar.position = Vector3(0, 2.4 * size_scale + 0.3, 0)


func hp_ratio() -> float:
    return clampf(hp / maxf(hp_max, 0.01), 0.0, 1.0)


func planar_distance_to(p: Vector3) -> float:
    return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func alive() -> bool:
    return state == "hunting" or state == "biting"


func _physics_process(delta: float) -> void:
    _t += delta
    if _hp_bar != null:
        _hp_bar.global_rotation = Vector3.ZERO   # 血條永遠正對相機那一側
    if _flash > 0.0:
        _flash -= delta
        if _flash <= 0.0:
            _set_overlay(null)
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
    if target == null or not is_instance_valid(target) or (target is Helper and (target as Helper).eaten):
        target = null
        _retarget()
        if target == null:
            if is_king:
                _move_to(Vector3.ZERO, logic.speed() * 0.5, delta, 1.0)   # 王不走:沒東西吃就在村子中間等
            else:
                _leave()
            return
    var d := planar_distance_to(target.global_position)
    var bite_need := _bite_sec_for(target)
    if state == "biting":
        if d > logic.bite_radius() * 1.6 * size_scale:
            state = "hunting"
            return
        bite += delta
        if _head != null:
            _head.rotation.x = sin(_t * 18.0) * 0.25
        _face(target.global_position)
        if bite >= bite_need:
            _eat()
        return
    if target is Helper and d <= logic.panic_radius():
        (target as Helper).set_panic(true)
    if d <= logic.bite_radius() * size_scale:
        state = "biting"
        bite = 0.0
        if target is Helper:
            (target as Helper).set_panic(true)
            EventBus.bear_biting.emit(target)
        return
    _move_to(target.global_position, logic.speed(), delta, logic.bite_radius() * 0.9 * size_scale)


func _bite_sec_for(t: Node3D) -> float:
    if t is Fish:
        return logic.king_fish_bite_sec()
    return logic.king_bite_sec() if is_king else logic.bite_sec()


## 最近的、還沒被吃的幫手;一群熊時先避開別隻熊已經盯上的(都被盯了才搶)。王連水裡的魚也算獵物。
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
    if is_king:
        for fa in level.fish_areas:
            for f in fa.fish:
                if f != null and is_instance_valid(f):
                    var e := {"id": f.get_instance_id(), "pos": f.global_position}
                    prey.append(e)
                    free.append(e)
    var id := BearLogic.pick_target(global_position, free if not free.is_empty() else prey)
    if id < 0:
        return
    var obj := instance_from_id(id)
    if obj is Node3D:
        target = obj as Node3D


func _eat() -> void:
    var t := target
    target = null
    state = "hunting"
    bite = 0.0
    if _head != null:
        _head.rotation.x = 0.0
    eaten_total += 1
    if level == null or t == null or not is_instance_valid(t):
        return
    if t is Fish:
        level.fish_eaten(t as Fish, self)
        if is_king:
            _feast(logic.king_heal_fish(), logic.king_grow_fish())
    elif t is Helper:
        level.helper_eaten(t as Helper, self)
        if is_king:
            _feast(1.0, logic.king_grow_helper())


## 王吃到東西:回血(heal = 血條上限的比例)、變大(血條上限跟著體型漲)
func _feast(heal: float, grow: float) -> void:
    var new_scale := minf(size_scale * grow, logic.king_max_scale())
    var ratio := new_scale / maxf(size_scale, 0.01)
    size_scale = new_scale
    hp_max *= ratio
    hp = minf(hp + hp_max * heal, hp_max)
    _body.scale = Vector3(size_scale, size_scale, size_scale)
    _update_hp_bar()
    EventBus.bear_fed.emit(self)


## 被玩家打一下:扣血、閃紅;歸零就逃(王也是逃走消失,等於被打死)
func take_hit(damage: float, by: Carrier) -> void:
    if not alive() or damage <= 0.0:
        return
    hp = maxf(hp - damage, 0.0)
    hits_taken += 1
    _flash = 0.12
    _set_overlay(_hit_material())
    _update_hp_bar()
    EventBus.bear_hit.emit(self, damage, hp)
    if hp <= 0.0:
        defeat(by)


## 血條歸零:放開正在咬的幫手,往來的方向逃
func defeat(by: Carrier) -> void:
    if not alive():
        return
    _release()
    state = "fleeing"
    if _head != null:
        _head.rotation.x = 0.0
    if _hp_bar != null:
        _hp_bar.visible = false
    EventBus.bear_defeated.emit(self, by)


## 沒人可吃:慢慢走掉
func _leave() -> void:
    if state == "leaving":
        return
    _release()
    state = "leaving"


func _release() -> void:
    if target != null and is_instance_valid(target) and target is Helper:
        (target as Helper).set_panic(false)
    target = null
    bite = 0.0


func _set_overlay(mat: StandardMaterial3D) -> void:
    for mi in _meshes:
        if is_instance_valid(mi):
            mi.material_overlay = mat


static func _hit_material() -> StandardMaterial3D:
    if _hit_overlay == null:
        _hit_overlay = StandardMaterial3D.new()
        _hit_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        _hit_overlay.albedo_color = Color(1.0, 0.2, 0.15, 0.55)
        _hit_overlay.emission_enabled = true
        _hit_overlay.emission = Color(1.0, 0.2, 0.1)
        _hit_overlay.emission_energy_multiplier = 1.5
    return _hit_overlay


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
