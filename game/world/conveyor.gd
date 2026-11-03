class_name Conveyor
extends Node3D
## 傳送帶(shop.json belt_<工作站>,Harbor.CONVEYORS 定路線):從工作站的輸出格架到同種貨櫃台的上架格,架高 height 讓人從底下走;
## 規則在 ConveyorLogic(每秒拿一件、件件前進、櫃台滿了就在末端排隊)。沒有物理。外觀:帶面 + 支架 + 帶上的貨(物品模型或方塊)。
## 存檔 world.belts{id: [每件位置]}。工作站被王拆了(is_broken)帶子就停。

var id := ""
var level: Harbor = null
var station: Station = null
var counter: Counter = null
var logic: ConveyorLogic = null
var height := 1.3
var length := 5.0

var _dir := Vector3.FORWARD
var _item_nodes: Array[Node3D] = []
var _item_size := Vector3(0.5, 0.15, 0.4)
var _belt: Node3D = null
var _stripes: Array[MeshInstance3D] = []
var _stripe_t := 0.0


## 架在 a(工作站輸出格)到 b(櫃台上架格)之間;要在加進場景樹之前呼叫
func setup(belt_id: String, from: Station, to: Counter) -> void:
    id = belt_id
    station = from
    counter = to
    var a := from.global_position + Vector3(0, 0, 2.2)
    var b := to.global_position + Vector3(-2.2, 0, 0)
    position = a
    var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
    length = maxf(d.length(), 0.5)
    _dir = d / length
    var cfg := GameData.section("conveyor")
    height = maxf(float(cfg.get("height", 1.3)), 0.3)
    logic = ConveyorLogic.from_config(cfg, length)


func _ready() -> void:
    add_to_group("conveyor")
    if logic == null:
        logic = ConveyorLogic.from_config(GameData.section("conveyor"), length)
    _build_visual()


func _build_visual() -> void:
    _belt = Node3D.new()
    _belt.name = "Belt"
    _belt.rotation.y = atan2(_dir.x, _dir.z)
    add_child(_belt)
    var dark := Color(0.22, 0.22, 0.25)
    var frame := Color(0.5, 0.5, 0.55)
    _belt.add_child(VisualFactory.box(Vector3(0.7, 0.08, length), frame, Vector3(0, height - 0.06, length / 2.0)))
    _belt.add_child(VisualFactory.box(Vector3(0.56, 0.06, length), dark, Vector3(0, height, length / 2.0)))
    for side in [-0.33, 0.33]:
        _belt.add_child(VisualFactory.box(Vector3(0.06, 0.16, length), frame, Vector3(float(side), height + 0.02, length / 2.0)))
    var legs := maxi(int(floor(length / 2.5)), 1) + 1
    for i in legs:
        var z := clampf(0.6 + float(i) * (length - 1.2) / maxf(float(legs - 1), 1.0), 0.3, length - 0.3)
        for side in [-0.28, 0.28]:
            _belt.add_child(VisualFactory.box(Vector3(0.1, height, 0.1), frame.darkened(0.2), Vector3(float(side), height / 2.0, z)))
    # 帶面上的橫紋(會往前跑,看得出方向)
    var n := maxi(int(floor(length / 0.8)), 1)
    for i in n:
        var s := VisualFactory.box(Vector3(0.5, 0.02, 0.08), Color(0.4, 0.4, 0.45), Vector3(0, height + 0.04, float(i) * 0.8))
        _belt.add_child(s)
        _stripes.append(s)


func _physics_process(delta: float) -> void:
    if station == null or counter == null or not is_instance_valid(station) or not is_instance_valid(counter):
        return
    var source := station.logic.output_count if not station.is_broken() else 0
    var res := logic.tick(delta, source, counter.logic.space())
    var taken := int(res.get("taken", 0))
    var delivered := int(res.get("delivered", 0))
    if taken > 0:
        station.logic.take_output(taken)
        station.refresh_piles()
    if delivered > 0:
        counter.logic.add_stock(delivered)
        counter.refresh_pile()
        EventBus.items_moved.emit("belt", counter.logic.item_id, global_position + _dir * length + Vector3(0, height, 0), counter.pile_top(), delivered)
    _update_items()
    if not logic.is_empty():
        _stripe_t = fmod(_stripe_t + logic.speed * delta, 0.8)
        for i in _stripes.size():
            _stripes[i].position.z = fmod(float(i) * 0.8 + _stripe_t, maxf(length, 0.8))


func _update_items() -> void:
    var item := station.logic.output_id
    while _item_nodes.size() < logic.count():
        _item_nodes.append(_make_item(item))
    for i in _item_nodes.size():
        var node := _item_nodes[i]
        if i < logic.count():
            node.visible = true
            node.position = Vector3(0, height + 0.03 + _item_size.y / 2.0, logic.items[i])
        else:
            node.visible = false


func _make_item(item: String) -> Node3D:
    _item_size = GameData.item_size(item)
    var holder := Node3D.new()
    var mesh := ModelLibrary.item_mesh(item)
    if mesh != null:
        var mi := MeshInstance3D.new()
        mi.mesh = mesh
        mi.transform = ModelLibrary.item_fit(item)
        holder.add_child(mi)
    else:
        holder.add_child(VisualFactory.box(_item_size, GameData.item_color(item)))
    holder.visible = false
    _belt.add_child(holder)
    return holder


func snapshot() -> Array:
    return logic.snapshot()


func restore(positions: Array) -> void:
    logic.restore(positions)
    _update_items()
