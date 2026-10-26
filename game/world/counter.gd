class_name Counter
extends Node3D
## 櫃台:上架格(local -X)+ 櫃台桌 + 收銀格(local +Z,要有會收銀的人站著才賣)+ 排隊位(local +X 一排)。
## 顧客從出生點走到自己的排隊位,輪到最前面、有貨、有人收銀就買 1 件,錢進 money_pad,然後走向出口消失;後面的往前補。
## 規則在 CounterLogic;庫存上限吃 pile_cap 升級。資料在 data/counters.json。

var def := {}
var def_id := ""
var logic := CounterLogic.new()
var base_stock_cap := 30
var deposit_pad: CounterPad
var service_pad: ServicePad
var money_pad: MoneyPad = null
var stock_pile: StackVisual
var customers: Array = []   # Customer(filter 回傳無型別陣列,所以不標型別)
var cashier: Helper = null
var max_customers := 6
var spawn_interval := 2.0
var serve_interval := 0.35
var spawn_offset := Vector3(12.0, 0, 1.5)   # local:顧客出生點
var exit_offset := Vector3(12.0, 0, 4.0)    # local:離開點
var served_total := 0

var _spawn_timer := 0.5
var _serve_timer := 0.0
var _server_frame := -1000


static func create(counter_def: Dictionary) -> Counter:
    var c := Counter.new()
    c.def = counter_def
    c.def_id = str(counter_def.get("id", "counter"))
    c.name = "Counter_%s" % c.def_id
    return c


func _ready() -> void:
    add_to_group("counter")
    logic.item_id = str(def.get("item", "fillet"))
    base_stock_cap = int(def.get("stockCap", 30))
    logic.price = int(def.get("price", 2))
    var ccfg := GameData.section("customers")
    max_customers = int(ccfg.get("max", 6))
    spawn_interval = maxf(float(ccfg.get("spawnIntervalSec", 2.0)), 0.1)
    serve_interval = maxf(float(ccfg.get("serveIntervalSec", 0.35)), 0.0)
    add_child(VisualFactory.box(Vector3(1.0, 1.0, 2.6), Color(0.75, 0.52, 0.28), Vector3(0, 0.5, 0)))
    add_child(VisualFactory.box(Vector3(1.2, 0.08, 2.8), Color(0.85, 0.65, 0.4), Vector3(0, 1.04, 0)))
    var title := str(def.get("name", "COUNTER_%s" % def_id))
    add_child(VisualFactory.label("%s  $%d" % [tr(title), logic.price], Vector3(0, 2.4, 0), 44, Color(1.0, 0.95, 0.8)))
    deposit_pad = CounterPad.new()
    deposit_pad.counter = self
    deposit_pad.color = Color(0.3, 0.26, 0.3)
    deposit_pad.label_text = "%s\n%s" % [tr("PAD_COUNTER"), GameData.item_name(logic.item_id)]
    deposit_pad.position = Vector3(-2.2, 0, 0)
    add_child(deposit_pad)
    service_pad = ServicePad.new()
    service_pad.counter = self
    service_pad.position = Vector3(0, 0, 2.2)
    add_child(service_pad)
    stock_pile = StackVisual.new()
    stock_pile.columns = 3
    stock_pile.position = Vector3(0, 1.08, 0)
    add_child(stock_pile)
    apply_upgrades()
    GameState.changed.connect(apply_upgrades)
    refresh_pile()


func apply_upgrades() -> void:
    logic.stock_cap = maxi(int(round(float(base_stock_cap) * GameState.upgrade_mult("pile_cap"))), 1)


func refresh_pile() -> void:
    stock_pile.show_items(logic.item_id, logic.stock)


## 庫存堆頂端(世界座標),飛行動畫用
func pile_top() -> Vector3:
    return stock_pile.global_position + Vector3(0.0, stock_pile.top_height(), 0.0)


## 收銀格每幀呼叫:這幀有人在收銀
func notify_server() -> void:
    _server_frame = Engine.get_physics_frames()


func has_server() -> bool:
    return Engine.get_physics_frames() - _server_frame <= 2


func slot_position(index: int) -> Vector3:
    return to_global(Vector3(1.6 + float(index) * 1.1, 0.0, 0.0))


func waiting_customers() -> int:
    var n := 0
    for c in customers:
        if is_instance_valid(c) and (c as Customer).arrived and not (c as Customer).leaving:
            n += 1
    return n


func _physics_process(delta: float) -> void:
    customers = customers.filter(func(c) -> bool: return is_instance_valid(c))
    _spawn_timer -= delta
    if _spawn_timer <= 0.0 and customers.size() < max_customers:
        _spawn_customer()
        _spawn_timer = spawn_interval
    _serve_timer = maxf(_serve_timer - delta, 0.0)
    if customers.is_empty() or _serve_timer > 0.0 or not has_server():
        return
    var front: Customer = customers[0]
    if front.leaving or not front.arrived or logic.stock <= 0:
        return
    var res := logic.serve(front.want)
    var sold := int(res["sold"])
    if sold <= 0:
        return
    served_total += sold
    var from := pile_top()
    refresh_pile()
    if money_pad != null:
        money_pad.add_cash(int(res["cash"]))
    EventBus.sale_made.emit(logic.item_id, sold, int(res["cash"]))
    EventBus.items_moved.emit("sold", logic.item_id, from, front.global_position + Vector3(0.0, 1.4, 0.0), sold)
    front.leave(to_global(exit_offset))
    customers.remove_at(0)
    _reassign_slots()
    _serve_timer = serve_interval


func _spawn_customer() -> void:
    var c := Customer.new()
    c.want = 1
    c.item_name = GameData.item_name(logic.item_id)
    get_parent().add_child(c)
    c.global_position = to_global(spawn_offset + Vector3(0, 0, randf_range(-0.5, 0.5)))
    customers.append(c)
    c.set_target(slot_position(customers.size() - 1))


func _reassign_slots() -> void:
    for i in customers.size():
        (customers[i] as Customer).set_target(slot_position(i))
