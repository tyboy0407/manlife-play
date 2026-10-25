class_name Counter
extends Node3D
## 櫃台:上架格(local -X)+ 櫃台桌 + 排隊位(local +X 一排)。顧客從出生點走到自己的排隊位,輪到最前面且有貨就買 1 件,
## 錢進 money_pad,然後走向出口消失;後面的往前補。規則在 CounterLogic。

var logic := CounterLogic.new()
var deposit_pad: CounterPad
var money_pad: MoneyPad = null
var stock_pile: StackVisual
var customers: Array = []   # Customer(filter 回傳無型別陣列,所以不標型別)
var max_customers := 6
var spawn_interval := 2.0
var serve_interval := 0.35
var spawn_offset := Vector3(12.0, 0, 1.5)   # local:顧客出生點
var exit_offset := Vector3(12.0, 0, 4.0)    # local:離開點
var served_total := 0

var _spawn_timer := 0.5
var _serve_timer := 0.0


func _ready() -> void:
    add_to_group("counter")
    var cfg := GameData.section("counter")
    logic.item_id = str(cfg.get("item", "fillet"))
    logic.stock_cap = int(cfg.get("stockCap", 30))
    logic.price = int(cfg.get("pricePerItem", 2))
    var ccfg := GameData.section("customers")
    max_customers = int(ccfg.get("max", 6))
    spawn_interval = maxf(float(ccfg.get("spawnIntervalSec", 2.0)), 0.1)
    serve_interval = maxf(float(ccfg.get("serveIntervalSec", 0.35)), 0.0)
    add_child(VisualFactory.box(Vector3(1.0, 1.0, 2.6), Color(0.75, 0.52, 0.28), Vector3(0, 0.5, 0)))
    add_child(VisualFactory.box(Vector3(1.2, 0.08, 2.8), Color(0.85, 0.65, 0.4), Vector3(0, 1.04, 0)))
    deposit_pad = CounterPad.new()
    deposit_pad.counter = self
    deposit_pad.color = Color(0.3, 0.26, 0.3)
    deposit_pad.label_text = "%s\n%s" % [tr("PAD_COUNTER"), GameData.item_name(logic.item_id)]
    deposit_pad.position = Vector3(-2.2, 0, 0)
    add_child(deposit_pad)
    stock_pile = StackVisual.new()
    stock_pile.columns = 3
    stock_pile.position = Vector3(0, 1.08, 0)
    add_child(stock_pile)
    refresh_pile()


func refresh_pile() -> void:
    stock_pile.show_items(logic.item_id, logic.stock)


func slot_position(index: int) -> Vector3:
    return to_global(Vector3(1.6 + float(index) * 1.1, 0.0, 0.0))


func _physics_process(delta: float) -> void:
    customers = customers.filter(func(c) -> bool: return is_instance_valid(c))
    _spawn_timer -= delta
    if _spawn_timer <= 0.0 and customers.size() < max_customers:
        _spawn_customer()
        _spawn_timer = spawn_interval
    _serve_timer = maxf(_serve_timer - delta, 0.0)
    if customers.is_empty() or _serve_timer > 0.0:
        return
    var front: Customer = customers[0]
    if front.leaving or not front.arrived or logic.stock <= 0:
        return
    var res := logic.serve(front.want)
    var sold := int(res["sold"])
    if sold <= 0:
        return
    served_total += sold
    refresh_pile()
    if money_pad != null:
        money_pad.add_cash(int(res["cash"]))
    EventBus.sale_made.emit(logic.item_id, sold, int(res["cash"]))
    front.leave(to_global(exit_offset))
    customers.remove_at(0)
    _reassign_slots()
    _serve_timer = serve_interval


func _spawn_customer() -> void:
    var c := Customer.new()
    c.want = 1
    get_parent().add_child(c)
    c.global_position = to_global(spawn_offset + Vector3(0, 0, randf_range(-0.5, 0.5)))
    customers.append(c)
    c.set_target(slot_position(customers.size() - 1))


func _reassign_slots() -> void:
    for i in customers.size():
        (customers[i] as Customer).set_target(slot_position(i))
