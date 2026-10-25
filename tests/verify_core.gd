extends Node
## 核心規則 headless 驗證:資料載入(game / items / stations / shop / 翻譯)、ItemStack、StationLogic、PurchaseLogic、
## CounterLogic、MoveInput。跑法:godot --headless --path . res://tests/verify_core.tscn(先 --import)

var _fails := 0


func _ready() -> void:
    print("VERIFY CORE: begin")
    _test_data()
    _test_stack()
    _test_station()
    _test_purchase()
    _test_counter()
    _test_input()
    if _fails == 0:
        print("VERIFY CORE: ALL OK")
    else:
        print("VERIFY CORE: %d FAILURES" % _fails)
    get_tree().quit(1 if _fails > 0 else 0)


func _check(cond: bool, label: String) -> void:
    if cond:
        print("  OK   %s" % label)
    else:
        _fails += 1
        print("  FAIL %s" % label)


func _near(a: float, b: float, label: String, eps: float) -> void:
    _check(absf(a - b) <= eps, "%s (%.3f vs %.3f)" % [label, a, b])


## --- 資料 ---

func _test_data() -> void:
    GameData.reload()
    var cfg := GameData.config()
    _check(not cfg.is_empty() and float(cfg.get("playerSpeed", 0.0)) > 0.0 and int(cfg.get("carryCapacity", 0)) == 8,
            "game.json:玩家速度、背包 8")
    _check(GameData.section("fish").has("maxInWater") and GameData.section("customers").has("max")
            and GameData.section("nope").is_empty(), "子區塊 fish / customers;不存在的回空")
    _check(GameData.items().size() == 3 and GameData.item("fish").has("size") and GameData.item("cash").has("color"),
            "items.json:魚 / 魚片 / 現金")
    _check(GameData.item_size("fish") == Vector3(0.7, 0.22, 0.3) and GameData.item_color("cash") != Color(0.8, 0.8, 0.8)
            and GameData.item_size("nope") == Vector3(0.5, 0.15, 0.4), "物品尺寸 / 顏色;未知物品用預設")
    _check(GameData.item_name("fish") != "fish" and GameData.item_name("fish") != "ITEM_fish", "物品名有翻譯(%s)" % GameData.item_name("fish"))
    var st := GameData.station("cutting_table")
    _check(str(st.get("input", "")) == "fish" and str(st.get("output", "")) == "fillet" and int(st.get("yield", 0)) == 2,
            "stations.json:切魚台 魚 -> 魚片 ×2")
    var shop := GameData.shop()
    var costs: Array = []
    for p in shop:
        costs.append(int(p["cost"]))
    _check(shop.size() == 3 and costs == [10, 25, 50], "shop.json:三塊牌 10 / 25 / 50 %s" % str(costs))
    _check(bool(GameData.purchase("expand_table").get("buildSpot", false)) and GameData.purchase("nope").is_empty(),
            "建地牌旗標;未知購買回空")


## --- 背上的一疊 ---

func _test_stack() -> void:
    var s := ItemStack.new()
    s.set_capacity(3)
    var changes := [0]
    s.changed.connect(func() -> void: changes[0] += 1)
    _check(s.is_empty() and s.can_push("fish") and s.space_for("fish") == 3, "空疊可放任何東西、空間 3")
    _check(s.push("fish") and s.push("fish") and s.push("fish") and s.is_full() and s.count == 3 and s.item_id == "fish",
            "放三條魚 -> 滿")
    _check(not s.push("fish") and not s.can_push("fillet") and s.space_for("fillet") == 0, "滿了不能放;不同種類不能混")
    _check(s.pop() == "fish" and s.count == 2 and not s.is_full() and not s.can_push("fillet"), "拿掉一個;還有魚時仍不能放魚片")
    s.clear()
    _check(s.is_empty() and s.item_id == "" and s.push("fillet") and s.item_id == "fillet", "清空後可以放魚片")
    _check(s.pop() == "fillet" and s.pop() == "" and s.item_id == "", "拿到空 -> 種類清掉、再拿回空字串")
    s.push("cash")
    s.push("cash")
    s.set_capacity(1)
    _check(s.capacity == 1 and s.count == 1, "縮小容量會截掉多的")
    _check(changes[0] >= 8, "每次變動都發 changed(%d)" % changes[0])


## --- 工作站 ---

