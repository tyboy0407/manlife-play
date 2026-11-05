class_name StationPad
extends Pad
## 工作站的輸入格 / 輸出格:輸入格把 carrier 身上的原料搬進工作站;輸出格把成品搬到 carrier 身上(只有 takes_output 的 carrier)。
## 多原料的工作站(廚房)每種原料各一個輸入格(item 指定收哪種)。
## 原料是不佔背包的資源(毛皮 / 熊王牙,GameState.is_resource)時,輸入格改從 GameState 的資源扣:只有會收錢的 carrier(玩家)
## 站滿 resourceInputDelaySec(0.8 秒)才開始放,走過不會掉毛皮(服飾店 5 張毛皮做一件毛衣)。
## 搬了東西就發 EventBus.items_moved 給飛行動畫 / 音效。

var station: Station = null
var mode := "input"   # input / output
var item := ""        # 輸入格收哪種原料(空字串 = 工作站的第一種)

var _dwell := {}        # carrier id -> 站了幾秒(資源輸入用;離開兩幀以上就重算)
var _dwell_frame := {}  # carrier id -> 上次站著的物理幀


func input_item() -> String:
    return item if item != "" else (station.logic.input_id if station != null and station.logic != null else "")


func _on_carrier_stay(c: Carrier, delta: float) -> void:
    if station == null or station.logic == null:
        return
    var rate := float(GameData.config().get("transferPerSec", 8.0))
    var logic := station.logic
    var moved := 0
    if mode == "input":
        var it := input_item()
        if GameState.is_resource(it):
            _resource_input(c, delta, rate, it)
            return
        if c.stack.item_id != it or c.stack.count <= 0 or not logic.can_accept_input_of(it):
            return
        var n := _budget(c, rate, delta)
        while n > 0 and c.stack.count > 0 and c.stack.item_id == it and logic.can_accept_input_of(it):
            c.stack.pop()
            logic.add_input_of(it, 1)
            n -= 1
            moved += 1
        if moved > 0:
            station.refresh_piles()
            EventBus.items_moved.emit("to_station", it, c.stack_top(), station.pile_top_for(it), moved)
    else:
        if not c.takes_output or logic.output_count <= 0 or not c.stack.can_push(logic.output_id):
            return
        var n := _budget(c, rate, delta)
        while n > 0 and logic.output_count > 0 and c.stack.can_push(logic.output_id):
            logic.take_output(1)
            c.stack.push(logic.output_id)
            n -= 1
            moved += 1
        if moved > 0:
            station.refresh_piles()
            EventBus.items_moved.emit("from_station", logic.output_id, station.pile_top(false), c.stack_top(), moved)


## 資源原料(毛皮):玩家站滿 resourceInputDelaySec 後,從 GameState 的資源一張張搬進原料堆
func _resource_input(c: Carrier, delta: float, rate: float, it: String) -> void:
    var logic := station.logic
    if not c.collects_cash or GameState.resource(it) <= 0 or not logic.can_accept_input_of(it):
        return
    var key := c.get_instance_id()
    var now := Engine.get_physics_frames()
    var dwell := delta
    if now - int(_dwell_frame.get(key, -100)) <= 2:
        dwell += float(_dwell.get(key, 0.0))
    _dwell[key] = dwell
    _dwell_frame[key] = now
    if dwell < float(GameData.config().get("resourceInputDelaySec", 0.8)):
        return
    var n := _budget(c, rate, delta)
    var moved := 0
    while n > 0 and GameState.resource(it) > 0 and logic.can_accept_input_of(it):
        if GameState.spend_resource(it, 1) <= 0:
            break
        logic.add_input_of(it, 1)
        n -= 1
        moved += 1
    if moved > 0:
        station.refresh_piles()
        EventBus.items_moved.emit("to_station", it, c.stack_top(), station.pile_top_for(it), moved)
