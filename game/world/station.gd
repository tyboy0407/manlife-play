class_name Station
extends Node3D
## 工作站(切魚台 / 烤魚攤 / 服飾店):桌子 + 工人占位 + 輸入格(朝水邊,local -Z)+ 輸出格(local +Z)。規則在 StationLogic,
## 服飾店(stations.json tailor)收的是不佔背包的毛皮(StationPad 從 GameState.pelts 扣),5 張做一件毛衣。
## 兩個格子上各有一堆外觀(StackVisual,排 3 列)。工人有人物模型就在處理中播 interact-right(占位膠囊則上下動)。
## 速度與堆疊上限吃 GameState 的升級。
## 北極熊王咬滿 buildingBiteSec 秒會把它拆掉(wreck):桌子變廢墟、工人不見、兩個格子停用(堆裡的貨留著),
## 站上廢墟花 $200(shop.json repairStation)修好(repair);修復牌 = Harbor.repair_pad_for(spot_id),完好時藏著。

var def := {}
var spot_id := ""             # 關卡裡的位置 id(存檔用)
var level: Harbor = null
var logic: StationLogic
var input_pad: StationPad
var output_pad: StationPad
var input_pile: StackVisual        # 第一種原料的堆(多原料時 input_piles 每種一堆)
var output_pile: StackVisual
var input_pads := {}               # 原料 -> StationPad(多原料的工作站每種一格)
var input_piles := {}              # 原料 -> StackVisual
var worker: Node3D
var worker_model: CharacterModel = null   # 有人物模型時的工人(models.worker)
var ring: ProgressRing   # 工人頭上的處理進度環
var broken := false
var times_broken := 0
var times_repaired := 0

var _built: Node3D = null    # 桌子 + 工人(完好時)
var _rubble: Node3D = null   # 拆掉後的廢墟
var _work_anim := 0.0


static func create(station_def: Dictionary) -> Station:
    var s := Station.new()
    s.def = station_def
    s.name = "Station_%s" % str(station_def.get("id", "station"))
    return s


func _ready() -> void:
    add_to_group("station")
    logic = StationLogic.from_def(def)
    var kind := str(def.get("id", ""))
    var is_grill := kind == "grill"
    var is_tailor := kind == "tailor"
    var is_kitchen := kind == "kitchen"
    var table_color := Color(0.55, 0.3, 0.2) if is_grill else (Color(0.45, 0.38, 0.62) if is_tailor else (Color(0.5, 0.42, 0.36) if is_kitchen else Color(0.78, 0.55, 0.3)))
    _built = Node3D.new()
    _built.name = "Built"
    add_child(_built)
    _built.add_child(VisualFactory.box(Vector3(2.2, 0.9, 1.0), table_color, Vector3(0, 0.45, 0)))
    if is_grill:
        _built.add_child(VisualFactory.box(Vector3(1.6, 0.12, 0.7), Color(0.2, 0.2, 0.22), Vector3(0, 0.96, 0)))
        _built.add_child(VisualFactory.box(Vector3(1.2, 0.08, 0.4), Color(1.0, 0.45, 0.15), Vector3(0, 1.03, 0)))
    elif is_tailor:
        # 衣架(兩根柱子 + 橫桿)掛一件毛衣
        var rack := Color(0.35, 0.25, 0.15)
        _built.add_child(VisualFactory.box(Vector3(1.8, 0.06, 0.06), rack, Vector3(0, 1.75, 0)))
        for sx in [-0.8, 0.8]:
            _built.add_child(VisualFactory.box(Vector3(0.08, 0.85, 0.08), rack, Vector3(float(sx), 1.32, 0)))
        _built.add_child(VisualFactory.box(Vector3(0.7, 0.6, 0.16), GameData.item_color("sweater"), Vector3(0, 1.4, 0)))
    elif is_kitchen:
        # 廚房:桌上一口大鍋,鍋裡是湯的顏色
        _built.add_child(VisualFactory.cylinder(0.5, 0.55, Color(0.3, 0.3, 0.33), Vector3(0, 1.17, 0)))
        _built.add_child(VisualFactory.cylinder(0.42, 0.06, GameData.item_color("soup"), Vector3(0, 1.45, 0)))
        _built.add_child(VisualFactory.box(Vector3(0.08, 0.5, 0.08), Color(0.35, 0.25, 0.15), Vector3(0.45, 1.6, -0.3)))
    else:
        _built.add_child(VisualFactory.box(Vector3(0.9, 0.5, 0.06), Color(0.6, 0.6, 0.65), Vector3(0, 1.15, 0)))
    add_child(VisualFactory.label(tr(display_name_key()), Vector3(0, 2.4, 0), 44, Color(1.0, 0.95, 0.8)))
    # 工人(桌子後面,面向桌子)
    worker = Node3D.new()
    worker.position = Vector3(0, 0, 1.1)
    worker.rotation.y = PI
    _built.add_child(worker)
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
    # 廢墟:歪掉的桌板、斷腳、碎木
    _rubble = Node3D.new()
    _rubble.name = "Rubble"
    var dark := table_color.darkened(0.35)
    var top := VisualFactory.box(Vector3(2.0, 0.16, 0.9), dark, Vector3(0.2, 0.3, 0.1))
    top.rotation = Vector3(0.12, 0.35, -0.3)
    _rubble.add_child(top)
    var leg := VisualFactory.box(Vector3(0.18, 0.7, 0.18), dark.darkened(0.2), Vector3(-0.9, 0.2, -0.3))
    leg.rotation = Vector3(0.0, 0.3, 1.1)
    _rubble.add_child(leg)
    _rubble.add_child(VisualFactory.box(Vector3(0.5, 0.12, 0.3), dark.darkened(0.3), Vector3(0.8, 0.06, -0.5)))
    _rubble.add_child(VisualFactory.box(Vector3(0.35, 0.1, 0.5), dark.darkened(0.1), Vector3(-0.4, 0.05, 0.6)))
    _rubble.visible = false
    add_child(_rubble)
    # 格子
    # 輸入格:每種原料一格,排在桌子北邊(單原料在正中、兩種各偏 1.3)
    var n_in := logic.inputs.size()
    for i in n_in:
        var item: String = logic.inputs[i]
        var pad := StationPad.new()
        pad.name = "InputPad" if i == 0 else "InputPad_%s" % item
        pad.station = self
        pad.mode = "input"
        pad.item = item
        pad.color = Color(0.3, 0.26, 0.22)
        pad.label_text = "%s\n%s" % [tr("PAD_INPUT"), GameData.item_name(item)]
        pad.position = Vector3((float(i) - float(n_in - 1) / 2.0) * 2.6, 0, -2.2)
        add_child(pad)
        input_pads[item] = pad
        if i == 0:
            input_pad = pad
    output_pad = StationPad.new()
    output_pad.name = "OutputPad"
    output_pad.station = self
    output_pad.mode = "output"
    output_pad.color = Color(0.26, 0.3, 0.26)
    output_pad.label_text = "%s\n%s" % [tr("PAD_OUTPUT"), GameData.item_name(logic.output_id)]
    output_pad.position = Vector3(0, 0, 2.2)
    add_child(output_pad)
    for item in logic.inputs:
        var pile := StackVisual.new()
        pile.columns = 3
        pile.position = (input_pads[item] as Node3D).position + Vector3(0, 0.1, 0)
        add_child(pile)
        input_piles[item] = pile
        if input_pile == null:
            input_pile = pile
    output_pile = StackVisual.new()
    output_pile.columns = 3
    output_pile.position = Vector3(0, 0.1, 2.2)
    add_child(output_pile)
    apply_upgrades()
    GameState.changed.connect(apply_upgrades)
    refresh_piles()