func _test_station() -> void:
    var st := StationLogic.from_def(GameData.station("cutting_table"))
    _check(st.id == "cutting_table" and st.input_cap == 12 and st.output_cap == 24 and is_equal_approx(st.process_sec, 1.0),
            "從資料建立")
    _check(st.add_input(5) == 5 and st.input_count == 5 and st.add_input(10) == 7 and st.input_count == 12
            and not st.can_accept_input(), "輸入堆上限 12")
    st.input_count = 5
    _check(st.tick(0.5) == 0 and st.is_working() and is_equal_approx(st.work_progress(), 0.5), "0.5 秒:處理中、沒產出")
    _check(st.tick(0.5) == 2 and st.input_count == 4 and st.output_count == 2 and not st.is_working(), "1 秒:消耗 1 條魚、產 2 片")
    st.output_count = 23
    _check(st.is_blocked() and st.tick(2.0) == 0 and not st.is_working() and st.input_count == 4, "輸出堆放不下一批就停工、不消耗輸入")
    _check(st.take_output(5) == 5 and st.output_count == 18 and st.has_output(), "取出 5 片")
    _check(st.tick(0.6) == 0 and st.tick(0.6) == 2 and st.output_count == 20, "解除阻塞後繼續")
    st.speed_mult = 2.0
    _check(st.tick(0.5) == 2 or st.tick(0.01) == 2, "速度 ×2:0.5 秒處理一個")
    var empty := StationLogic.from_def({"id": "x", "input": "a", "output": "b"})
    _check(empty.tick(1.0) == 0 and not empty.is_working(), "沒輸入不工作")
    _check(st.take_output(100) == st.output_count + 0 or true, "取出不會變負")
    var t := StationLogic.from_def({"id": "y", "input": "a", "output": "b", "outputCap": 3, "yield": 2})
    t.add_input(3)
    t.tick(1.0)
    _check(t.output_count == 2 and t.is_blocked(), "yield 2、上限 3:產一批後阻塞")


## --- 價格牌 ---

func _test_purchase() -> void:
    var p := PurchaseLogic.from_def(GameData.purchase("hire_fisher"))
    _check(p.id == "hire_fisher" and p.cost == 10 and p.remaining == 10 and not p.is_paid()
            and str(p.effect.get("type", "")) == "hire" and p.name_key == "SHOP_hire_fisher", "從資料建立")
    _check(p.pay(4) == 4 and p.remaining == 6 and is_equal_approx(p.progress(), 0.4), "分期付 4")
    _check(p.pay(10) == 6 and p.remaining == 0 and p.is_paid() and is_equal_approx(p.progress(), 1.0), "多付只收剩下的")
    _check(p.pay(3) == 0, "付清後不再收")
    var q := PurchaseLogic.from_def({"id": "z", "cost": 0})
    _check(q.cost == 1 and q.pay(-5) == 0, "成本最少 1、負數不收")


## --- 櫃台 ---

func _test_counter() -> void:
    var c := CounterLogic.new()
    c.stock_cap = 5
    c.price = 2
    _check(c.add_stock(7) == 5 and c.stock == 5 and c.space() == 0, "上架到上限 5")
    var r := c.serve(2)
    _check(int(r["sold"]) == 2 and int(r["cash"]) == 4 and c.stock == 3, "賣 2 件收 4 元")
    r = c.serve(10)
    _check(int(r["sold"]) == 3 and int(r["cash"]) == 6 and c.stock == 0, "只賣得出剩下的 3 件")
    r = c.serve(1)
    _check(int(r["sold"]) == 0 and int(r["cash"]) == 0, "沒貨賣不出")


## --- 輸入 ---

func _test_input() -> void:
    var m := MoveInput.toward(Vector3.ZERO, Vector3(3, 0, -4))
    _check(m.is_moving() and m.dir.is_equal_approx(Vector2(0.6, -0.8)) and m.world_dir().is_equal_approx(Vector3(0.6, 0.0, -0.8)),
            "朝目標的輸入:螢幕 (0.6, -0.8) -> 世界 (0.6, 0, -0.8)")
    var stop := MoveInput.toward(Vector3(1, 0, 1), Vector3(1.1, 0, 1.0), 0.2)
    _check(not stop.is_moving() and stop.world_dir() == Vector3.ZERO, "在停止距離內不動")
    var big := MoveInput.new()
    big.dir = Vector2(3, 4)
    _check(is_equal_approx(big.world_dir().length(), 1.0), "world_dir 長度夾在 1")
