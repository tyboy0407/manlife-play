class_name Bait
extends Node3D
## 誘餌魚堆(shop.json bait_n,牌子就是放誘餌的位置,Harbor.BAIT_SPOTS):買了就放好(placed),
## lure_radius 內的熊(王也是)會改去吃它(Bear._nearest_bait),咬滿 eat_sec 秒就吃光(Bear._eat -> consume -> Harbor.bait_eaten,牌子重新出現)。
## 吃誘餌的熊站著不動,正好給守衛塔射、玩家打。沒有物理;外觀:木盆 + 一堆魚(StackVisual)。存檔 world.baits{id: placed}。

var id := ""
var level: Harbor = null
var logic: TrapLogic = null
var placed := false
var lure_radius := 8.0
var eat_sec := 10.0
var eaten_total := 0

var _pile: StackVisual = null
var _bowl: Node3D = null


func _ready() -> void:
    add_to_group("bait")
    if logic == null:
        logic = TrapLogic.from_config(GameData.section("trap"))
    lure_radius = logic.bait_radius()
    eat_sec = logic.bait_eat_sec()
    _bowl = Node3D.new()
    _bowl.name = "Bowl"
    add_child(_bowl)
    var wood := Color(0.6, 0.42, 0.26)
    _bowl.add_child(VisualFactory.cylinder(1.0, 0.12, wood.darkened(0.2), Vector3(0, 0.06, 0)))
    _bowl.add_child(VisualFactory.cylinder(0.85, 0.1, wood, Vector3(0, 0.17, 0)))
    _pile = StackVisual.new()
    _pile.columns = 3
    _pile.position = Vector3(0, 0.24, 0)
    add_child(_pile)
    _apply_state()


func is_set() -> bool:
    return placed


## 放好誘餌(silent = 存檔還原)
func place(_silent: bool = false) -> void:
    placed = true
    _apply_state()


## 被熊吃光
func consume(by: Node3D) -> void:
    if not placed:
        return
    placed = false
    eaten_total += 1
    _apply_state()
    EventBus.bait_eaten.emit(self, by)
    if level != null:
        level.bait_eaten(self, by)


func _apply_state() -> void:
    if _bowl != null:
        _bowl.visible = placed
    if _pile != null:
        _pile.show_items("fish", logic.bait_fish_count() if placed else 0)


func snapshot() -> Dictionary:
    return {"placed": placed}


func restore(d: Dictionary) -> void:
    placed = bool(d.get("placed", false))
    _apply_state()
