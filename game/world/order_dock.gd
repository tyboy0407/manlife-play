class_name OrderDock
extends Pad
## 碼頭的訂單交貨格(村外西北,貨船旁):有訂單時,背著訂單要的貨的 carrier(玩家或搬運工)站上來就一件件扣(transferPerSec),
## 訂單要稀有魚時從 GameState 的稀有魚資源扣(只有玩家 collects_cash)。送齊由 Harbor(聽 logic)結算。
## 外觀:格子 + 牌子文字顯示訂單內容(Harbor 每幀餵 set_order_text)。

var level: Harbor = null
var logic: OrderLogic = null
var delivered_here := 0


func _ready() -> void:
    color = Color(0.25, 0.3, 0.45)
    label_text = tr("PAD_DOCK")
    super()
    if label != null:
        label.position.y = 1.9


func _on_carrier_stay(c: Carrier, delta: float) -> void:
    if logic == null or not logic.has_order():
        return
    var rate := float(GameData.config().get("transferPerSec", 8.0))
    var moved := 0
    var item := c.stack.item_id
    if c.stack.count > 0 and logic.need_of(item) > 0:
        var n := _budget(c, rate, delta)
        while n > 0 and c.stack.count > 0 and logic.need_of(item) > 0:
            c.stack.pop()
            logic.deliver(item, 1)
            n -= 1
            moved += 1
        if moved > 0:
            delivered_here += moved
            EventBus.items_moved.emit("to_dock", item, c.stack_top(), global_position + Vector3(0, 1.0, 0), moved)
            EventBus.order_delivered.emit(item, moved)
    elif c.collects_cash and logic.need_of(OrderLogic.RARE_ITEM) > 0 and GameState.resource(OrderLogic.RARE_ITEM) > 0:
        # 稀有魚不佔背包:玩家站上來就從資源扣
        var n := _budget(c, rate, delta)
        while n > 0 and logic.need_of(OrderLogic.RARE_ITEM) > 0 and GameState.resource(OrderLogic.RARE_ITEM) > 0:
            if GameState.spend_resource(OrderLogic.RARE_ITEM, 1) <= 0:
                break
            logic.deliver(OrderLogic.RARE_ITEM, 1)
            n -= 1
            moved += 1
        if moved > 0:
            delivered_here += moved
            EventBus.items_moved.emit("to_dock", OrderLogic.RARE_ITEM, c.stack_top(), global_position + Vector3(0, 1.0, 0), moved)
            EventBus.order_delivered.emit(OrderLogic.RARE_ITEM, moved)
    if moved > 0 and level != null and logic.is_complete():
        level.order_completed()
