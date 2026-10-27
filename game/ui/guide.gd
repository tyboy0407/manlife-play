class_name Guide
extends Node3D
## 引導:教學階段(新存檔)照 GuideLogic 的步驟指路,之後當提示(GameState.hints_on,H 鍵開關)。
## 外觀:玩家頭上一支小箭頭轉向目標 + 目標上方一支上下彈跳、慢慢旋轉的大箭頭;HUD 顯示目標文字。
## 每 0.1 秒從關卡抓一次狀態字典餵 GuideLogic;純表現層,只改教學進度(GameState.tutorial_step)。

const GOLD := Color(1.0, 0.82, 0.25)
const REFRESH_SEC := 0.1
const NEAR := 1.6

var level: Harbor = null
var current := {}            # 目前的提示 {"kind", "target", "text", "arg"}
var target_pos := Vector3.ZERO
var has_target := false
var in_tutorial := false
var marker: Node3D
var head_arrow: Node3D

var _timer := 0.0
var _t := 0.0


func _ready() -> void:
    var mat := VisualFactory.material(GOLD, Color(0.6, 0.45, 0.1))
    marker = Node3D.new()
    marker.name = "Marker"
    add_child(marker)
    var tip := VisualFactory.cone(0.45, 0.8, GOLD, Vector3(0, 0.4, 0))
    tip.rotation.x = PI
    tip.material_override = mat
    marker.add_child(tip)
    var shaft := VisualFactory.cylinder(0.16, 0.7, GOLD, Vector3(0, 1.15, 0))
    shaft.material_override = mat
    marker.add_child(shaft)
    head_arrow = Node3D.new()
    head_arrow.name = "HeadArrow"
    add_child(head_arrow)
    var head_tip := VisualFactory.cone(0.22, 0.45, GOLD, Vector3(0, 0, -0.38))
    head_tip.rotation.x = -PI / 2.0
    head_tip.material_override = mat
    head_arrow.add_child(head_tip)
    var head_shaft := VisualFactory.cylinder(0.08, 0.4, GOLD, Vector3(0, 0, 0.05))
    head_shaft.rotation.x = PI / 2.0
    head_shaft.material_override = mat
    head_arrow.add_child(head_shaft)
    marker.visible = false
    head_arrow.visible = false
    refresh()


func _physics_process(delta: float) -> void:
    _t += delta
    _timer -= delta
    if _timer <= 0.0:
        _timer = REFRESH_SEC
        refresh()
    _animate(delta)


## 從關卡抓狀態、推進教學、決定目前提示與目標位置
func refresh() -> void:
    if level == null or level.player == null or not is_instance_valid(level.player):
        return
    var state := build_state()
    var total := GuideLogic.tutorial_steps()
    var step := GameState.tutorial_step
    while step < total and GuideLogic.tutorial_step_done(step, state):
        step += 1
        GameState.tutorial_step = step
        EventBus.tutorial_step_done.emit(step)
        if step >= total:
            EventBus.tutorial_finished.emit()
            EventBus.notice.emit(tr("NOTICE_TUTORIAL_DONE"))
    in_tutorial = step < total
    var text := ""
    if in_tutorial:
        current = GuideLogic.tutorial_hint(step, state)
        text = tr("HUD_OBJECTIVE") % [step + 1, total, _hint_text(current)]
    elif GameState.hints_on:
        current = GuideLogic.hint(state)
        if str(current.get("kind", "none")) != "none":
            text = tr("HUD_HINT_PREFIX") % _hint_text(current)
    else:
        current = {}
        text = tr("HUD_HINTS_OFF")
    has_target = _resolve(current)
    if level.hud != null:
        level.hud.set_objective(text)


func _hint_text(h: Dictionary) -> String:
    var key := str(h.get("text", ""))
    if key == "":
        return ""
    var s := tr(key)
    if h.has("arg") and str(h["arg"]) != "" and s.contains("%s"):
        s = s % tr(str(h["arg"]))
    return s


