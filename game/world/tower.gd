class_name Tower
extends Node3D
## 守衛塔(村莊四角,各有一塊 $200 的牌:shop.json tower_1 ~ tower_4,牌就是塔的地基):
## 買了就蓋起來(state alive),塔頂的守衛每 attackIntervalSec 朝射程內最近的活熊射一箭(Arrow 追著熊飛,到了才扣血),
## 熊靠近(TowerLogic.aggro_radius)或被射中會改來咬塔,咬一口扣 biteDamage,血條歸零就塌(state broken,剩廢墟);
## 北極熊王不看血量,咬滿 buildingBiteSec 秒直接拆(wreck),
## 牌子重新出現標「修復」(rebuyMult 1 = 同價),付清再蓋回來。沒買過是 state none(只有牌子)。沒有物理(熊 / 玩家都穿得過)。
## 規則在 TowerLogic;蓋 / 塌的結算在 Harbor(_on_purchased "tower" / tower_destroyed)。外觀:方塊占位 + models.guard 的人物當守衛。
## tier 1 = 強力守衛塔(熊王牙牌 tooth_<id> 強化,Harbor._on_purchased "tower_upgrade" -> upgrade()):血 2000(50 口)、每箭 25;拆掉修好後還是強力的。
## 升級(rate_level / damage_level,各最多 TowerLogic.max_upgrades 次、每次 upgrade_cost):玩家站在完好的塔旁 upgrade_radius 內滿 upgrade_dwell_sec 秒
## -> Harbor.tower_upgrade_prompt(self) 開面板(射速 or 傷害);走開再站才會再開。存檔記 rate / damage 等級。

signal destroyed(by: Node3D)

var id := ""
var level: Harbor = null
var logic: TowerLogic = null
var state := "none"       # none / alive / broken
var tier := 0             # 0 一般、1 強力(熊王牙)
var hp := 0.0
var hp_max := 120.0
var shots_total := 0
var hits_total := 0       # 箭射中幾次
var damage_dealt := 0.0
var times_built := 0
var times_broken := 0
var last_target: Node3D = null

var _built: Node3D = null      # 完整的塔
var _rubble: Node3D = null     # 塌掉的廢墟
var _guard_pivot: Node3D = null
var _guard: CharacterModel = null
var _hp_bar: Node3D = null
var _hp_fill: MeshInstance3D = null
var _ring: ProgressRing = null
var _flag: MeshInstance3D = null
var _strong_band: MeshInstance3D = null
var _cooldown := 0.0
var _flash := 0.0
var rate_level := 0       # 射速升級幾次(射擊間隔 × rateMult^n)
var damage_level := 0     # 傷害升級幾次
var _near_t := 0.0        # 玩家站在旁邊幾秒了
var _near_armed := true   # 開過面板後要走開才會再開
var _meshes: Array[MeshInstance3D] = []

static var _hit_overlay: StandardMaterial3D = null


func _ready() -> void:
    add_to_group("tower")
    if logic == null:
        logic = TowerLogic.from_config(GameData.section("tower"))
    hp_max = logic.hp(tier)
    _build_visuals()
    _apply_state()


## --- 外觀 ---

