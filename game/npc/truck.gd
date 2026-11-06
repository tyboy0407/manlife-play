class_name Truck
extends Node3D
## 雪地貨車(shop.json truck,牌在 Harbor.GARAGE_SPOT 也是停車位):漁夫開車,沿 Harbor.truck_route 的路線出村到野外的魚池(Harbor.ponds),
## 停在岸邊每 catchSec 撈一條(FishArea.take_nearest),載滿 capacity(30)條或池子空太久就開回來,停在放置區旁把魚卸進 FishDepot(每秒 unloadPerSec 條),
## 放置區滿了就等。沒有物理(路線避開建築就好)。規則在 TruckLogic;存檔記車上的魚數(回來時停在車庫重新出發)。

var level: Harbor = null
var logic: TruckLogic = null
var fish := 0
var state := "idle"          # idle / to_pond / fishing / to_depot / unloading
var pond_index := -1
var trips := 0
var caught_total := 0
var unloaded_total := 0

var _path: Array[Vector3] = []
var _wp := 0
var _idle_t := 1.5
var _catch_t := 0.0
var _empty_t := 0.0
var _unload_acc := 0.0
var _wait_full := 0.0
var _pile: StackVisual
var _wheels: Array[MeshInstance3D] = []
var _driver: CharacterModel = null


func _ready() -> void:
    add_to_group("truck")
    if logic == null:
        logic = TruckLogic.from_config(GameData.section("truck"))
    var paint := Color(0.3, 0.45, 0.8)
    var dark := Color(0.15, 0.15, 0.18)
    add_child(VisualFactory.box(Vector3(1.4, 0.5, 2.6), paint.darkened(0.25), Vector3(0, 0.55, 0)))        # 底盤
    add_child(VisualFactory.box(Vector3(1.4, 0.5, 1.4), paint, Vector3(0, 0.85, -0.6)))                   # 貨斗(後)
    add_child(VisualFactory.box(Vector3(1.3, 0.1, 1.3), Color(0.6, 0.45, 0.3), Vector3(0, 1.12, -0.6)))   # 貨斗底板
    add_child(VisualFactory.box(Vector3(1.3, 1.0, 1.0), paint.lightened(0.1), Vector3(0, 1.2, 0.75)))     # 駕駛艙(前)
    add_child(VisualFactory.box(Vector3(1.1, 0.5, 0.08), Color(0.7, 0.85, 1.0), Vector3(0, 1.35, 1.27)))  # 擋風玻璃
    for x in [-0.72, 0.72]:
        for z in [-0.85, 0.85]:
            var w := VisualFactory.cylinder(0.3, 0.26, dark, Vector3(float(x), 0.3, float(z)))
            w.rotation.z = PI / 2.0
            add_child(w)
            _wheels.append(w)
    # 漁夫坐在駕駛艙裡(只露上半身)
    var scene := ModelLibrary.character(ModelLibrary.role_model("fisher"))
    if scene != null:
        _driver = CharacterModel.create(scene, ModelLibrary.character_height() * 0.9)
        _driver.position = Vector3(0, 0.75, 0.6)
        add_child(_driver)
    _pile = StackVisual.new()
    _pile.columns = 3
    _pile.position = Vector3(0, 1.18, -0.6)
    add_child(_pile)
    add_child(VisualFactory.label(tr("TRUCK_LABEL"), Vector3(0, 2.4, 0), 38, Color(0.85, 0.92, 1.0)))
    add_child(VisualFactory.blob_shadow(1.0, Settings.is_smooth()))
    _refresh_pile()


func _refresh_pile() -> void:
    _pile.show_items("fish", fish)


func stack_top() -> Vector3:
    return _pile.global_position + Vector3(0.0, _pile.top_height(), 0.0)


func _physics_process(delta: float) -> void:
    if level == null:
        return
    match state:
        "to_pond":
            if _follow(delta):
                state = "fishing"
                _catch_t = 0.0
                _empty_t = 0.0
        "fishing":
            _catch_t -= delta
            if _catch_t <= 0.0:
                _catch_t = logic.catch_sec()
                var pond: FishArea = level.ponds[pond_index] if pond_index >= 0 and pond_index < level.ponds.size() else null
                if pond != null and not logic.is_full(fish) and pond.take_nearest(global_position, stack_top()):
                    fish += 1
                    caught_total += 1
                    _empty_t = 0.0
                    _refresh_pile()
                else:
                    _empty_t += logic.catch_sec()
            if logic.should_return(fish, _empty_t):
                _path = level.truck_route(pond_index, false)
                _wp = 0
                state = "to_depot"
        "to_depot":
            if _follow(delta):
                state = "unloading"
                _unload_acc = 0.0
                _wait_full = 0.0
        "unloading":
            if fish <= 0:
                trips += 1
                state = "idle"
                _idle_t = 1.5
                return
            _unload_acc += logic.unload_per_sec() * delta
            var n := int(floor(_unload_acc))
            if n <= 0:
                return
            _unload_acc -= float(n)
            var accepted := level.depot.receive(mini(n, fish)) if level.depot != null else 0
            if accepted > 0:
                fish -= accepted
                unloaded_total += accepted
                _refresh_pile()
                EventBus.items_moved.emit("to_station", "fish", stack_top(), level.depot.pile_top(false), accepted)
            else:
                _wait_full += delta   # 放置區滿了:等
        _:
            _idle_t -= delta
            if _idle_t > 0.0 or level.ponds.is_empty():
                return
            pond_index = TruckLogic.pick_pond(level.pond_counts(), pond_index)
            _path = level.truck_route(pond_index, true)
            _wp = 0
            state = "to_pond"


## 沿路線開;到終點回 true
func _follow(delta: float) -> bool:
    if _wp >= _path.size():
        return true
    var p := _path[_wp]
    var d := Vector3(p.x - global_position.x, 0.0, p.z - global_position.z)
    var dist := d.length()
    if dist < 0.4:
        _wp += 1
        return _wp >= _path.size()
    var step := minf(logic.speed() * delta, dist)
    global_position += d / dist * step
    rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), minf(1.0, 8.0 * delta))
    for w in _wheels:
        w.rotation.x += step * 3.0
    return false


func is_driving() -> bool:
    return state == "to_pond" or state == "to_depot"


func snapshot() -> Dictionary:
    return {"fish": fish, "trips": trips}


func restore(d: Dictionary) -> void:
    fish = clampi(int(d.get("fish", 0)), 0, logic.capacity())
    trips = maxi(int(d.get("trips", 0)), 0)
    _refresh_pile()
    state = "unloading" if fish > 0 else "idle"   # 車上有魚就先卸到放置區
