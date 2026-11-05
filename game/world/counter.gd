class_name Counter
extends Node3D
## 櫃台:上架格(local -X)+ 櫃台桌 + 收銀格(local +Z,要有會收銀的人站著才賣)+ 排隊位(local +X 一排)。
## 顧客從出生點走到自己的排隊位,輪到最前面、有貨、有人收銀就買 want 件(customers.wantWeights 抽 1 ~ N 件,counters.json 的 wantWeights 可蓋過;
## 庫存不夠就買得到幾件算幾件),
## 錢進 money_pad,然後走向出口消失;後面的往前補。
## 規則在 CounterLogic;庫存上限吃 pile_cap 升級。資料在 data/counters.json。
## 擴建成長(customers.perExpansion,Harbor 在擴建 / 新建櫃台時 apply_expansion(n)):每擴建一次顧客上限 +max、生成間隔 × intervalMult、
## 每人要的件數權重往多件偏 wantShift 件(上限 wantMax;counters.json 自己給 wantWeights 的櫃台(毛衣)不偏);
## 超過一排(base_max_customers)的顧客排到第二排(local -Z 1.2 格,櫃台北側)。

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
var base_max_customers := 6      # 一排幾個(擴建前的上限,第二排從這之後起算)
var base_spawn_interval := 2.0
var spawn_interval := 2.0
var expansion := 0               # 套用了幾次擴建成長
var row_spacing := 1.2           # 第二排在櫃台北側幾格
var serve_interval := 0.35
var queue_spacing := 1.3                    # 排隊位間距(counters.json queueSpacing 可蓋過)
var spawn_offset := Vector3(12.0, 0, 1.5)   # local:顧客出生點(沒設 door 時用)
var exit_offset := Vector3(12.0, 0, 4.0)    # local:離開點(沒設 door 時用)
var door := Vector3.INF                     # 世界座標:這塊地的顧客門外(Harbor.customer_door);顧客從這裡來、買完走回這裡
var served_total := 0
var want_weights: Array = [1]
var base_want_weights: Array = [1]
var fixed_want := false          # counters.json 自己給了 wantWeights(毛衣櫃台一次一件):擴建不偏

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
    base_max_customers = int(def.get("maxCustomers", ccfg.get("max", 6)))   # counters.json 可蓋過(擴建區的櫃台排 4 個就到柵欄了)
    max_customers = base_max_customers
    queue_spacing = maxf(float(def.get("queueSpacing", ccfg.get("queueSpacing", 1.3))), 0.6)
    base_spawn_interval = maxf(float(ccfg.get("spawnIntervalSec", 2.0)), 0.1)
    spawn_interval = base_spawn_interval
    serve_interval = maxf(float(ccfg.get("serveIntervalSec", 0.35)), 0.0)
    fixed_want = def.has("wantWeights")
    var ww = def.get("wantWeights", ccfg.get("wantWeights", [1]))   # counters.json 可蓋過(毛衣櫃台一次只買一件)
    base_want_weights = ww if typeof(ww) == TYPE_ARRAY and not ww.is_empty() else [1]
    want_weights = base_want_weights
    add_child(VisualFactory.box(Vector3(1.0, 1.0, 2.6), Color(0.75, 0.52, 0.28), Vector3(0, 0.5, 0)))
    add_child(VisualFactory.box(Vector3(1.2, 0.08, 2.8), Color(0.85, 0.65, 0.4), Vector3(0, 1.04, 0)))
    var title := str(def.get("name", "COUNTER_%s" % def_id))
    add_child(VisualFactory.label("%s  $%d" % [tr(title), logic.price], Vector3(0, 2.4, 0), 44, Color(1.0, 0.95, 0.8)))
    deposit_pad = CounterPad.new()
    deposit_pad.name = "DepositPad"
    deposit_pad.counter = self
    deposit_pad.color = Color(0.3, 0.26, 0.3)
    deposit_pad.label_text = "%s\n%s" % [tr("PAD_COUNTER"), GameData.item_name(logic.item_id)]
    deposit_pad.position = Vector3(-2.2, 0, 0)
    add_child(deposit_pad)
    service_pad = ServicePad.new()
    service_pad.name = "ServicePad"
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
    apply_expansion(expansion)


## 擴建成長:套 n 次(customers.perExpansion)
func apply_expansion(n: int) -> void:
    expansion = maxi(n, 0)
    var pe = GameData.section("customers").get("perExpansion", {})
    if typeof(pe) != TYPE_DICTIONARY:
        pe = {}
    max_customers = base_max_customers + int(pe.get("max", 1)) * expansion
    spawn_interval = maxf(base_spawn_interval * pow(clampf(float(pe.get("intervalMult", 0.85)), 0.1, 1.0), float(expansion)), 0.1)
    if fixed_want:
        want_weights = base_want_weights
    else:
        want_weights = CounterLogic.shift_weights(base_want_weights, int(pe.get("wantShift", 1)) * expansion, int(pe.get("wantMax", 9)))


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


## 第 index 個排隊位:一排 base_max_customers 個,之後排到第二排(北側)
func slot_position(index: int) -> Vector3:
    var per_row := maxi(base_max_customers, 1)
    var row := index / per_row
    var col := index % per_row
    return to_global(Vector3(1.6 + float(col) * queue_spacing, 0.0, -row_spacing * float(row)))


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
    front.leave(exit_point())
    customers.remove_at(0)
    _reassign_slots()
    _serve_timer = serve_interval


func _spawn_customer() -> void:
    var c := Customer.new()
    c.want = CounterLogic.roll_want(want_weights, randf())
    c.item_name = GameData.item_name(logic.item_id)
    get_parent().add_child(c)
    c.global_position = spawn_point() + Vector3(0, 0, randf_range(-0.5, 0.5))
    customers.append(c)
    c.set_target(slot_position(customers.size() - 1))


## 顧客出生點 / 離開點:有顧客門就用門外,沒有(測試單獨建的櫃台)用櫃台東邊 12 格
func spawn_point() -> Vector3:
    return door if door != Vector3.INF else to_global(spawn_offset)


func exit_point() -> Vector3:
    return door if door != Vector3.INF else to_global(exit_offset)


func _reassign_slots() -> void:
    for i in customers.size():
        (customers[i] as Customer).set_target(slot_position(i))