func _build_visuals() -> void:
    var stone := Color(0.58, 0.6, 0.66)
    var wood := Color(0.6, 0.42, 0.26)
    var roof := Color(0.55, 0.18, 0.15)
    _built = Node3D.new()
    _built.name = "Built"
    add_child(_built)
    _built.add_child(VisualFactory.cylinder(0.8, 2.4, stone, Vector3(0, 1.2, 0)))
    _built.add_child(VisualFactory.cylinder(0.95, 0.3, stone.darkened(0.15), Vector3(0, 0.15, 0)))
    _built.add_child(VisualFactory.box(Vector3(2.0, 0.22, 2.0), wood, Vector3(0, 2.5, 0)))
    for side in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
        var rail_size := Vector3(2.0, 0.12, 0.1) if side.z != 0.0 else Vector3(0.1, 0.12, 2.0)
        _built.add_child(VisualFactory.box(rail_size, wood.darkened(0.2), side * 0.95 + Vector3(0, 3.0, 0)))
    for x in [-0.85, 0.85]:
        for z in [-0.85, 0.85]:
            _built.add_child(VisualFactory.box(Vector3(0.14, 1.6, 0.14), wood.darkened(0.25), Vector3(x, 3.4, z)))
    _built.add_child(VisualFactory.cone(1.45, 1.1, roof, Vector3(0, 4.25, 0)))
    _built.add_child(VisualFactory.box(Vector3(0.06, 0.9, 0.06), wood.darkened(0.3), Vector3(0, 5.2, 0)))
    _flag = VisualFactory.box(Vector3(0.5, 0.3, 0.04), Color(0.9, 0.25, 0.2), Vector3(0.27, 5.45, 0))
    _built.add_child(_flag)
    _strong_band = VisualFactory.cylinder(0.9, 0.25, Color(1.0, 0.82, 0.2), Vector3(0, 2.3, 0))
    _strong_band.visible = false
    _built.add_child(_strong_band)
    _guard_pivot = Node3D.new()
    _guard_pivot.name = "GuardPivot"
    _guard_pivot.position = Vector3(0, 2.61, 0)
    _built.add_child(_guard_pivot)
    var scene := ModelLibrary.character(ModelLibrary.guard_model())
    if scene != null:
        _guard = CharacterModel.create(scene, ModelLibrary.customer_height())
        _guard_pivot.add_child(_guard)
    else:
        _guard_pivot.add_child(VisualFactory.capsule(0.3, 1.1, Color(0.3, 0.45, 0.7), Vector3(0, 0.62, 0)))
    # 弓:一根彎的占位木條
    _guard_pivot.add_child(VisualFactory.box(Vector3(0.05, 0.9, 0.05), wood.darkened(0.35), Vector3(0.38, 0.85, 0.3)))
    _rubble = Node3D.new()
    _rubble.name = "Rubble"
    add_child(_rubble)
    _rubble.add_child(VisualFactory.cylinder(0.8, 0.9, stone.darkened(0.3), Vector3(0, 0.45, 0)))
    _rubble.add_child(VisualFactory.cylinder(0.95, 0.3, stone.darkened(0.35), Vector3(0, 0.15, 0)))
    var b1 := VisualFactory.box(Vector3(1.2, 0.2, 0.7), wood.darkened(0.4), Vector3(0.9, 0.3, 0.6))
    b1.rotation = Vector3(0.1, 0.5, 0.35)
    _rubble.add_child(b1)
    var b2 := VisualFactory.box(Vector3(0.9, 0.5, 0.5), stone.darkened(0.25), Vector3(-0.8, 0.25, -0.5))
    b2.rotation = Vector3(0.0, -0.6, 0.2)
    _rubble.add_child(b2)
    var b3 := VisualFactory.cone(0.6, 0.5, roof.darkened(0.3), Vector3(-0.5, 0.25, 0.9))
    b3.rotation = Vector3(1.2, 0.3, 0.0)
    _rubble.add_child(b3)
    _meshes = ModelLibrary.mesh_instances(_built)
    _ring = ProgressRing.new()
    _ring.inner = logic.attack_range() - 0.12
    _ring.outer = logic.attack_range()
    _ring.color = Color(0.45, 0.75, 1.0, 0.55)
    _ring.bg_color = Color(0.0, 0.0, 0.0, 0.0)
    _ring.segments = 72
    _ring.position = Vector3(0, 0.04, 0)
    add_child(_ring)
    _ring.set_progress(1.0)
    _hp_bar = Node3D.new()
    _hp_bar.name = "HpBar"
    _hp_bar.position = Vector3(0, logic.height() + 2.9, 0)
    add_child(_hp_bar)
    _hp_bar.add_child(VisualFactory.box(Vector3(1.7, 0.22, 0.06), Color(0.12, 0.1, 0.12), Vector3.ZERO))
    _hp_fill = VisualFactory.box(Vector3(1.6, 0.14, 0.08), Color(0.3, 0.8, 0.35), Vector3.ZERO)
    _hp_fill.material_override = VisualFactory.material(Color(0.3, 0.8, 0.35), Color(0.05, 0.3, 0.08))
    _hp_bar.add_child(_hp_fill)


func _apply_state() -> void:
    var alive := state == "alive"
    if _flag != null:
        _flag.material_override = VisualFactory.material(Color(1.0, 0.82, 0.2) if tier >= 1 else Color(0.9, 0.25, 0.2))
    if _strong_band != null:
        _strong_band.visible = tier >= 1
    if _built != null:
        _built.visible = alive
    if _rubble != null:
        _rubble.visible = state == "broken"
    if _ring != null:
        _ring.visible = alive
    if _hp_bar != null:
        _hp_bar.visible = alive
    _update_hp_bar()


func _update_hp_bar() -> void:
    if _hp_fill == null:
        return
    var ratio := hp_ratio()
    _hp_fill.scale = Vector3(maxf(ratio, 0.001), 1.0, 1.0)
    _hp_fill.position.x = -(1.0 - ratio) * 0.8