## 世界狀態 -> GuideLogic 的字典
func build_state() -> Dictionary:
    var p := level.player
    var counters := []
    for c in level.counters:
        counters.append({"id": c.def_id, "item": c.logic.item_id, "stock": c.logic.stock, "cap": c.logic.stock_cap,
                "has_server": c.has_server(), "has_cashier": c.cashier != null and is_instance_valid(c.cashier)})
    var stations := []
    for s in level.stations:
        stations.append({"id": s.spot_id, "input": s.logic.input_id, "input_count": s.logic.input_count, "input_cap": s.logic.input_cap,
                "output": s.logic.output_id, "output_count": s.logic.output_count})
    var pads := []
    for id in level.price_pads:
        var pad: PricePad = level.price_pads[id]
        pads.append({"id": str(id), "name": pad.logic.name_key, "remaining": pad.logic.remaining,
                "visible": pad.visible and not pad.logic.is_exhausted()})
    return {
        "carry_item": p.stack.item_id, "carry_count": p.stack.count, "wallet": GameState.wallet,
        "money_on_pad": level.money_pad.cash if level.money_pad != null else 0,
        "fish_caught": GameState.fish_caught, "items_sold": GameState.items_sold, "purchases": GameState.unlocked.size(),
        "hired": GameState.hired.duplicate(), "counters": counters, "stations": stations, "pads": pads,
        "bear": level.bears != null and level.bears.has_bear(), "weapon_level": GameState.weapon_level,
    }


## 把提示的 kind / target 換成世界座標;回傳有沒有目標
func _resolve(h: Dictionary) -> bool:
    var kind := str(h.get("kind", "none"))
    var id := str(h.get("target", ""))
    match kind:
        "water":
            target_pos = _water_target()
            return true
        "station_input", "station_output":
            var s := level.station_at(id)
            if s == null:
                return false
            target_pos = s.input_pad.global_position if kind == "station_input" else s.output_pad.global_position
            return true
        "counter_deposit", "service":
            var c := level.counter_by_id(id)
            if c == null:
                return false
            target_pos = c.deposit_pad.global_position if kind == "counter_deposit" else c.service_pad.global_position
            return true
        "money":
            if level.money_pad == null:
                return false
            target_pos = level.money_pad.global_position
            return true
        "trash":
            if level.trash_pad == null:
                return false
            target_pos = level.trash_pad.global_position
            return true
        "pad":
            if not level.price_pads.has(id):
                return false
            target_pos = (level.price_pads[id] as PricePad).global_position
            return true
        "bear":
            if level.bears == null or not level.bears.has_bear():
                return false
            target_pos = level.bears.nearest_bear(level.player.global_position).global_position
            return true
    return false


## 水邊目標:在水裡就指最近的魚,不然指離玩家最近的水面點(有多個水區就挑最近的)
func _water_target() -> Vector3:
    var p := level.player.global_position
    var fa := level.nearest_fish_area(p)
    if fa == null:
        return p
    if fa.contains(p):
        var f := fa.nearest_fish_to(p)
        if f != null:
            return f.global_position
    var r := fa.rect
    return Vector3(clampf(p.x, r.position.x + 1.0, r.end.x - 1.0), 0.0, clampf(p.z, r.position.y + 1.0, r.end.y - 1.0))


func _animate(delta: float) -> void:
    var show := has_target and (in_tutorial or GameState.hints_on)
    marker.visible = show
    if not show:
        head_arrow.visible = false
        return
    marker.global_position = target_pos + Vector3(0.0, 2.3 + sin(_t * 4.0) * 0.25, 0.0)
    marker.rotation.y += delta * 1.5
    var p := level.player.global_position
    head_arrow.global_position = p + Vector3(0.0, 3.1, 0.0)
    var far := Vector2(target_pos.x - p.x, target_pos.z - p.z).length() > NEAR
    head_arrow.visible = far
    if far:
        head_arrow.look_at(Vector3(target_pos.x, head_arrow.global_position.y, target_pos.z), Vector3.UP)


## H 鍵:教學結束後的提示開 / 關
func toggle_hints() -> void:
    GameState.hints_on = not GameState.hints_on
    EventBus.notice.emit(tr("NOTICE_HINTS_ON" if GameState.hints_on else "NOTICE_HINTS_OFF"))
    refresh()
