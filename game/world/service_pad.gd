class_name ServicePad
extends Pad
## 櫃台的收銀格:有會收銀的 carrier(玩家 / 收銀員)站著,櫃台才賣得出去;有人站著時發亮。

var counter: Counter = null


func _ready() -> void:
    color = Color(0.36, 0.3, 0.2)
    label_text = tr("PAD_SERVICE")
    super()


func _on_carrier_stay(c: Carrier, _delta: float) -> void:
    if c.can_serve and counter != null:
        counter.notify_server()


func _physics_process(delta: float) -> void:
    super(delta)
    set_highlight(counter != null and counter.has_server())
