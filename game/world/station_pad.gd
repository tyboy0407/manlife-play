class_name StationPad
extends Pad
## 工作站的輸入格 / 輸出格:輸入格把 carrier 身上的原料搬進工作站;輸出格把成品搬到 carrier 身上(只有 takes_output 的 carrier)。
## 搬了東西就發 EventBus.items_moved 給飛行動畫 / 音效。

var station: Station = null
var mode := "input"   # input / output


func _on_carrier_stay(c: Carrier, delta: float) -> void:
    if station == null or station.logic == null:
        return
    var rate := float(GameData.config().get("transferPerSec", 8.0))
    var logic := station.logic
    var moved := 0
    if mode == "input":
        if c.stack.item_id != logic.input_id or c.stack.count <= 0 or not logic.can_accept_input():
            return
        var n := _budget(c, rate, delta)
        while n > 0 and c.stack.count > 0 and c.stack.item_id == logic.input_id and logic.can_accept_input():
            c.stack.pop()
            logic.add_input(1)
            n -= 1
            moved += 1
        if moved > 0:
            station.refresh_piles()
            EventBus.items_moved.emit("to_station", logic.input_id, c.stack_top(), station.pile_top(true), moved)
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