func hp_ratio() -> float:
    return clampf(hp / maxf(hp_max, 0.01), 0.0, 1.0)


func is_alive() -> bool:
    return state == "alive"


func is_broken() -> bool:
    return state == "broken"


func is_strong() -> bool:
    return tier >= 1


func planar_distance_to(p: Vector3) -> float:
    return Vector2(p.x - global_position.x, p.z - global_position.z).length()


## --- 蓋 / 塌 ---

## 蓋好(或修好):血回滿;silent = 存檔還原不發事件
func build(silent: bool = false) -> void:
    state = "alive"
    hp_max = logic.hp(tier)
    hp = hp_max
    _cooldown = 0.0
    times_built += 1
    _apply_state()
    if not silent:
        EventBus.tower_built.emit(self)


## 熊王牙強化成強力守衛塔:血上限 / 每箭傷害換成 strong 的,血回滿(只能升一次);回傳有沒有升
func upgrade(silent: bool = false) -> bool:
    if tier >= logic.max_tier():
        return false
    tier += 1
    hp_max = logic.hp(tier)
    if is_alive():
        hp = hp_max
    _apply_state()
    if not silent:
        EventBus.tower_upgraded.emit(self)
    return true


## 熊咬一口:扣血、閃紅;歸零就塌。回傳是否塌了
func take_bite(damage: float, by: Node3D) -> bool:
    if not is_alive() or damage <= 0.0:
        return false
    hp = maxf(hp - damage, 0.0)
    _flash = 0.15
    _set_overlay(_hit_material())
    _update_hp_bar()
    EventBus.tower_damaged.emit(self, hp)
    if hp <= 0.0:
        _collapse(by)
        return true
    return false


## 北極熊王咬滿時間直接拆掉(不看血量);回傳是否真的塌了
func wreck(by: Node3D) -> bool:
    if not is_alive():
        return false
    hp = 0.0
    _collapse(by)
    return true


func _collapse(by: Node3D) -> void:
    state = "broken"
    times_broken += 1
    _set_overlay(null)
    _apply_state()
    EventBus.tower_destroyed.emit(self, by)
    destroyed.emit(by)
    if level != null:
        level.tower_destroyed(self, by)


## --- 射箭 ---

func _physics_process(delta: float) -> void:
    if _flash > 0.0:
        _flash -= delta
        if _flash <= 0.0:
            _set_overlay(null)
    if not is_alive():
        return
    _check_player(delta)
    _cooldown = maxf(_cooldown - delta, 0.0)
    if _cooldown > 0.0:
        return
    var target := _pick_target()
    if target == null:
        return
    _shoot(target)


## 玩家站在塔旁滿 upgrade_dwell_sec 秒就請關卡開升級面板(走開才會再開一次)
func _check_player(delta: float) -> void:
    if level == null or level.player == null or not is_instance_valid(level.player):
        return
    if planar_distance_to(level.player.global_position) <= logic.upgrade_radius():
        _near_t += delta
        if _near_armed and _near_t >= logic.upgrade_dwell_sec():
            _near_armed = false
            level.tower_upgrade_prompt(self)
    else:
        _near_t = 0.0
        _near_armed = true


## 玩家站在旁邊幾秒了(測試用)
func near_sec() -> float:
    return _near_t


func upgrades_left(kind: String) -> int:
    return logic.max_upgrades() - (rate_level if kind == "rate" else damage_level)


## 升一級射速 / 傷害(不扣錢,錢由 Harbor 管);升滿回 false
func apply_upgrade(kind: String) -> bool:
    if not is_alive() or upgrades_left(kind) <= 0:
        return false
    if kind == "rate":
        rate_level += 1
    elif kind == "damage":
        damage_level += 1
    else:
        return false
    return true


func current_interval() -> float:
    return logic.attack_interval(rate_level)


func current_damage() -> float:
    return logic.damage(tier, damage_level)


## 射程內最近的活熊
func _pick_target() -> Bear:
    var bears := []
    for n in get_tree().get_nodes_in_group("bear"):
        if n is Bear and is_instance_valid(n):
            bears.append({"id": n.get_instance_id(), "pos": (n as Node3D).global_position, "alive": (n as Bear).alive()})
    var id := TowerLogic.pick_target(global_position, bears, logic.attack_range())
    if id < 0:
        return null
    var obj := instance_from_id(id)
    return obj as Bear if obj is Bear else null


