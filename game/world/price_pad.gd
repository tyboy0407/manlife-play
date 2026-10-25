class_name PricePad
extends Pad
## 價格牌:會收錢的 carrier 身上有現金、站上來就一張張扣(payPerSec),走開暫停;付清 -> GameState.apply_purchase。
## 可重複買的牌付清後價格漲一級、留在原地,但付錢的人要先走開再踏上來才會開始付下一次(避免站著不動就把錢一直吃掉);
## 買滿或一次性的牌付清就消失。build_spot = 橘色半透明建地。付款中發黃光。

var logic: PurchaseLogic
var build_spot := false

var _paying_frames := 0
var _blocked := {}   # 剛付清時還站在格子上的 carrier id -> true(離開後解除)


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
    var text := "%s\n$%d" % [tr(logic.name_key), logic.remaining]
    if logic.repeatable:
        text += "\n(%d/%d)" % [logic.buys + 1, logic.max_buys]
    set_label(text)


func _on_carrier_stay(c: Carrier, delta: float) -> void:
    if logic.is_exhausted() or not c.collects_cash or _blocked.has(c.get_instance_id()):
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
        _complete(c)


func _physics_process(delta: float) -> void:
    super(delta)
    if _paying_frames > 0:
        _paying_frames -= 1
        if _paying_frames == 0:
            set_highlight(false)
    if not _blocked.is_empty() and monitoring:
        var present := {}
        for b in get_overlapping_bodies():
            present[b.get_instance_id()] = true
        for id in _blocked.keys():
            if not present.has(id):
                _blocked.erase(id)


func _complete(payer: Carrier) -> void:
    var title := tr(logic.name_key)
    logic.complete()
    EventBus.notice.emit(tr("NOTICE_PURCHASED") % title)
    GameState.apply_purchase(logic.id, logic.effect)
    if logic.is_exhausted():
        _disable()
    else:
        _update_label()
        _blocked[payer.get_instance_id()] = true


func _disable() -> void:
    set_deferred("monitoring", false)
    set_physics_process(false)
    visible = false


## 存檔還原:買過幾次、這一次還剩多少
func restore_state(buys: int, remaining: int) -> void:
    logic.restore(buys, remaining)
    if logic.is_exhausted():
        _disable()
    else:
        _update_label()
