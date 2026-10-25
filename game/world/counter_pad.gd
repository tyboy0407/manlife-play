class_name CounterPad
extends Pad
## 櫃台的上架格:把 carrier 身上的商品(櫃台賣的那種)搬進櫃台庫存。

var counter: Counter = null


func _on_carrier_stay(c: Carrier, delta: float) -> void:
    if counter == null:
        return
    var logic := counter.logic
    if c.stack.item_id != logic.item_id or c.stack.count <= 0 or logic.space() <= 0:
        return
    var n := _budget(c, float(GameData.config().get("transferPerSec", 8.0)), delta)
    var moved := 0
    while n > 0 and c.stack.count > 0 and logic.space() > 0:
        c.stack.pop()
        logic.add_stock(1)
        n -= 1
        moved += 1
    if moved > 0:
        counter.refresh_pile()