func _shoot(target: Bear) -> void:
    _cooldown = logic.attack_interval(rate_level)
    shots_total += 1
    last_target = target
    _face_guard(target.global_position)
    var a := Arrow.new()
    a.tower = self
    a.target = target
    a.speed = logic.arrow_speed()
    a.damage = logic.damage(tier, damage_level)
    var parent := get_parent() if get_parent() != null else self
    parent.add_child(a)
    a.global_position = global_position + Vector3(0, logic.height(), 0)
    a.aim()
    EventBus.tower_shot.emit(self, target)


## 箭到了:熊還活著就扣血,熊會記住是哪座塔射的(靠得近就改來拆塔)
func _arrow_hit(a: Arrow) -> void:
    var b := a.target as Bear
    if b == null or not is_instance_valid(b) or not b.alive():
        return
    hits_total += 1
    damage_dealt += a.damage
    b.take_hit(a.damage, self)
    if is_instance_valid(b):
        b.on_tower_hit(self)


func _face_guard(p: Vector3) -> void:
    if _guard_pivot == null:
        return
    var d := Vector3(p.x - global_position.x, 0.0, p.z - global_position.z)
    if d.length_squared() > 0.0001:
        _guard_pivot.rotation.y = atan2(d.x, d.z)


func _set_overlay(mat: StandardMaterial3D) -> void:
    for mi in _meshes:
        if is_instance_valid(mi):
            mi.material_overlay = mat


static func _hit_material() -> StandardMaterial3D:
    if _hit_overlay == null:
        _hit_overlay = StandardMaterial3D.new()
        _hit_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        _hit_overlay.albedo_color = Color(1.0, 0.3, 0.2, 0.5)
        _hit_overlay.emission_enabled = true
        _hit_overlay.emission = Color(1.0, 0.25, 0.1)
        _hit_overlay.emission_energy_multiplier = 1.2
    return _hit_overlay


## --- 存檔 ---

func snapshot() -> Dictionary:
    return {"state": state, "hp": hp, "tier": tier, "rate": rate_level, "damage": damage_level}


func restore(d: Dictionary) -> void:
    tier = clampi(int(d.get("tier", 0)), 0, logic.max_tier())
    rate_level = clampi(int(d.get("rate", 0)), 0, logic.max_upgrades())
    damage_level = clampi(int(d.get("damage", 0)), 0, logic.max_upgrades())
    hp_max = logic.hp(tier)
    var s := str(d.get("state", "none"))
    if s == "alive":
        build(true)
        hp = clampf(float(d.get("hp", hp_max)), 1.0, hp_max)
        _update_hp_bar()
    elif s == "broken":
        state = "broken"
        hp = 0.0
        _apply_state()
    else:
        state = "none"
        hp = 0.0
        _apply_state()


## 箭:從塔頂朝熊飛(追著熊,一定射中),到了叫 Tower._arrow_hit 扣血。沒有物理。
class Arrow extends Node3D:
    var tower: Tower = null
    var target: Node3D = null
    var speed := 18.0
    var damage := 10.0
    var _life := 3.0


    func _ready() -> void:
        var shaft := Color(0.5, 0.35, 0.2)
        add_child(VisualFactory.box(Vector3(0.06, 0.06, 0.8), shaft, Vector3.ZERO))
        add_child(VisualFactory.box(Vector3(0.1, 0.1, 0.16), Color(0.75, 0.78, 0.82), Vector3(0, 0, -0.46)))
        add_child(VisualFactory.box(Vector3(0.16, 0.03, 0.2), Color(0.9, 0.9, 0.92), Vector3(0, 0, 0.32)))


    func _aim_point() -> Vector3:
        if target == null or not is_instance_valid(target):
            return global_position
        var h := 1.0
        if target is Bear:
            h = 1.0 * (target as Bear).size_scale
        return target.global_position + Vector3(0, h, 0)


    ## 箭頭(local -Z)朝向目標
    func aim() -> void:
        var p := _aim_point()
        if p.distance_squared_to(global_position) > 0.0001:
            look_at(p, Vector3.UP)


    func _physics_process(delta: float) -> void:
        _life -= delta
        if target == null or not is_instance_valid(target) or _life <= 0.0:
            queue_free()
            return
        var p := _aim_point()
        var d := p - global_position
        var dist := d.length()
        var step := speed * delta
        if dist <= step:
            global_position = p
            if tower != null and is_instance_valid(tower):
                tower._arrow_hit(self)
            queue_free()
            return
        global_position += d / dist * step
        aim()
