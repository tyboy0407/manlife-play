class_name Trap
extends Node3D
## 捕熊夾(shop.json trap_n,牌子就是放夾子的位置,Harbor.TRAP_SPOTS):買了就放好(armed),
## 活著的熊走進 TrapLogic.radius 內就夾到:扣血(Bear.take_hit)、定住(Bear.stun)幾秒,夾子用掉(Harbor.trap_used -> 牌子重新出現,同價)。
## 沒有物理;外觀:底板 + 兩片張開的夾齒。存檔 world.traps{id: armed}。

var id := ""
var level: Harbor = null
var logic: TrapLogic = null
var armed := false
var triggers_total := 0

var _jaws: Node3D = null
var _plate: MeshInstance3D = null


func _ready() -> void:
    add_to_group("trap")
    if logic == null:
        logic = TrapLogic.from_config(GameData.section("trap"))
    var steel := Color(0.45, 0.47, 0.52)
    _plate = VisualFactory.cylinder(0.9, 0.08, steel.darkened(0.3), Vector3(0, 0.04, 0))
    add_child(_plate)
    _jaws = Node3D.new()
    _jaws.name = "Jaws"
    add_child(_jaws)
    for side in [-1.0, 1.0]:
        var jaw := VisualFactory.box(Vector3(1.6, 0.1, 0.5), steel, Vector3(0, 0.3, float(side) * 0.55))
        jaw.rotation.x = float(side) * -0.9
        _jaws.add_child(jaw)
        for i in 5:
            var tooth := VisualFactory.box(Vector3(0.12, 0.28, 0.12), steel.lightened(0.15), Vector3(-0.6 + float(i) * 0.3, 0.5, float(side) * 0.78))
            tooth.rotation.x = float(side) * -0.9
            _jaws.add_child(tooth)
    _jaws.add_child(VisualFactory.cylinder(0.2, 0.3, Color(0.8, 0.2, 0.15), Vector3(0, 0.15, 0)))   # 中間的紅色踏板
    _apply_state()


func is_armed() -> bool:
    return armed


## 放好夾子(silent = 存檔還原,不發事件)
func arm(_silent: bool = false) -> void:
    armed = true
    _apply_state()


func _apply_state() -> void:
    if _jaws != null:
        _jaws.visible = armed
    if _plate != null:
        _plate.visible = armed
    set_physics_process(armed)


func _physics_process(_delta: float) -> void:
    if not armed:
        return
    for b in get_tree().get_nodes_in_group("bear"):
        var bear := b as Bear
        if bear != null and bear.alive() and TrapLogic.in_reach(global_position, bear.global_position, logic.radius()):
            trigger(bear)
            return


## 夾到熊:扣血、定住,夾子用掉
func trigger(bear: Bear) -> void:
    if not armed or bear == null or not is_instance_valid(bear):
        return
    armed = false
    triggers_total += 1
    _apply_state()
    logic.ice = GameState.is_unlocked("ice_traps")   # 熊王祭壇解鎖冰封夾:所有夾子一起變強
    var dmg := logic.damage(bear.is_king)
    bear.stun(logic.stun_sec())
    bear.take_hit(dmg, self)
    EventBus.trap_triggered.emit(self, bear)
    if level != null:
        level.trap_used(self, bear)


func snapshot() -> Dictionary:
    return {"armed": armed}


func restore(d: Dictionary) -> void:
    armed = bool(d.get("armed", false))
    _apply_state()
