class_name Station
extends Node3D
## 工作站(切魚台 / 烤魚攤):桌子 + 工人占位 + 輸入格(朝水邊,local -Z)+ 輸出格(local +Z)。規則在 StationLogic,
## 兩個格子上各有一堆外觀(StackVisual,排 3 列)。工人有人物模型就在處理中播 interact-right(占位膠囊則上下動)。
## 速度與堆疊上限吃 GameState 的升級。

var def := {}
var spot_id := ""             # 關卡裡的位置 id(存檔用)
var logic: StationLogic
var input_pad: StationPad
var output_pad: StationPad
var input_pile: StackVisual
var output_pile: StackVisual
var worker: Node3D
var worker_model: CharacterModel = null   # 有人物模型時的工人(models.worker)
var ring: ProgressRing   # 工人頭上的處理進度環
var _work_anim := 0.0


static func create(station_def: Dictionary) -> Station:
    var s := Station.new()
    s.def = station_def
    s.name = "Station_%s" % str(station_def.get("id", "station"))
    return s


func _ready() -> void:
    add_to_group("station")
    logic = StationLogic.from_def(def)
    var is_grill := str(def.get("id", "")) == "grill"
    var table_color := Color(0.55, 0.3, 0.2) if is_grill else Color(0.78, 0.55, 0.3)
    add_child(VisualFactory.box(Vector3(2.2, 0.9, 1.0), table_color, Vector3(0, 0.45, 0)))
    if is_grill:
        add_child(VisualFactory.box(Vector3(1.6, 0.12, 0.7), Color(0.2, 0.2, 0.22), Vector3(0, 0.96, 0)))
        add_child(VisualFactory.box(Vector3(1.2, 0.08, 0.4), Color(1.0, 0.45, 0.15), Vector3(0, 1.03, 0)))
    else:
        add_child(VisualFactory.box(Vector3(0.9, 0.5, 0.06), Color(0.6, 0.6, 0.65), Vector3(0, 1.15, 0)))
    add_child(VisualFactory.label(tr(str(def.get("name", "STATION_%s" % str(def.get("id", ""))))), Vector3(0, 2.4, 0), 44, Color(1.0, 0.95, 0.8)))
    # 工人(桌子後面,面向桌子)
    worker = Node3D.new()
    worker.position = Vector3(0, 0, 1.1)
    worker.rotation.y = PI
    add_child(worker)
    var scene := ModelLibrary.character(ModelLibrary.worker_model())
    if scene != null:
        worker_model = CharacterModel.create(scene, ModelLibrary.character_height() * 0.95)
        worker.add_child(worker_model)
    else:
        worker.add_child(VisualFactory.capsule(0.35, 1.4, Color(0.45, 0.3, 0.2), Vector3(0, 0.8, 0)))
        worker.add_child(VisualFactory.box(Vector3(0.55, 0.2, 0.55), Color(0.3, 0.2, 0.12), Vector3(0, 1.62, 0)))
    ring = ProgressRing.new()
    ring.inner = 0.28
    ring.outer = 0.4
    ring.color = Color(0.45, 0.9, 1.0)
    ring.bg_color = Color(0.1, 0.1, 0.14, 0.6)
    ring.position = Vector3(0, 2.1, 1.1)
    ring.visible = false
    add_child(ring)
    # 格子
    input_pad = StationPad.new()
    input_pad.station = self
    input_pad.mode = "input"
    input_pad.color = Color(0.3, 0.26, 0.22)
    input_pad.label_text = "%s\n%s" % [tr("PAD_INPUT"), GameData.item_name(logic.input_id)]
    input_pad.position = Vector3(0, 0, -2.2)
    add_child(input_pad)
    output_pad = StationPad.new()
    output_pad.station = self
    output_pad.mode = "output"
    output_pad.color = Color(0.26, 0.3, 0.26)
    output_pad.label_text = "%s\n%s" % [tr("PAD_OUTPUT"), GameData.item_name(logic.output_id)]
    output_pad.position = Vector3(0, 0, 2.2)
    add_child(output_pad)
    input_pile = StackVisual.new()
    input_pile.columns = 3
    input_pile.position = Vector3(0, 0.1, -2.2)
    add_child(input_pile)
    output_pile = StackVisual.new()
    output_pile.columns = 3
    output_pile.position = Vector3(0, 0.1, 2.2)
    add_child(output_pile)
    apply_upgrades()
    GameState.changed.connect(apply_upgrades)
    refresh_piles()


## 工人速度 / 堆疊上限升級(GameState.changed 時重算)
func apply_upgrades() -> void:
    logic.speed_mult = GameState.upgrade_mult("worker_speed")
    var m := GameState.upgrade_mult("pile_cap")
    logic.input_cap = maxi(int(round(float(def.get("inputCap", 12)) * m)), 1)
    logic.output_cap = maxi(int(round(float(def.get("outputCap", 24)) * m)), 1)


func _physics_process(delta: float) -> void:
    var made := logic.tick(delta)
    if made > 0:
        refresh_piles()
        EventBus.items_processed.emit(logic.id, made)
    ring.visible = logic.is_working()
    if logic.is_working():
        ring.set_progress(logic.work_progress())
        if worker_model != null:
            worker_model.set_action("interact-right", true, clampf(logic.speed_mult, 0.8, 2.5))
        else:
            _work_anim += delta * 12.0 * logic.speed_mult
            worker.position.y = absf(sin(_work_anim)) * 0.12
    elif worker_model != null:
        worker_model.clear_action()
        worker_model.set_moving(0.0)
    else:
        worker.position.y = lerpf(worker.position.y, 0.0, minf(1.0, 8.0 * delta))


func refresh_piles() -> void:
    input_pile.show_items(logic.input_id, logic.input_count)
    output_pile.show_items(logic.output_id, logic.output_count)


## 輸入 / 輸出堆的頂端(世界座標),飛行動畫用
func pile_top(is_input: bool) -> Vector3:
    var pile := input_pile if is_input else output_pile
    return pile.global_position + Vector3(0.0, pile.top_height(), 0.0)


## 搬運工把送不出去的成品放回輸出堆;回傳收下幾個
func take_back(n: int) -> int:
    var accepted := mini(maxi(n, 0), logic.output_cap - logic.output_count)
    if accepted > 0:
        logic.output_count += accepted
        refresh_piles()
    return accepted
