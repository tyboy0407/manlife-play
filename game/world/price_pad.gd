class_name PricePad
extends Pad
## 價格牌:會收錢的 carrier(玩家)站上來停留 payDelaySec 後,從錢包(GameState.wallet)一張張扣(payPerSec),走開暫停;
## 付清 -> GameState.apply_purchase。停留時間是為了「帶著錢走過牌子不會順手付掉」。
## 可重複買的牌付清後價格漲一級、留在原地,但付錢的人要先走開再踏上來才會開始付下一次(避免站著不動就把錢一直吃掉);
## 買滿或一次性的牌付清就消失;僱用牌的幫手被吃掉(on_lost)名額退回來、牌子重新出現並標「買回 ×1.5」;
## 守衛塔牌(effect tower)就是塔的地基,塔被拆 on_lost 後標「修復」(同價);工作站的修復牌(effect repair,Harbor._add_station 生的)
## 完好時藏著(當作已買),被王拆了 on_lost 才出現。擴建村莊 expand():僱用牌多開放 expandBuys 個名額。
## 付款速度 payPerSec × max(1, 本次價格 / payScaleCost):大額牌(擴建村莊 $1000)不用站一分鐘。build_spot = 橘色半透明建地。付款中發黃光。
## currency 不是 cash 的牌(武器店升級收毛皮、強化守衛塔收熊王牙)從 GameState 的資源計數扣;set_open 給關卡手動開關(熊王牙牌只在塔完好時出現)。
## 捕熊夾 / 誘餌牌(effect trap / bait)是消耗品:用掉後 on_lost 同價重新出現(rebuyMult 1、不標買回);傳送帶牌(effect conveyor)一次性。

var logic: PurchaseLogic
var build_spot := false
var pay_delay := 0.6
var ring: ProgressRing = null   # 付款進度環

var _paying_frames := 0
var _blocked := {}   # 剛付清時還站在格子上的 carrier id -> true(離開後解除)
var _dwell := {}     # carrier id -> 已站了幾秒(離開就清掉)


static func create(def: Dictionary) -> PricePad:
    var p := PricePad.new()
    p.logic = PurchaseLogic.from_def(def)
    p.build_spot = bool(def.get("buildSpot", false))
    p.name = "PricePad_%s" % p.logic.id
    return p


func _ready() -> void:
    color = Color(0.95, 0.55, 0.2, 0.55) if build_spot else Color(0.2, 0.2, 0.26)
    pay_delay = maxf(float(GameData.config().get("payDelaySec", 0.6)), 0.0)
    super()
    if build_spot:
        mesh.material_override = VisualFactory.material(color, Color.BLACK, true)
    ring = ProgressRing.new()
    ring.inner = 1.08
    ring.outer = 1.3
    ring.color = Color(1.0, 0.8, 0.25)
    ring.position = Vector3(0, 0.12, 0)
    add_child(ring)
    _update_label()


func _update_label() -> void:
    var text := "%s\n$%d" % [tr(logic.name_key), logic.remaining]
    if not logic.is_cash():
        text = "%s\n%s" % [tr(logic.name_key), tr("COST_%s" % logic.currency) % logic.remaining]
    if logic.repeatable:
        text += "\n(%d/%d)" % [logic.buys + 1, logic.max_buys]
    if logic.is_rebuy() and not is_consumable_pad():
        text += "\n" + (tr("PAD_REPAIR") if is_repair_pad() else tr("PAD_REBUY") % str(logic.rebuy_mult))
    set_label(text)
    if ring != null:
        ring.set_progress(logic.progress())


func _on_carrier_stay(c: Carrier, delta: float) -> void:
    if logic.is_exhausted() or not c.collects_cash:
        return
    var key := c.get_instance_id()
    if _blocked.has(key):
        return
    var dwell := float(_dwell.get(key, 0.0)) + delta
    _dwell[key] = dwell
    var have := GameState.resource(logic.currency)
    if dwell < pay_delay:
        return
    # 免費升級券:站滿 payDelaySec 就直接付清這張升級牌(不扣錢)
    if str(logic.effect.get("type", "")) == "upgrade" and logic.is_cash() and GameState.coupon("upgrade") > 0:
        GameState.use_coupon("upgrade")
        logic.pay(logic.remaining)
        EventBus.notice.emit(tr("NOTICE_COUPON_UPGRADE"))
        EventBus.purchase_progress.emit(logic.id, logic.remaining)
        _update_label()
        _complete(c)
        return
    if have <= 0:
        return
    var scale_cost := maxf(float(GameData.config().get("payScaleCost", 100.0)), 1.0)
    var rate := float(GameData.config().get("payPerSec", 15.0)) * maxf(1.0, float(logic.current_cost()) / scale_cost)
    var n := _budget(c, rate, delta)
    var paid := logic.pay(mini(n, have))
    if paid <= 0:
        return
    GameState.spend_resource(logic.currency, paid)
    EventBus.items_moved.emit("pay", logic.currency, c.global_position + Vector3(0.0, 1.6, 0.0), global_position + Vector3(0.0, 0.3, 0.0), paid)
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
    if monitoring and (not _blocked.is_empty() or not _dwell.is_empty()):
        var present := {}
        for b in get_overlapping_bodies():
            present[b.get_instance_id()] = true
        for id in _blocked.keys():
            if not present.has(id):
                _blocked.erase(id)
        for id in _dwell.keys():
            if not present.has(id):
                _dwell.erase(id)


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


func _enable() -> void:
    set_deferred("monitoring", true)
    set_physics_process(true)
    visible = true


func is_tower_pad() -> bool:
    return str(logic.effect.get("type", "")) == "tower"


## 消耗品的牌(捕熊夾 / 誘餌):用掉後 on_lost 重新出現,同價、不標「買回」
func is_consumable_pad() -> bool:
    var t := str(logic.effect.get("type", ""))
    return t == "trap" or t == "bait"


## 蓋回來 / 修好用的牌(守衛塔、工作站修復):再買一次標「修復」而不是「買回 ×」
func is_repair_pad() -> bool:
    var t := str(logic.effect.get("type", ""))
    return t == "tower" or t == "repair"


## 擴建村莊:這塊牌多開放 expandBuys 個名額(買滿消失的牌重新出現)
func expand() -> void:
    if not logic.expand():
        return
    _blocked.clear()
    _enable()
    _update_label()


## 武器店升級:武器牌名額提高到 n(買滿消失的牌重新出現,價格接著漲)
func raise_max(n: int) -> void:
    if not logic.raise_max(n):
        return
    _blocked.clear()
    _enable()
    _update_label()


## 關卡手動開關(熊王牙牌只在塔完好且還沒強化時出現);買滿的牌開不了
func set_open(open: bool) -> void:
    if open and not logic.is_exhausted():
        if not visible:
            _blocked.clear()
            _enable()
            _update_label()
    else:
        _disable()


## 這塊牌僱的幫手被吃掉 / 蓋的塔被拆了:名額退回來(買回價 / 修復價),買滿消失的牌也重新出現
func on_lost() -> void:
    if not logic.lose():
        return
    _blocked.clear()
    _enable()
    _update_label()


## 存檔還原:買過幾次、這一次還剩多少、幾個名額等著買回
func restore_state(buys: int, remaining: int, lost: int = 0) -> void:
    logic.restore(buys, remaining, lost)
    if logic.is_exhausted():
        _disable()
    else:
        _enable()
        _update_label()
