class_name Fish
extends Node3D
## 魚:在 rect(世界 XZ)裡漫游,被 FishArea 抓走就消失。純外觀 + 位置,沒有物理。
## 外觀:有水裡的魚模型(ModelLibrary.water_fish,Quaternius FBX 含游泳動畫)就用模型(縮到 models.waterFish.length 長、
## 頭朝 local +Z),沒有就兩個方塊占位。被盯上(set_highlight)時模型蓋一層黃色 material_overlay,方塊則換發光材質。

const BODY_Y := 0.12   # 身體中心高度(水面在 0 附近,半泡在水裡)

static var _overlay: StandardMaterial3D = null
static var _gold: StandardMaterial3D = null

var rect := Rect2(-5, -5, 10, 10)
var swim_speed := 1.6
var target := Vector3.ZERO
var highlighted := false
var variant := -1   # 用 models.waterFish.files 的第幾個(-1 隨機)
var rare := false   # 稀有魚(金魚):一直發金光、游得快,只有玩家抓得到(FishArea 管)

var _retarget := 0.0
var _bob := 0.0
var _hl_timer := 0.0
var _body: MeshInstance3D = null   # 占位方塊
var _model: Node3D = null
var _meshes: Array[MeshInstance3D] = []
var _anim: AnimationPlayer = null


func _ready() -> void:
    add_to_group("fish")
    var n := ModelLibrary.water_fish_count()
    var scene: PackedScene = null
    if n > 0:
        scene = ModelLibrary.water_fish(variant if variant >= 0 else randi() % n)
    if scene != null:
        _model = scene.instantiate() as Node3D
        add_child(_model)
        var box := ModelLibrary.scene_aabb(_model)
        var s := ModelLibrary.water_fish_length() / maxf(maxf(box.size.x, box.size.z), 0.01)
        var yaw := ModelLibrary.water_fish_yaw()
        _model.scale = Vector3(s, s, s)
        _model.rotation.y = yaw
        _model.position = Vector3(0, BODY_Y, 0) - Basis(Vector3.UP, yaw) * (box.get_center() * s)
        _meshes = ModelLibrary.mesh_instances(_model)
        _anim = ModelLibrary.find_anim(_model)
        if _anim != null and _anim.get_animation_list().size() > 0:
            var swim: String = _anim.get_animation_list()[0]
            _anim.get_animation(swim).loop_mode = Animation.LOOP_LINEAR
            _anim.speed_scale = randf_range(0.9, 1.4)
            _anim.play(swim)
            _anim.seek(randf() * _anim.get_animation(swim).length)
    else:
        _body = VisualFactory.box(GameData.item_size("fish"), GameData.item_color("fish"), Vector3(0, BODY_Y, 0))
        add_child(_body)
        add_child(VisualFactory.box(Vector3(0.12, 0.25, 0.22), GameData.item_color("fish").darkened(0.2), Vector3(0, BODY_Y, -0.42)))
    _bob = randf() * TAU
    _pick_target()
    if rare:
        _apply_gold()


## 金魚外觀:模型蓋一層金色 overlay(永久),方塊換金色發光材質
func _apply_gold() -> void:
    if _model != null:
        for mi in _meshes:
            mi.material_overlay = _gold_material()
    elif _body != null:
        _body.material_override = VisualFactory.material(Color(1.0, 0.85, 0.2), Color(1.0, 0.7, 0.1))


static func _gold_material() -> StandardMaterial3D:
    if _gold == null:
        _gold = StandardMaterial3D.new()
        _gold.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        _gold.albedo_color = Color(1.0, 0.8, 0.15, 0.7)
        _gold.emission_enabled = true
        _gold.emission = Color(1.0, 0.75, 0.1)
        _gold.emission_energy_multiplier = 1.8
    return _gold


func has_model() -> bool:
    return _model != null


func anim_playing() -> bool:
    return _anim != null and _anim.is_playing()


## 模型目前有沒有蓋著亮起的 overlay(測試用)
func overlay_on() -> bool:
    return not _meshes.is_empty() and _meshes[0].material_overlay != null


func random_point() -> Vector3:
    return Vector3(randf_range(rect.position.x, rect.end.x), 0.0, randf_range(rect.position.y, rect.end.y))


func _pick_target() -> void:
    target = random_point()
    _retarget = randf_range(1.0, 3.0)


## 亮起 0.25 秒(每幀被 FishArea 重新點亮就持續),沒人靠近自動熄
func set_highlight(on: bool) -> void:
    if rare:
        return   # 金魚一直是金色的
    if on:
        _hl_timer = 0.25
    if on == highlighted:
        return
    highlighted = on
    if _model != null:
        var mat: StandardMaterial3D = _overlay_material() if on else null
        for mi in _meshes:
            mi.material_overlay = mat
    elif _body != null:
        _body.material_override = VisualFactory.material(GameData.item_color("fish"),
                Color(0.9, 0.85, 0.2) if on else Color.BLACK)


static func _overlay_material() -> StandardMaterial3D:
    if _overlay == null:
        _overlay = StandardMaterial3D.new()
        _overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        _overlay.albedo_color = Color(1.0, 0.9, 0.25, 0.45)
        _overlay.emission_enabled = true
        _overlay.emission = Color(0.9, 0.8, 0.2)
        _overlay.emission_energy_multiplier = 1.2
    return _overlay


func _physics_process(delta: float) -> void:
    _retarget -= delta
    _bob += delta
    if highlighted:
        _hl_timer -= delta
        if _hl_timer <= 0.0:
            set_highlight(false)
    var d := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
    if _retarget <= 0.0 or d.length() < 0.3:
        _pick_target()
        return
    global_position += d.normalized() * minf(swim_speed * delta, d.length())
    global_position.y = sin(_bob * 2.0) * 0.04
    rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), minf(1.0, 6.0 * delta))