## 顯示名稱的翻譯鍵(STATION_cutting_table / STATION_grill)
func display_name_key() -> String:
    return str(def.get("name", "STATION_%s" % str(def.get("id", ""))))


## 工人速度 / 堆疊上限升級(GameState.changed 時重算)
func apply_upgrades() -> void:
    logic.speed_mult = GameState.upgrade_mult("worker_speed")
    var m := GameState.upgrade_mult("pile_cap")
    logic.input_cap = maxi(int(round(float(def.get("inputCap", 12)) * m)), 1)
    logic.output_cap = maxi(int(round(float(def.get("outputCap", 24)) * m)), 1)


func _physics_process(delta: float) -> void:
    if broken:
        return
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
    for item in input_piles:
        (input_piles[item] as StackVisual).show_items(str(item), logic.input_count_of(str(item)))
    output_pile.show_items(logic.output_id, logic.output_count)


## 輸入 / 輸出堆的頂端(世界座標),飛行動畫用(輸入 = 第一種原料)
func pile_top(is_input: bool) -> Vector3:
    var pile := input_pile if is_input else output_pile
    return pile.global_position + Vector3(0.0, pile.top_height(), 0.0)


## 某種原料的堆頂
func pile_top_for(item: String) -> Vector3:
    var pile: StackVisual = input_piles.get(item, input_pile)
    return pile.global_position + Vector3(0.0, pile.top_height(), 0.0)


## 收 item 的輸入格(沒這種原料就回第一格)
func input_pad_for(item: String) -> StationPad:
    return input_pads.get(item, input_pad)


## 搬運工把送不出去的成品放回輸出堆;回傳收下幾個
func take_back(n: int) -> int:
    var accepted := mini(maxi(n, 0), logic.output_cap - logic.output_count)
    if accepted > 0:
        logic.output_count += accepted
        refresh_piles()
    return accepted


## --- 拆 / 修 ---

func is_broken() -> bool:
    return broken


## 北極熊王把它拆了:停工、廢墟、格子停用;Harbor.station_destroyed 開修復牌。回傳是否真的拆了(已經是廢墟回 false)
func wreck(by: Node3D) -> bool:
    if broken:
        return false
    set_broken(true)
    times_broken += 1
    EventBus.station_destroyed.emit(self, by)
    if level != null:
        level.station_destroyed(self, by)
    return true


## 修好:桌子與工人回來、格子恢復(silent = 存檔還原不發事件)
func repair(silent: bool = false) -> void:
    if not broken:
        return
    set_broken(false)
    times_repaired += 1
    if not silent:
        EventBus.station_repaired.emit(self)


## 只切外觀與格子狀態(存檔還原用,不發事件、不動修復牌)
func set_broken(b: bool) -> void:
    broken = b
    if _built != null:
        _built.visible = not b
    if _rubble != null:
        _rubble.visible = b
    if ring != null and b:
        ring.visible = false
    if b and logic != null:
        logic.processing = false
        logic.progress = 0.0
    var pads: Array = input_pads.values()
    pads.append(output_pad)
    for pad in pads:
        if pad != null:
            pad.set_deferred("monitoring", not b)
            pad.set_physics_process(not b)
            pad.visible = not b
