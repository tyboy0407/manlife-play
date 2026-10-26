class_name TrashPad
extends Pad
## 垃圾桶:玩家(can_use_trash)站上來,把背上的東西一件件丟掉(錢在錢包裡,不受影響)。

var trashed_total := 0


func _ready() -> void:
    color = Color(0.25, 0.25, 0.28)
    label_text = tr("PAD_TRASH")
    super()
    add_child(VisualFactory.cylinder(0.38, 0.9, Color(0.35, 0.36, 0.4), Vector3(0, 0.45, -0.65)))
    add_child(VisualFactory.cylinder(0.42, 0.08, Color(0.2, 0.2, 0.24), Vector3(0, 0.92, -0.65)))


func _on_carrier_stay(c: Carrier, delta: float) -> void:
    if not c.can_use_trash or c.stack.is_empty():
        return
    var n := _budget(c, float(GameData.config().get("trashPerSec", 12.0)), delta)
    var t := 0
    while n > 0 and c.stack.count > 0:
        c.stack.pop()
        n -= 1
        t += 1
    if t > 0:
        trashed_total += t
        GameState.add_trashed(t)
        set_highlight(true)
    else:
        set_highlight(false)
