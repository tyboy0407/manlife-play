class_name PricePad
extends Pad
## 價格牌:會收錢的 carrier 身上有現金、站上來就一張張扣(payPerSec),走開暫停;付清 -> GameState.apply_purchase。
## build_spot = 橘色半透明建地(付清後關卡在這裡生東西);一般價格牌付清後消失。付款中格子發黃光。

var logic: PurchaseLogic
var build_spot := false

var _paying_frames := 0


static func create(def: Dictionary) -> PricePad:
    var p := PricePad.new()
    p.logic = PurchaseLogic.from_def(def)
    p.build_spot = bool(def.get("buildSpot", false))
    p.name = "PricePad_%s" % p.logic.id
    return p


func _ready() -> void:
    color = Color(0.95, 0.55, 0.2, 0.55) if build_spot else Color(0.2, 0.2, 0.26)
    super()
    if build_spot:
        mesh.material_override = VisualFactory.material(color, Color.BLACK, true)
    _update_label()


func _update_label() -> void:
    set_label("%s\n$%d" % [tr(logic.name_key), logic.remaining])


func _on_carrier_stay(c: Carrier, delta: float) -> void:
    if logic.is_paid() or not c.collects_cash:
        return
    if c.stack.item_id != "cash" or c.stack.count <= 0:
        return
    var n := _budget(c, float(GameData.config().get("payPerSec", 12.0)), delta)
    var paid := 0
    while n > 0 and c.stack.count > 0 and not logic.is_paid():
        c.stack.pop()
        logic.pay(1)
        n -= 1
        paid += 1
    if paid <= 0:
        return
    _update_label()
    set_highlight(true)
    _paying_frames = 8
    EventBus.purchase_progress.emit(logic.id, logic.remaining)
    if logic.is_paid():
        _complete()


func _physics_process(delta: float) -> void:
    super(delta)
    if _paying_frames > 0:
        _paying_frames -= 1
        if _paying_frames == 0:
            set_highlight(false)


func _complete() -> void:
    set_deferred("monitoring", false)
    set_physics_process(false)
    visible = false
    EventBus.notice.emit(tr("NOTICE_PURCHASED") % tr(logic.name_key))
    GameState.apply_purchase(logic.id, logic.effect)
