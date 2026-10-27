class_name Player
extends Carrier
## 玩家:輸入來自 MoveInput(鍵盤 / 手把;測試可指定 input_provider 餵合成輸入;之後加觸控搖桿)。
## 背包容量 = 設定值 + GameState 的擴充。武器(GameState.weapon_level)掛在右側腰間:weapon.levels[等級-1].model,沒模型就木棒占位。

var input_provider: Callable = Callable()
var weapon_prop: Node3D = null

var _weapon_shown := 0


func _ready() -> void:
    color = Color(0.35, 0.55, 0.95)
    model_name = ModelLibrary.player_model()
    super()
    add_to_group("player")
    can_serve = true
    can_use_trash = true
    speed = float(GameData.config().get("playerSpeed", 6.0))
    accel = float(GameData.config().get("playerAccel", 40.0))
    _refresh_capacity()
    _refresh_weapon()
    GameState.changed.connect(_refresh_capacity)
    GameState.changed.connect(_refresh_weapon)


func _refresh_capacity() -> void:
    stack.set_capacity(int(GameData.config().get("carryCapacity", 8)) + GameState.capacity_bonus)


## 武器等級變了就換腰間的模型(等比例縮到 model.length 高;沒模型就木棒 + 鐵頭占位)
func _refresh_weapon() -> void:
    var lv := GameState.weapon_level
    if lv == _weapon_shown and (weapon_prop != null or lv == 0):
        return
    _weapon_shown = lv
    if weapon_prop != null:
        weapon_prop.queue_free()
        weapon_prop = null
    if lv <= 0:
        return
    var m := BearLogic.from_config({}, GameData.section("weapon")).weapon_model(lv)
    weapon_prop = Node3D.new()
    weapon_prop.name = "Weapon"
    var scene := ModelLibrary.prop(str(m.get("file", "")))
    if scene != null:
        var inst := scene.instantiate() as Node3D
        var box := ModelLibrary.scene_aabb(inst)
        var s := float(m.get("length", 0.9)) / maxf(box.size.y, 0.01)
        inst.scale = Vector3(s, s, s)
        inst.position = -box.get_center() * s
        weapon_prop.add_child(inst)
    else:
        weapon_prop.add_child(VisualFactory.box(Vector3(0.08, 0.9, 0.08), Color(0.45, 0.3, 0.18)))
        weapon_prop.add_child(VisualFactory.box(Vector3(0.3, 0.2, 0.08), Color(0.6, 0.62, 0.66), Vector3(-0.1, 0.35, 0)))
    weapon_prop.position = Vector3(0.52, 0.8, 0.0)
    weapon_prop.rotation = Vector3(0.0, 0.0, -0.35)
    add_child(weapon_prop)


func _physics_process(delta: float) -> void:
    var mi: MoveInput = input_provider.call() if input_provider.is_valid() else MoveInput.from_actions()
    move_toward_dir(mi.world_dir(), delta)
