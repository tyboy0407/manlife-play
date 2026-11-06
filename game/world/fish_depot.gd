class_name FishDepot
extends Pad
## 貨物放置區(主村南排,Harbor.DEPOT_SPOT):雪地貨車把魚卸在這裡(最多 depot.cap 條),搬運工站上來拿魚送去切魚台。
## 對搬運工來說它跟工作站的輸出堆一樣(logic.output_count / output_pad / take_back / pile_top),所以 PorterPlanner 的來源清單直接放它;
## 只有搬運工(Helper role porter)站上來會拿,玩家走過不會順手拿走。外觀:格子 + 堆在上面的魚(StackVisual)+ 標籤「貨物放置區 魚 n/300」。

var level: Harbor = null
var logic: StationLogic
var output_pad: Node3D
var cap := 300
var received_total := 0   # 貨車卸進來的
var taken_total := 0      # 搬運工拿走的

var _pile: StackVisual


func _ready() -> void:
    cap = maxi(int(GameData.section("depot").get("cap", 300)), 1)
    logic = StationLogic.from_def({"id": "depot", "input": "", "output": "fish", "inputCap": 1, "outputCap": cap, "processSec": 1.0, "yield": 1})
    output_pad = self
    color = Color(0.26, 0.3, 0.34)
    label_text = _label_text()
    super()
    add_to_group("depot")
    _pile = StackVisual.new()
    _pile.columns = 4
    _pile.position = Vector3(0, 0.1, 0)
    add_child(_pile)
    refresh_piles()


func _label_text() -> String:
    return tr("SIGN_DEPOT") % [logic.output_count if logic != null else 0, cap]


func refresh_piles() -> void:
    _pile.show_items("fish", logic.output_count)
    set_label(_label_text())


func pile_top(_is_input: bool = false) -> Vector3:
    return _pile.global_position + Vector3(0.0, _pile.top_height(), 0.0)


func is_broken() -> bool:
    return false


func stock() -> int:
    return logic.output_count


func space() -> int:
    return logic.output_cap - logic.output_count


## 放進 n 條(貨車卸貨 / 搬運工放回);回收下幾條
func take_back(n: int) -> int:
    var accepted := mini(maxi(n, 0), space())
    if accepted > 0:
        logic.output_count += accepted
        refresh_piles()
    return accepted


## 貨車卸貨(另外計數)
func receive(n: int) -> int:
    var accepted := take_back(n)
    received_total += accepted
    return accepted


## 搬運工站上來:照 transferPerSec 一條條拿走
func _on_carrier_stay(c: Carrier, delta: float) -> void:
    if not (c is Helper) or (c as Helper).role != "porter" or not c.takes_output:
        return
    if logic.output_count <= 0 or not c.stack.can_push("fish"):
        return
    var rate := float(GameData.config().get("transferPerSec", 8.0))
    var n := _budget(c, rate, delta)
    var moved := 0
    while n > 0 and logic.output_count > 0 and c.stack.can_push("fish"):
        logic.take_output(1)
        c.stack.push("fish")
        n -= 1
        moved += 1
    if moved > 0:
        taken_total += moved
        refresh_piles()
        EventBus.items_moved.emit("from_station", "fish", pile_top(false), c.stack_top(), moved)


func snapshot() -> Dictionary:
    return {"stock": logic.output_count}


func restore(d: Dictionary) -> void:
    logic.output_count = clampi(int(d.get("stock", 0)), 0, cap)
    refresh_piles()
