class_name MoneyPad
extends Pad
## 錢格:賣出的現金堆在這裡(StackVisual 排 4 列);會收錢的 carrier(玩家)站上來就一疊疊收進錢包(GameState.wallet),不佔背包。

var cash := 0
var pile: StackVisual


func _ready() -> void:
    color = Color(0.22, 0.32, 0.22)
    label_text = tr("PAD_MONEY")
    super()
    pile = StackVisual.new()
    pile.columns = 4
    pile.max_visible = 48
    pile.position = Vector3(0, 0.1, 0)
    add_child(pile)
    _refresh()


func add_cash(n: int) -> void:
    if n <= 0:
        return
    cash += n
    _refresh()


## 存檔還原
func set_cash(n: int) -> void:
    cash = maxi(n, 0)
    _refresh()


func _refresh() -> void:
    pile.show_items("cash", cash)
    if label != null:
        label.text = "%s\n$%d" % [tr("PAD_MONEY"), cash]


func _on_carrier_stay(c: Carrier, delta: float) -> void:
    if not c.collects_cash or cash <= 0:
        return
    var taken := mini(_budget(c, float(GameData.config().get("cashPickupPerSec", 40.0)), delta), cash)
    if taken <= 0:
        return
    cash -= taken
    GameState.add_wallet(taken)
    _refresh()
    EventBus.cash_collected.emit(c, taken)
    EventBus.items_moved.emit("cash", "cash", pile.global_position + Vector3(0.0, pile.top_height(), 0.0),
            c.global_position + Vector3(0.0, 2.2, 0.0), taken)
