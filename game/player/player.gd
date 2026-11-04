class_name Player
extends Carrier
## 玩家:輸入來自 MoveInput(鍵盤 / 手把;測試可指定 input_provider 餵合成輸入;之後加觸控搖桿)。
## 背包容量 = 設定值 + GameState 的擴充。武器(GameState.weapon_level)掛在右側腰間:weapon.levels[等級-1].model,沒模型就木棒占位。
## 攻擊:有武器時每 attackIntervalSec 自動打離自己最近、在 range 內的北極熊一下(damage 看等級),揮一下 attack-melee-right。

var input_provider: Callable = Callable()
var weapon_prop: Node3D = null
var hits_total := 0
var busy_with_bear := false   # 有武器且熊在 busyRadius 內:暫停抓魚 / 拿貨

var _weapon_shown := 0
var _attack_timer := 0.0
var _bear_logic: BearLogic = null


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
    stack.set_capacity(int(GameData.config().get("carryCapacity", 8)) + GameState.total_capacity_bonus())


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
    _attack(delta)


## 帶著武器靠近北極熊就自動攻擊(跟格子一樣不用按鍵)
func _attack(delta: float) -> void:
    _attack_timer = maxf(_attack_timer - delta, 0.0)
    var lv := GameState.weapon_level
    if _bear_logic == null:
        _bear_logic = BearLogic.from_config(GameData.section("bear"), GameData.section("weapon"))
    var best: Bear = null
    var best_d := INF
    if lv > 0:
        for n in get_tree().get_nodes_in_group("bear"):
            var b := n as Bear
            if b == null or not b.alive():
                continue
            var d := b.planar_distance_to(global_position)
            if d < best_d:
                best_d = d
                best = b
    # 帶著武器、熊就在附近:專心打熊,穿過水區 / 輸出格不順手抓魚拿貨(免得背包被塞滿)
    busy_with_bear = best != null and best_d <= _bear_logic.busy_radius()
    can_fish = not busy_with_bear
    takes_output = not busy_with_bear
    if lv <= 0 or _attack_timer > 0.0:
        return
    if best == null or not _bear_logic.can_attack(lv, best_d):
        return
    _attack_timer = _bear_logic.attack_interval()
    hits_total += 1
    if model != null:
        model.set_action("attack-melee-right", false, 1.4)
    best.take_hit(_bear_logic.weapon_damage(lv), self)
