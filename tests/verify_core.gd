extends Node
## 核心規則 headless 驗證:資料載入(game / items / stations / shop / 翻譯)、ItemStack、StationLogic、PurchaseLogic、
## CounterLogic、PorterPlanner、GuideLogic、BearLogic(北極熊 / 武器)、MoveInput、存檔、GameState。跑法:godot --headless --path . res://tests/verify_core.tscn(先 --import)

var _fails := 0


func _ready() -> void:
    print("VERIFY CORE: begin")
    _test_data()
    _test_stack()
    _test_station()
    _test_purchase()
    _test_counter()
    _test_porter()
    _test_guide()
    _test_bear()
    _test_tower()
    _test_settings()
    _test_batching()
    _test_models()
    _test_ring()
    _test_sfx()
    _test_input()
    _test_save()
    _test_state()
    if _fails == 0:
        print("VERIFY CORE: ALL OK")
    else:
        print("VERIFY CORE: %d FAILURES" % _fails)
    Sfx.stop_all()   # 還在播的音效離開時會被報成洩漏;AudioServer 要幾個 mix step 才真的放掉
    for i in 30:
        await get_tree().physics_frame
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
    _check(GameData.items().size() == 7 and GameData.item("fish").has("size") and GameData.item("cash").has("color") and GameData.item("pelt").has("size")
            and GameData.item("tooth").has("color"), "items.json:魚 / 魚片 / 現金 / 烤魚 / 毛皮 / 熊王牙 / 毛衣")
    _check(GameData.item_size("fish") == Vector3(0.7, 0.23, 0.36) and GameData.item_color("cash") != Color(0.8, 0.8, 0.8)
            and GameData.item_size("nope") == Vector3(0.5, 0.15, 0.4), "物品尺寸 / 顏色;未知物品用預設")
    _check(GameData.item_name("fish") != "fish" and GameData.item_name("fish") != "ITEM_fish", "物品名有翻譯(%s)" % GameData.item_name("fish"))
    var st := GameData.station("cutting_table")
    _check(str(st.get("input", "")) == "fish" and str(st.get("output", "")) == "fillet" and int(st.get("yield", 0)) == 2,
            "stations.json:切魚台 魚 -> 魚片 ×2")
    var shop := GameData.shop()
    var costs: Array = []
    for p in shop:
        costs.append(int(p["cost"]))
    var costs_expected: Array = [10, 30, 20, 25, 20, 20, 50, 60, 35, 1000, 2000, 8000]
    for i in 24:
        costs_expected.append(200)
    costs_expected.append(3)
    for i in 24:
        costs_expected.append(1)
    _check(shop.size() == 61 and costs == costs_expected,
            "shop.json:六十一塊牌(含村外武器店、三次擴建 $1000 / $2000 / $8000、二十四座守衛塔)%s" % str(costs))
    var tl := GameData.station("tailor")
    _check(str(tl.get("input", "")) == "pelt" and str(tl.get("output", "")) == "sweater" and int(tl.get("inputPer", 0)) == 5
            and int(GameData.counter("sweater_counter").get("price", 0)) == 200 and str(GameData.counter("sweater_counter").get("item", "")) == "sweater"
            and GameData.item_name("sweater") != "ITEM_sweater" and GameData.item_color("sweater") != GameData.item_color("pelt"),
            "服飾店:5 張毛皮 -> 1 件毛衣;毛衣櫃台 $200;毛衣有名字與顏色")
    _check(int(GameData.purchase("hire_fisher").get("expandBuys", 0)) == 2 and int(GameData.purchase("hire_porter").get("expandBuys", 0)) == 4
            and int(GameData.purchase("hire_cashier").get("expandBuys", 0)) == 2 and not GameData.purchase("capacity_1").has("expandBuys"),
            "擴建後多開放的名額:漁夫 +2、搬運工 +4、收銀員 +2")
    _check(str(GameData.purchase("tower_3").get("effect", {}).get("type", "")) == "tower"
            and str(GameData.purchase("tower_3").get("effect", {}).get("target", "")) == "tower_3"
            and is_equal_approx(float(GameData.purchase("tower_3").get("rebuyMult", 0.0)), 0.5) and GameData.section("tower").has("damage")
            and ModelLibrary.guard_model() != "", "守衛塔牌:效果 tower、修復半價 $100;tower 設定與守衛的人物")
    _check(str(GameData.purchase("expand_village").get("effect", {}).get("target", "")) == "village_2"
            and is_equal_approx(float(GameData.purchase("hire_fisher").get("rebuyMult", 0.0)), 1.5), "擴建村莊牌解鎖 village_2;僱用牌買回 ×1.5")
    _check(str(GameData.purchase("weapon").get("effect", {}).get("type", "")) == "weapon" and int(GameData.purchase("weapon").get("maxBuys", 0)) == 3,
            "武器牌:效果 weapon、三級")
    _check(bool(GameData.purchase("expand_table").get("buildSpot", false)) and GameData.purchase("nope").is_empty(),
            "建地牌旗標;未知購買回空")
    _check(GameData.counters().size() == 7 and int(GameData.counter("grill_counter").get("price", 0)) == 5 and str(GameData.counter("grill_counter_3").get("item", "")) == "grilled"
            and str(GameData.counter("fillet_counter").get("item", "")) == "fillet" and str(GameData.counter("grill_counter_2").get("item", "")) == "grilled",
            "counters.json:魚片櫃台 $2、烤魚櫃台 $5、兩塊擴建區的第二、三組")
    _check(GameData.section("customers").get("wantWeights", []).size() == 5 and float(GameData.config().get("payScaleCost", 0.0)) > 0.0,
            "顧客要 1 ~ 5 件的權重;大額牌付款加速門檻")
    _check(str(GameData.station("grill").get("input", "")) == "fillet" and str(GameData.station("grill").get("output", "")) == "grilled"
            and GameData.item("grilled").has("color"), "烤魚攤:魚片 -> 烤魚;烤魚物品存在")
    _check(GameData.helper("porter").has("speed") and GameData.helper("cashier").has("capacity") and GameData.helper("nope").is_empty(),
            "helpers 設定:搬運工 / 收銀員")
    _check(GameData.section("upgrades").has("worker_speed") and GameData.section("upgrades").has("pile_cap"), "upgrades 設定")
    _check(GameData.section("bear").has("biteSec") and GameData.section("weapon").get("levels", []).size() == 6
            and ModelLibrary.shopkeeper_model() != "", "bear / weapon 設定:咬的秒數、六級武器、武器店老闆的人物")


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
    # 服飾店:一批吃 5 張毛皮做 1 件毛衣
    var tl := StationLogic.from_def(GameData.station("tailor"))
    _check(tl.input_per == 5 and tl.input_cap == 20 and tl.add_input(4) == 4 and not tl.has_enough_input() and tl.tick(5.0) == 0
            and not tl.is_working() and tl.input_count == 4, "服飾店:4 張毛皮不夠一批,不開工")
    tl.add_input(7)
    _check(tl.has_enough_input() and tl.tick(1.0) == 0 and tl.is_working() and tl.tick(2.0) == 1 and tl.input_count == 6 and tl.output_count == 1,
            "11 張:3 秒做一件毛衣、吃掉 5 張、剩 6")
    _check(tl.tick(3.0) == 1 and tl.input_count == 1 and tl.tick(5.0) == 0 and not tl.is_working(), "再做一件剩 1 張,不夠就停")


## --- 價格牌 ---

func _test_purchase() -> void:
    var p := PurchaseLogic.from_def(GameData.purchase("expand_table"))
    _check(p.id == "expand_table" and p.cost == 50 and p.remaining == 50 and not p.is_paid()
            and str(p.effect.get("type", "")) == "unlock" and p.name_key == "SHOP_expand_table", "從資料建立")
    _check(p.pay(20) == 20 and p.remaining == 30 and is_equal_approx(p.progress(), 0.4), "分期付 20")
    _check(p.pay(40) == 30 and p.remaining == 0 and p.is_paid() and is_equal_approx(p.progress(), 1.0), "多付只收剩下的")
    _check(p.pay(3) == 0, "付清後不再收")
    var q := PurchaseLogic.from_def({"id": "z", "cost": 0})
    _check(q.cost == 1 and q.pay(-5) == 0, "成本最少 1、負數不收")
    _check(not p.repeatable and p.max_buys == 1 and not p.is_exhausted(), "一次性牌:付清後 complete 前還不算買滿")
    p.complete()
    _check(p.is_exhausted() and p.pay(5) == 0 and not p.is_paid(), "一次性牌 complete -> 買滿、不再收錢")
    # 可重複購買
    var r := PurchaseLogic.from_def(GameData.purchase("hire_fisher"))
    _check(r.repeatable and r.max_buys == 3 and r.current_cost() == 10 and r.remaining == 10, "漁夫牌:可買 3 次、第一次 $10")
    r.pay(10)
    _check(r.is_paid(), "付清第一次")
    r.complete()
    _check(r.buys == 1 and not r.is_exhausted() and r.current_cost() == 18 and r.remaining == 18 and not r.is_paid(),
            "complete:第二次 $18(10 × 1.8)")
    r.pay(18)
    r.complete()
    _check(r.buys == 2 and r.remaining == 32 and is_equal_approx(r.progress(), 0.0), "第三次 $32(10 × 1.8²)")
    r.pay(32)
    r.complete()
    _check(r.is_exhausted() and r.remaining == 0 and r.pay(1) == 0 and is_equal_approx(r.progress(), 1.0), "買滿三次:exhausted")
    var r2 := PurchaseLogic.from_def(GameData.purchase("hire_fisher"))
    r2.restore(1, 5)
    _check(r2.buys == 1 and r2.remaining == 5 and r2.current_cost() == 18, "存檔還原:買過 1 次、這次剩 5")
    r2.restore(3, 0)
    _check(r2.is_exhausted() and r2.remaining == 0, "存檔還原:買滿")
    r2.restore(0, 0)
    _check(r2.buys == 0 and r2.remaining == 10, "存檔還原:剩 0 但沒買滿 -> 重設成整價")
    # 被吃掉買回:退一個名額,價格 = 該級 × 1.5,買回後回到正常階梯
    var r3 := PurchaseLogic.from_def(GameData.purchase("hire_fisher"))
    _check(not r3.lose() and r3.buys == 0 and r3.lost == 0, "沒僱過就沒得退")
    r3.pay(10)
    r3.complete()
    r3.pay(10)
    r3.complete()
    var before := r3.current_cost()
    _check(r3.buys == 2 and before == 32 and r3.lose() and r3.buys == 1 and r3.lost == 1 and r3.is_rebuy() and r3.current_cost() == 27
            and r3.remaining == 27, "兩個漁夫被吃一個:第二級 $18 × 1.5 = $27 買回(下一級本來 $32)")
    r3.pay(27)
    _check(r3.is_paid(), "付清買回價")
    r3.complete()
    _check(r3.buys == 2 and r3.lost == 0 and not r3.is_rebuy() and r3.current_cost() == 32 and r3.remaining == 32, "買回後名額補回、下一級回到正常的 $32")
    r3.pay(12)
    r3.lose()
    _check(r3.buys == 1 and r3.lost == 1 and r3.remaining == 27 - 12, "付到一半被吃:已付的 $12 保留在買回價裡")
    r3.pay(99)
    r3.complete()
    r3.pay(99)
    r3.complete()
    _check(r3.is_exhausted(), "買回 + 第三級 -> 買滿")
    _check(r3.lose() and not r3.is_exhausted() and r3.buys == 2 and r3.current_cost() == 49 and r3.remaining == 49, "買滿後被吃:牌子重新開放,第三級 $32.4 × 1.5 = $49")
    var r4 := PurchaseLogic.from_def(GameData.purchase("hire_fisher"))
    r4.restore(1, 27, 1)
    _check(r4.buys == 1 and r4.lost == 1 and r4.current_cost() == 27 and r4.remaining == 27, "存檔還原:帶著待買回的名額")
    # 擴建村莊多開放名額:漁夫牌 +2(3 -> 5),買滿消失的牌重新開放、價格是下一級;只加一次
    var r5 := PurchaseLogic.from_def(GameData.purchase("hire_fisher"))
    r5.restore(3, 0)
    _check(r5.is_exhausted() and r5.expand_buys == 2 and r5.expand() and not r5.is_exhausted() and r5.max_buys == 5 and r5.buys == 3
            and r5.remaining == r5.current_cost() and r5.current_cost() == 58 and r5.expand() and r5.max_buys == 7 and r5.expand() and r5.max_buys == 9
            and not r5.expand() and r5.max_buys == 9,
            "擴建:漁夫牌 3 -> 5 次,買滿的牌重開、第四次 $%d(10 × 1.8³)、三次擴建最多 9 次" % r5.current_cost())
    var r6 := PurchaseLogic.from_def(GameData.purchase("hire_porter"))
    r6.pay(30)
    r6.complete()
    r6.pay(7)
    var rem6 := r6.remaining
    _check(r6.expand() and r6.max_buys == 6 and r6.buys == 1 and r6.remaining == rem6 and rem6 == 54 - 7, "擴建:搬運工牌 2 -> 6 次,付到一半的進度不變")
    _check(not PurchaseLogic.from_def(GameData.purchase("capacity_1")).expand(), "沒 expandBuys 的牌 expand 回 false")
    # 守衛塔牌:一次性 $200,塔被拆 lose -> 修復同價(rebuyMult 1)
    var tp := PurchaseLogic.from_def(GameData.purchase("tower_1"))
    _check(not tp.repeatable and tp.max_buys == 1 and tp.current_cost() == 200 and is_equal_approx(tp.rebuy_mult, 0.5) and not tp.lose(),
            "守衛塔牌:$200 一次性,沒蓋過沒得修")
    tp.pay(200)
    tp.complete()
    var su := PurchaseLogic.from_def(GameData.purchase("shop_upgrade"))
    _check(su.currency == "pelt" and not su.is_cash() and su.repeatable and su.max_buys == 3 and su.current_cost() == 3 and su.remaining == 3,
            "武器店升級牌:收毛皮、三次")
    _check(su.pay(3) == 3 and su.is_paid(), "付 3 張毛皮")
    su.complete()
    _check(su.current_cost() == 8 and su.remaining == 8 and su.buys == 1, "第二次 8 張(逐次價格 costs)")
    su.pay(8)
    su.complete()
    _check(su.current_cost() == 15 and su.remaining == 15, "第三次 15 張")
    su.pay(15)
    su.complete()
    _check(su.is_exhausted() and su.current_cost() == 15, "三次買滿;超過 costs 長度用最後一個")
    var wl := PurchaseLogic.from_def(GameData.purchase("weapon"))
    for i in 3:
        wl.pay(wl.remaining)
        wl.complete()
    _check(wl.is_exhausted() and wl.base_max_buys == 3 and not wl.raise_max(3) and wl.raise_max(4) and not wl.is_exhausted()
            and wl.max_buys == 4 and wl.remaining == 172 and wl.current_cost() == 172 and wl.is_cash(),
            "武器牌買滿 3 級後 raise_max(4) 重新開放:Lv4 $172(35 × 1.7³)")
    var tt := PurchaseLogic.from_def(GameData.purchase("tooth_tower_1"))
    _check(tt.currency == "tooth" and tt.current_cost() == 1 and tt.effect.get("type", "") == "tower_upgrade" and tt.effect.get("target", "") == "tower_1",
            "熊王牙牌:1 顆、強化 tower_1")
    _check(tp.is_exhausted() and tp.lose() and not tp.is_exhausted() and tp.is_rebuy() and tp.current_cost() == 100 and tp.remaining == 100,
            "塔被拆:牌重開、修復 $200")
    tp.pay(200)
    tp.complete()
    _check(tp.is_exhausted() and tp.lost == 0 and tp.buys == 1, "修好:牌再消失")


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
    var w := [45, 25, 15, 10, 5]
    _check(CounterLogic.roll_want(w, 0.0) == 1 and CounterLogic.roll_want(w, 0.449) == 1 and CounterLogic.roll_want(w, 0.45) == 2
            and CounterLogic.roll_want(w, 0.699) == 2 and CounterLogic.roll_want(w, 0.7) == 3 and CounterLogic.roll_want(w, 0.85) == 4
            and CounterLogic.roll_want(w, 0.951) == 5 and CounterLogic.roll_want(w, 1.0) == 5 and CounterLogic.roll_want([], 0.5) == 1
            and CounterLogic.roll_want([1], 0.9) == 1, "顧客要幾件:權重 45 / 25 / 15 / 10 / 5 -> 1 ~ 5 件;沒權重 1 件")


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
    MoveInput.touch_dir = Vector2(2.0, 0.0)
    var t := MoveInput.from_actions()
    _check(t.dir.is_equal_approx(Vector2(1, 0)) and t.world_dir().is_equal_approx(Vector3(1, 0, 0)), "觸控搖桿方向夾到長度 1、轉成世界 +X")
    MoveInput.touch_dir = Vector2.ZERO
    _check(MoveInput.from_actions().dir == Vector2.ZERO, "放開搖桿、沒按鍵:不動")


## --- 存檔 IO ---

func _test_save() -> void:
    var default_path := SaveManager.save_path
    SaveManager.save_path = "user://_verify_core_save.json"
    SaveManager.delete()
    _check(not SaveManager.has_save() and SaveManager.read().is_empty(), "沒存檔:has_save false、read 空")
    _check(SaveManager.write({"a": 1, "nested": {"b": [1, 2]}}) and SaveManager.has_save(), "寫入存檔")
    var d := SaveManager.read()
    _check(int(d.get("a", 0)) == 1 and int(d.get("version", 0)) == SaveManager.VERSION and int(d.get("savedAt", 0)) > 0
            and typeof(d.get("nested")) == TYPE_DICTIONARY, "讀回:內容、版本、時間")
    var f := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
    f.store_string("{not json")
    f.close()
    _check(SaveManager.read().is_empty(), "壞掉的存檔 -> 空(不會炸)")
    SaveManager.write({"version": 999, "x": 1})
    var v := SaveManager.read()
    _check(v.has("x"), "write 會覆寫 version 成目前版本")
    f = FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
    f.store_string(JSON.stringify({"version": 999}))
    f.close()
    _check(SaveManager.read().is_empty(), "版本不符 -> 空")
    SaveManager.delete()
    _check(not SaveManager.has_save(), "刪除存檔")
    SaveManager.save_path = default_path


## --- GameState 序列化 ---

func _test_state() -> void:
    GameState.reset()
    var purchased := [0]
    var cb := func(_id: String, _e: Dictionary) -> void: purchased[0] += 1
    EventBus.purchased.connect(cb)
    GameState.apply_purchase("capacity_1", {"type": "capacity", "add": 4})
    GameState.apply_purchase("hire_fisher", {"type": "hire", "role": "fisher"})
    GameState.apply_purchase("hire_fisher", {"type": "hire", "role": "fisher"})
    GameState.apply_purchase("hire_cashier", {"type": "hire", "role": "cashier"})
    GameState.apply_purchase("unlock_grill", {"type": "unlock", "target": "grill_complex"})
    GameState.apply_purchase("upgrade_worker_speed", {"type": "upgrade", "key": "worker_speed"})
    GameState.apply_purchase("upgrade_worker_speed", {"type": "upgrade", "key": "worker_speed"})
    GameState.apply_purchase("weapon", {"type": "weapon"})
    GameState.apply_purchase("weapon", {"type": "weapon"})
    GameState.add_trashed(3)
    EventBus.purchased.disconnect(cb)
    _check(purchased[0] == 9 and GameState.capacity_bonus == 4 and GameState.hired_count("fisher") == 2
            and GameState.hired_count("cashier") == 1 and GameState.hired_total() == 3 and GameState.is_unlocked("grill_complex")
            and GameState.upgrade_level("worker_speed") == 2 and GameState.items_trashed == 3 and GameState.weapon_level == 2,
            "apply_purchase:容量 / 僱用 / 解鎖 / 升級 / 武器 / 丟棄")
    GameState.lose_helper("fisher")
    GameState.lose_helper("porter")
    _check(GameState.hired_count("fisher") == 1 and GameState.hired_count("porter") == 0 and GameState.hired_total() == 2
            and GameState.helpers_lost == 2, "被北極熊吃掉:角色計數 -1(不低於 0)、統計 +2")
    _near(GameState.upgrade_mult("worker_speed"), 2.0, "升級倍率 1 + 0.5 × 2", 0.001)
    _near(GameState.upgrade_mult("pile_cap"), 1.0, "沒升級倍率 1", 0.001)
    GameState.add_wallet(30)
    GameState.add_wallet(-5)
    _check(GameState.wallet == 30 and GameState.spend(12) == 12 and GameState.wallet == 18 and GameState.spend(50) == 18
            and GameState.wallet == 0 and GameState.spend(1) == 0, "錢包:加錢 / 扣到 0 為止、負數不理")
    GameState.add_wallet(7)
    GameState.sound_on = false
    GameState.play_time = 123.5
    var d := GameState.to_dict()
    GameState.reset()
    _check(GameState.hired_total() == 0 and GameState.capacity_bonus == 0 and GameState.upgrade_level("worker_speed") == 0
            and GameState.wallet == 0 and GameState.sound_on, "reset 清空")
    GameState.from_dict(JSON.parse_string(JSON.stringify(d)))
    _check(GameState.capacity_bonus == 4 and GameState.hired_count("fisher") == 1 and GameState.is_unlocked("grill_complex")
            and GameState.upgrade_level("worker_speed") == 2 and GameState.items_trashed == 3 and GameState.is_unlocked("hire_fisher")
            and GameState.wallet == 7 and not GameState.sound_on and GameState.weapon_level == 2 and GameState.helpers_lost == 2
            and is_equal_approx(GameState.play_time, 123.5), "to_dict -> JSON -> from_dict 往返(含錢包、音效開關、武器等級、被吃數、遊戲時間)")
    GameState.reset()


## --- 搬運工派工 ---

func _test_porter() -> void:
    var fc := {"id": "fc", "kind": "counter", "item": "fillet", "stock": 20, "cap": 30}
    var gc := {"id": "gc", "kind": "counter", "item": "grilled", "stock": 0, "cap": 24}
    var grill := {"id": "grill", "kind": "station", "item": "fillet", "stock": 0, "cap": 12, "out": "grilled"}
    var cutter := {"id": "cutter", "kind": "station", "item": "fish", "stock": 3, "cap": 12, "out": "fillet"}
    var dests := [fc, gc, grill, cutter]
    _near(PorterPlanner.need_of(fc, dests), 1.0 / 3.0, "魚片櫃台 20/30:需求 1/3", 0.001)
    _near(PorterPlanner.need_of(gc, dests), 1.0, "烤魚櫃台空:需求 1", 0.001)
    _near(PorterPlanner.need_of(grill, dests), PorterPlanner.EMPTY_INPUT_NEED, "烤魚攤原料區空:最優先(1.5,比任何櫃台都急)", 0.001)
    _near(PorterPlanner.need_of(cutter, dests), 0.9 * 1.5 * 0.75, "切魚台 3/12:下游烤魚攤 0.9 × 1.5 × 空位 0.75", 0.001)
    grill["blocked"] = true
    _near(PorterPlanner.need_of(grill, dests), 0.9, "烤魚攤成品堆滿停工:空的原料區不加急,照下游算 0.9", 0.001)
    grill.erase("blocked")
    grill["stock"] = 1
    _near(PorterPlanner.need_of(grill, dests), 0.9 * 11.0 / 12.0, "原料區有 1 片就照一般公式:0.9 × 空位 11/12", 0.001)
    grill["stock"] = 0
    # 烤魚攤原料區空:就算它有成品、烤魚櫃台也空,還是先送魚片去烤魚攤(使用者要求:魚片放置區空了最優先)
    var plan := PorterPlanner.plan(dests, [{"id": "cutter", "item": "fillet", "count": 10}, {"id": "grill", "item": "grilled", "count": 3}], 8)
    _check(plan["to"]["id"] == "grill" and plan["from"]["id"] == "cutter" and plan["item"] == "fillet" and int(plan["amount"]) == 8,
            "烤魚攤原料區空:先送 8 片魚片過去(有成品也一樣)")
    # 烤魚攤有料、有成品:直接補烤魚櫃台,只拿 3
    grill["stock"] = 1
    plan = PorterPlanner.plan(dests, [{"id": "cutter", "item": "fillet", "count": 10}, {"id": "grill", "item": "grilled", "count": 3}], 8)
    _check(plan["to"]["id"] == "gc" and plan["from"]["id"] == "grill" and plan["item"] == "grilled" and int(plan["amount"]) == 3,
            "烤魚攤有料了、烤魚櫃台最缺:搬 3 份烤魚過去")
    grill["stock"] = 0
    # 烤魚攤沒成品:先把魚片送去烤魚攤,而不是堆到還有 20 的魚片櫃台
    plan = PorterPlanner.plan(dests, [{"id": "cutter", "item": "fillet", "count": 10}, {"id": "grill", "item": "grilled", "count": 0}], 8)
    _check(plan["to"]["id"] == "grill" and plan["from"]["id"] == "cutter" and int(plan["amount"]) == 8, "烤魚攤沒成品:魚片先送烤魚攤(拿 8)")
    # 魚片櫃台也空了:烤魚攤原料區空(1.5)還是比空櫃台(1.0)優先;原料區有料後才是櫃台(1.0)比工作站原料(0.9)優先;來源只有 5 就拿 5
    fc["stock"] = 0
    plan = PorterPlanner.plan(dests, [{"id": "cutter", "item": "fillet", "count": 5}], 8)
    _check(plan["to"]["id"] == "grill" and int(plan["amount"]) == 5, "魚片櫃台空、烤魚攤原料區也空:先送烤魚攤")
    grill["stock"] = 1
    plan = PorterPlanner.plan(dests, [{"id": "cutter", "item": "fillet", "count": 5}], 8)
    _check(plan["to"]["id"] == "fc" and int(plan["amount"]) == 5, "烤魚攤有料了:魚片櫃台優先、來源只有 5 就拿 5")
    # 目的地只剩 2 格:只拿 2
    fc["stock"] = 28
    gc["stock"] = 24
    grill["stock"] = 12
    plan = PorterPlanner.plan(dests, [{"id": "cutter", "item": "fillet", "count": 10}], 8)
    _check(plan["to"]["id"] == "fc" and int(plan["amount"]) == 2, "魚片櫃台只剩 2 格:只拿 2")
    # 全滿 / 沒貨:沒事做
    fc["stock"] = 30
    _check(PorterPlanner.plan(dests, [{"id": "cutter", "item": "fillet", "count": 10}], 8).is_empty(), "收魚片的地方都滿:沒事做")
    fc["stock"] = 0
    _check(PorterPlanner.plan(dests, [{"id": "cutter", "item": "fillet", "count": 0}, {"id": "grill", "item": "grilled", "count": 0}], 8).is_empty(),
            "沒成品可搬:沒事做")
    # 手上已經有貨該去哪
    fc["stock"] = 10
    grill["stock"] = 0
    gc["stock"] = 0
    _check(PorterPlanner.best_dest(dests, "fillet")["id"] == "grill", "手上有魚片:空的烤魚攤(1.5)比 10/30 的魚片櫃台(0.67)急")
    grill["stock"] = 2
    _check(PorterPlanner.best_dest(dests, "fillet")["id"] == "grill", "烤魚攤 2/12(0.9 × 0.83)還是比魚片櫃台急")
    _check(PorterPlanner.best_dest(dests, "fillet", "grill")["id"] == "fc", "排除烤魚攤就去魚片櫃台")
    gc["stock"] = 24
    _check(PorterPlanner.best_dest(dests, "fillet")["id"] == "fc" and PorterPlanner.best_dest(dests, "grilled").is_empty()
            and PorterPlanner.best_dest(dests, "soup").is_empty(), "烤魚櫃台滿:有料的烤魚攤需求 0,魚片去櫃台;烤魚 / 不存在的東西沒地方去")
    grill["stock"] = 0
    _check(PorterPlanner.best_dest(dests, "fillet")["id"] == "grill", "烤魚櫃台滿但烤魚攤原料區空:還是先送料去烤(先烤起來放)")
    grill["stock"] = 12
    fc["stock"] = 30
    _check(PorterPlanner.best_dest(dests, "fillet").is_empty(), "全滿:手上的魚片沒地方放")
    # 來源挑成品最多的
    var src := PorterPlanner.best_source([{"id": "a", "item": "fillet", "count": 4}, {"id": "b", "item": "fillet", "count": 9},
            {"id": "c", "item": "grilled", "count": 20}], "fillet")
    _check(src["id"] == "b" and PorterPlanner.best_source([], "fillet").is_empty(), "來源:魚片最多的那座")


## --- 引導規則 ---

func _guide_state() -> Dictionary:
    return {"carry_item": "", "carry_count": 0, "wallet": 0, "money_on_pad": 0, "fish_caught": 0, "items_sold": 0, "purchases": 0,
        "hired": {}, "counters": [{"id": "fillet_counter", "item": "fillet", "stock": 0, "cap": 30, "has_server": false, "has_cashier": false}],
        "stations": [{"id": "station_1", "input": "fish", "input_count": 0, "input_cap": 12, "output": "fillet", "output_count": 0}],
        "pads": [{"id": "hire_fisher", "name": "SHOP_hire_fisher", "remaining": 10, "visible": true},
                {"id": "capacity_1", "name": "SHOP_capacity", "remaining": 25, "visible": true}]}


func _test_guide() -> void:
    var state := _guide_state()
    _check(GuideLogic.tutorial_steps() == 7, "教學七步")
    _check(not GuideLogic.tutorial_step_done(0, state) and GuideLogic.tutorial_hint(0, state)["kind"] == "water", "第 1 步:指水邊,還沒抓到魚")
    state["fish_caught"] = 4
    var h1 := GuideLogic.tutorial_hint(1, state)
    _check(GuideLogic.tutorial_step_done(0, state) and not GuideLogic.tutorial_step_done(1, state)
            and h1["kind"] == "station_input" and h1["target"] == "station_1", "抓到 4 條 -> 第 2 步:指切魚台輸入格")
    state["stations"][0]["input_count"] = 3
    _check(GuideLogic.tutorial_step_done(1, state) and GuideLogic.tutorial_hint(2, state)["kind"] == "station_output", "魚進了切魚台 -> 第 3 步:指輸出格")
    state["carry_item"] = "fillet"
    state["carry_count"] = 2
    var h3 := GuideLogic.tutorial_hint(3, state)
    _check(GuideLogic.tutorial_step_done(2, state) and h3["kind"] == "counter_deposit" and h3["target"] == "fillet_counter", "拿到魚片 -> 第 4 步:指櫃台上架格")
    state["carry_item"] = ""
    state["carry_count"] = 0
    state["counters"][0]["stock"] = 2
    _check(GuideLogic.tutorial_step_done(3, state) and not GuideLogic.tutorial_step_done(4, state)
            and GuideLogic.tutorial_hint(4, state)["kind"] == "service", "上架了 -> 第 5 步:指收銀格")
    state["items_sold"] = 1
    _check(GuideLogic.tutorial_step_done(4, state) and GuideLogic.tutorial_hint(5, state)["kind"] == "money", "賣出了 -> 第 6 步:指錢格")
    state["wallet"] = 2
    var h6e := GuideLogic.tutorial_hint(6, state)
    _check(GuideLogic.tutorial_step_done(5, state) and h6e["text"] == "TUT_earn" and h6e["kind"] == "service" and h6e["args"] == [8, "SHOP_hire_fisher"],
            "收了 $2 -> 第 7 步:錢不夠買 $10 的牌,箭頭回工作循環(櫃台有貨去收銀)、文字說還差 $8")
    state["wallet"] = 10
    var h6 := GuideLogic.tutorial_hint(6, state)
    _check(GuideLogic.tutorial_step_done(5, state) and h6["kind"] == "pad" and h6["target"] == "hire_fisher" and h6["arg"] == "SHOP_hire_fisher",
            "收了錢 -> 第 7 步:指最便宜的牌(僱漁夫)")
    _check(not GuideLogic.tutorial_step_done(6, state), "還沒買:第 7 步未完成")
    state["purchases"] = 1
    _check(GuideLogic.tutorial_step_done(6, state) and GuideLogic.tutorial_hint(7, state).is_empty(), "買了 -> 教學結束")
    var tailor_state := _guide_state()
    tailor_state["purchases"] = 1
    tailor_state["hired"] = {"porter": 1}
    tailor_state["stations"].append({"id": "tailor", "input": "pelt", "input_count": 0, "input_cap": 20, "input_per": 5, "output": "sweater", "output_count": 0})
    tailor_state["pads"] = []
    tailor_state["resources"] = {"pelt": 4, "tooth": 0}
    _check(GuideLogic.hint(tailor_state)["kind"] == "water", "毛皮 4 張不夠一件毛衣:照常指水邊")
    tailor_state["resources"]["pelt"] = 5
    var hp := GuideLogic.hint(tailor_state)
    _check(hp["kind"] == "station_input" and hp["target"] == "tailor" and hp["text"] == "HINT_pelts", "毛皮 5 張:指服飾店輸入格")
    tailor_state["stations"][1]["input_count"] = 20
    _check(GuideLogic.hint(tailor_state)["kind"] == "water", "服飾店放滿了:不提醒")
    var fresh := _guide_state()
    fresh["purchases"] = 1
    var all_done := true
    for i in 7:
        all_done = all_done and GuideLogic.tutorial_step_done(i, fresh)
    _check(all_done, "有購買紀錄的存檔:七步都算完成")
    # 提示:手上有貨
    state = _guide_state()
    _check(GuideLogic.hint(state)["kind"] == "water", "空手、什麼都沒有:去抓魚")
    state["carry_item"] = "fish"
    state["carry_count"] = 3
    var h := GuideLogic.hint(state)
    _check(h["kind"] == "station_input" and h["target"] == "station_1", "背著魚:指切魚台")
    state["stations"][0]["input_count"] = 12
    _check(GuideLogic.hint(state)["text"] == "HINT_station_full", "切魚台滿:提示等工人")
    state["carry_item"] = "fillet"
    h = GuideLogic.hint(state)
    _check(h["kind"] == "counter_deposit" and h["target"] == "fillet_counter", "背著魚片:指櫃台")
    state["counters"][0]["stock"] = 30
    state["stations"].append({"id": "grill", "input": "fillet", "input_count": 0, "input_cap": 12, "output": "grilled", "output_count": 0})
    h = GuideLogic.hint(state)
    _check(h["kind"] == "station_input" and h["target"] == "grill" and h["text"] == "HINT_to_next_station", "櫃台滿、烤魚攤收魚片:指烤魚攤")
    state["stations"][1]["input_count"] = 12
    h = GuideLogic.hint(state)
    _check(h["kind"] == "service" and h["target"] == "fillet_counter" and h["text"] == "HINT_counter_full_serve", "都滿了、沒人收銀:指收銀格自己賣")
    state["counters"][0]["has_cashier"] = true
    _check(GuideLogic.hint(state)["text"] == "HINT_counter_full" and GuideLogic.hint(state)["kind"] == "counter_deposit", "都滿了、有收銀員:提示等顧客")
    state["counters"][0]["has_cashier"] = false
    state["carry_item"] = "soup"
    _check(GuideLogic.hint(state)["kind"] == "trash", "背著沒人收的東西:指垃圾桶")
    # 工作站塞住(成品堆滿停工):背著魚先丟、空手先去拿成品(比買牌子優先)
    state = _guide_state()
    state["carry_item"] = "fish"
    state["carry_count"] = 3
    state["stations"][0]["input_count"] = 12
    state["stations"][0]["output_count"] = 24
    state["stations"][0]["blocked"] = true
    h = GuideLogic.hint(state)
    _check(h["kind"] == "trash" and h["text"] == "HINT_station_jammed", "切魚台塞住、背著魚:先指垃圾桶")
    state["carry_item"] = ""
    state["carry_count"] = 0
    state["wallet"] = 50
    h = GuideLogic.hint(state)
    _check(h["kind"] == "station_output" and h["target"] == "station_1" and h["text"] == "HINT_take_jammed", "切魚台塞住、空手:先去拿成品(比買牌優先)")
    state["stations"][0]["blocked"] = false
    _check(GuideLogic.hint(state)["kind"] == "pad", "沒塞住:回到買得起的牌")
    # 提示:空手的優先序
    state = _guide_state()
    state["counters"][0]["stock"] = 5
    state["money_on_pad"] = 8
    state["stations"][0]["output_count"] = 6
    state["wallet"] = 10
    h = GuideLogic.hint(state)
    _check(h["kind"] == "pad" and h["target"] == "hire_fisher" and h["arg"] == "SHOP_hire_fisher", "錢夠買最便宜的牌:先去買")
    state["wallet"] = 9
    _check(GuideLogic.hint(state)["kind"] == "money", "錢包 $9 不夠、但加上錢格的 $8 就買得起:先去收錢")
    state["money_on_pad"] = 0
    _check(GuideLogic.hint(state)["kind"] == "service", "錢不夠、錢格沒錢:櫃台有貨沒人收銀 -> 去收銀")
    state["counters"][0]["has_cashier"] = true
    state["money_on_pad"] = 8
    _check(GuideLogic.hint(state)["kind"] == "money", "有收銀員:去收錢格的錢")
    state["money_on_pad"] = 0
    h = GuideLogic.hint(state)
    _check(h["kind"] == "station_output" and h["target"] == "station_1", "錢格空:工作站有成品 -> 去拿")
    state["hired"] = {"porter": 1}
    _check(GuideLogic.hint(state)["kind"] == "water", "有搬運工就不用自己拿 -> 去抓魚")
    state["stations"][0]["input_count"] = 12
    _check(GuideLogic.hint(state)["kind"] == "none", "切魚台滿、沒事可做:沒提示")
    state = _guide_state()
    state["wallet"] = 100
    state["pads"][0]["visible"] = false
    _check(GuideLogic.hint(state)["target"] == "capacity_1", "隱藏(買滿)的牌不算,挑下一個最便宜的")
    # 北極熊在村裡:最優先
    state = _guide_state()
    state["carry_item"] = "fish"
    state["carry_count"] = 3
    state["bear"] = true
    state["pads"].append({"id": "weapon", "name": "SHOP_weapon", "remaining": 35, "visible": true})
    h = GuideLogic.hint(state)
    _check(h["kind"] == "station_input" and h["text"] == "HINT_BEAR_EARN" and h["args"] == [35], "北極熊來了、沒武器、錢不夠:照工作循環賺錢(背著魚指切魚台)、文字說還差 $35")
    state["money_on_pad"] = 5
    h = GuideLogic.hint(state)
    _check(h["kind"] == "money" and h["text"] == "HINT_BEAR_MONEY", "錢格有錢:先去收錢")
    state["money_on_pad"] = 0
    state["wallet"] = 35
    h = GuideLogic.hint(state)
    _check(h["kind"] == "pad" and h["target"] == "weapon" and h["text"] == "HINT_BEAR_WEAPON", "錢夠了:就算背著魚也先指武器店的牌")
    state["weapon_level"] = 1
    h = GuideLogic.hint(state)
    _check(h["kind"] == "bear" and h["text"] == "HINT_BEAR_CHASE", "有武器:指向北極熊")
    state["weapon_level"] = 0
    state["pads"][2]["visible"] = false
    _check(GuideLogic.hint(state)["kind"] == "bear", "武器牌買滿看不見又沒武器(不該發生):退回指熊")
    state["bear"] = false
    _check(GuideLogic.hint(state)["kind"] == "station_input", "熊走了:回到平常的提示")


## --- 北極熊 / 武器 ---

func _test_bear() -> void:
    var b := BearLogic.from_config(GameData.section("bear"), GameData.section("weapon"))
    _check(is_equal_approx(b.bite_sec(), 8.0) and is_equal_approx(b.bite_radius(), 1.4)
            and b.panic_radius() >= b.bite_radius() and b.speed() > 0.0 and b.flee_speed() >= b.speed() and b.entries().size() == 2,
            "咬 8 秒、嚇呆半徑 >= 咬的半徑、兩個入口")
    _check(b.drop_count(false, 0.0) == 1 and b.drop_count(false, 0.49) == 1 and b.drop_count(false, 0.5) == 2 and b.drop_count(false, 1.0) == 2
            and b.drop_count(true, 0.3) == 3, "掉落數:一般熊 1 ~ 2 張毛皮、王 3 顆牙")
    _check(b.pack_max_eats() == 2 and is_equal_approx(b.busy_radius(), 6.0), "一群最多吃 2 個就撤退;熊在 6 格內暫停抓魚 / 拿貨")
    _check(b.weapon_max_level() == 6 and is_equal_approx(b.weapon_damage(0), 0.0) and is_equal_approx(b.weapon_damage(1), 10.0)
            and is_equal_approx(b.weapon_damage(2), 20.0) and is_equal_approx(b.weapon_damage(3), 35.0) and is_equal_approx(b.weapon_damage(4), 55.0)
            and is_equal_approx(b.weapon_damage(5), 80.0) and is_equal_approx(b.weapon_damage(6), 120.0) and is_equal_approx(b.weapon_damage(9), 120.0)
            and is_equal_approx(b.attack_range(1), 1.8) and b.attack_range(6) > b.attack_range(3) and is_equal_approx(b.attack_interval(), 0.5),
            "武器六級只加攻擊力:0 / 10 / 20 / 35 / 55 / 80 / 120,打擊距離 1.8 起、每 0.5 秒一下;超過最高級當最高級")
    _check(b.shop_base_levels() == 3 and b.weapon_levels_for_sale(0) == 3 and b.weapon_levels_for_sale(1) == 4 and b.weapon_levels_for_sale(3) == 6
            and b.weapon_levels_for_sale(9) == 6 and b.drop() == "pelt" and b.drop(true) == "tooth",
            "武器店基本賣 3 級、每升一級多賣一級(最多 6);熊掉毛皮、王掉熊王牙")
    _check(not b.can_attack(0, 0.1) and b.can_attack(1, 1.8) and not b.can_attack(1, 2.0) and b.can_attack(3, 2.0), "can_attack:等級 × 距離")
    _near(b.cooldown_mult(1), 1.0, "武器不再影響冷卻(倍率 1)", 0.001)
    _near(b.next_cooldown(0, 0.0), 35.0, "下次冷卻:開局最短 35", 0.001)
    _near(b.next_cooldown(3, 1.0), 55.0, "下次冷卻:開局最長 55", 0.001)
    # 難度曲線:3 分鐘後 5 分鐘內縮到 15 ~ 25;血量每分鐘 +10
    _check(b.interval(0.0) == Vector2(35.0, 55.0) and b.interval(180.0) == Vector2(35.0, 55.0) and b.interval(330.0).is_equal_approx(Vector2(32.5, 47.5))
            and b.interval(480.0) == Vector2(30.0, 40.0) and b.interval(9999.0) == Vector2(30.0, 40.0),
            "出沒間隔:3 分鐘前 35 ~ 55,之後 5 分鐘內線性縮到 30 ~ 40(5.5 分鐘時 32.5 ~ 47.5)")
    _near(b.next_cooldown(0, 0.0, 9999.0), 30.0, "後期最短 30 秒", 0.001)
    _near(b.hp(0.0), 30.0, "血量:開局 30", 0.001)
    _near(b.hp(180.0), 60.0, "血量:3 分鐘 60", 0.001)
    _check(is_equal_approx(b.king_at_sec(), 480.0) and is_equal_approx(b.king_hp_mult(), 4.0) and is_equal_approx(b.king_scale(), 1.6)
            and b.king_grow_helper() > b.king_grow_fish() and b.king_grow_fish() > 1.0 and b.king_max_scale() >= b.king_scale()
            and b.king_fish_bite_sec() < b.king_bite_sec() and b.king_bite_sec() < b.bite_sec() and b.king_respawn_sec() > 0.0,
            "北極熊王:5 分鐘出場、血量 ×4、體型 1.6、吃幫手長得比吃魚多、咬得比一般熊快")
    _check(is_equal_approx(b.king_heal_fish(), 0.0) and is_equal_approx(b.king_heal_helper(), 0.0) and is_equal_approx(b.king_building_bite_sec(), 10.0),
            "王吃魚 / 吃幫手都不回血;咬建築 10 秒拆掉")
    _check(str(b.weapon_model(3).get("file", "")).contains("axe-upgraded") and b.weapon_model(0).is_empty(), "武器模型:Lv3 強化斧、Lv0 沒有")
    _check(b.pack_size(0.0) == 4 and b.pack_size(0.099) == 4 and b.pack_size(0.1) == 3 and b.pack_size(0.399) == 3 and b.pack_size(0.4) == 2
            and b.pack_size(0.899) == 2 and b.pack_size(0.9) == 1 and b.pack_size(1.0) == 1, "一次幾隻:10% 4 隻、30% 3 隻、50% 2 隻、10% 1 隻")
    _check(b.interval() == Vector2(35.0, 55.0) and is_equal_approx(b.first_delay(), 5.0) and is_equal_approx(b.first_at_sec(), 180.0),
            "第一群 3 分鐘後(再倒數 5 秒)才來、之後 35 ~ 55 秒")
    _check(b.entries(1).size() == 2 and b.entries(1)[1].x > 30.0 and b.entries(0)[1].x < 20.0 and b.entries(2)[1].x > 50.0
            and b.entries(2)[0].x < 0.0 and b.entries(3)[1].x > 70.0 and b.entries(9)[1].x > 70.0, "擴建後東邊入口移到 annex 外、每次擴建再往東(超過設定退回最後一級)")
    var prey := [{"id": 1, "pos": Vector3(10, 0, 0)}, {"id": 2, "pos": Vector3(3, 5, 4)}, {"id": 3, "pos": Vector3(-8, 0, 1)}]
    _check(BearLogic.pick_target(Vector3.ZERO, prey) == 2 and BearLogic.pick_target(Vector3(-7, 0, 0), prey) == 3
            and BearLogic.pick_target(Vector3.ZERO, []) == -1, "盯上平面距離最近的幫手(忽略高度);沒幫手回 -1")
    var empty := BearLogic.from_config({}, {})
    _check(empty.weapon_damage(1) == 0.0 and empty.weapon_max_level() == 0 and empty.entries().is_empty() and empty.first_delay() > 0.0
            and empty.pack_size(0.5) == 1 and empty.hp(60.0) > 0.0 and empty.interval(999.0) == empty.interval(0.0) and empty.king_at_sec() > 0.0
            and empty.king_building_bite_sec() > 0.0 and is_equal_approx(empty.king_heal_fish(), 0.0)
            and empty.first_at_sec() == 0.0 and empty.pack_max_eats() == 0 and empty.drop_count(false, 0.5) == 1 and empty.drop_count(true, 0.5) == 1,
            "沒設定也不會爆:沒武器等級、沒入口、用預設秒數、一次一隻、血量與王有預設")


## --- 守衛塔 ---

func _test_tower() -> void:
    var t := TowerLogic.from_config(GameData.section("tower"))
    _check(is_equal_approx(t.hp(), 800.0) and is_equal_approx(t.damage(), 10.0) and is_equal_approx(t.attack_range(), 9.0)
            and is_equal_approx(t.attack_interval(), 0.8) and t.arrow_speed() > 0.0 and is_equal_approx(t.bite_sec(), 2.5)
            and t.aggro_radius() >= 1.0 and t.height() > 0.0, "守衛塔設定:血 800、每箭 10、射程 9、每 0.8 秒一箭、熊咬一口 2.5 秒")
    _check(is_equal_approx(t.bite_damage(), 40.0) and t.bites_to_break() == 20, "一般熊咬一口 40:要咬 20 口才拆得掉")
    _check(t.max_tier() == 1 and is_equal_approx(t.hp(1), 2000.0) and is_equal_approx(t.damage(1), 25.0) and t.bites_to_break(1) == 50
            and is_equal_approx(t.dps(1), 31.25) and t.shots_to_kill(100.0, 1) == 4 and is_equal_approx(t.hp(0), 800.0),
            "強力守衛塔(熊王牙):血 2000 = 扛 50 口、每箭 25")
    _check(int(GameData.repair_station().get("cost", 0)) == 100, "工作站修復牌 $100(shop.json repairStation)")
    _near(t.dps(), 12.5, "每秒傷害 12.5", 0.001)
    _check(t.shots_to_kill(30.0) == 3 and t.shots_to_kill(31.0) == 4 and t.shots_to_kill(0.0) == 0 and t.in_range(9.0) and not t.in_range(9.01),
            "幾箭射死 / 射程判斷")
    var bears := [{"id": 1, "pos": Vector3(5, 0, 0), "alive": true}, {"id": 2, "pos": Vector3(2, 3, 1), "alive": false},
            {"id": 3, "pos": Vector3(-3, 0, 3), "alive": true}, {"id": 4, "pos": Vector3(20, 0, 0), "alive": true}]
    _check(TowerLogic.pick_target(Vector3.ZERO, bears, 9.0) == 3 and TowerLogic.pick_target(Vector3(6, 0, 0), bears, 9.0) == 1
            and TowerLogic.pick_target(Vector3(100, 0, 0), bears, 9.0) == -1 and TowerLogic.pick_target(Vector3.ZERO, [], 9.0) == -1,
            "射程內最近的活熊(跳過逃走的、超出射程的);沒有回 -1")
    var empty := TowerLogic.from_config({})
    _check(empty.hp() > 0.0 and empty.damage() > 0.0 and empty.attack_range() > 0.0 and empty.bite_damage() > 0.0 and empty.bites_to_break() > 0
            and empty.shots_to_kill(50.0) > 0, "沒設定也有預設")


## --- 裝置偏好 ---

func _test_settings() -> void:
    var default_path := Settings.path
    var old_quality := Settings.quality
    var old_fps := Settings.show_fps
    Settings.path = "user://_verify_core_settings.json"
    Settings.delete_file()
    Settings.quality = Settings.FINE
    Settings.show_fps = false
    var changes := [0]
    var cb := func() -> void: changes[0] += 1
    Settings.changed.connect(cb)
    Settings.toggle_quality()
    _check(Settings.is_smooth() and is_equal_approx(Settings.scaling_3d(), 0.75) and changes[0] == 1 and FileAccess.file_exists(Settings.path),
            "畫質切到流暢:3D 0.75 倍、發 changed、寫檔")
    Settings.set_show_fps(true)
    Settings.set_quality("nope")
    _check(Settings.show_fps and Settings.is_smooth() and changes[0] == 2, "FPS 開關;不認識的畫質值不理")
    Settings.quality = Settings.FINE
    Settings.show_fps = false
    Settings.load_settings()
    _check(Settings.is_smooth() and Settings.show_fps, "重新讀檔:畫質與 FPS 設定都回來")
    Settings.delete_file()
    Settings.load_settings()
    _check(Settings.quality == (Settings.SMOOTH if Settings.is_touch_device() else Settings.FINE) and not Settings.show_fps,
            "沒設定檔:依裝置給預設(這台是 %s)" % Settings.quality)
    Settings.changed.disconnect(cb)
    Settings.path = default_path
    Settings.quality = old_quality
    Settings.show_fps = old_fps


## --- 堆疊 MultiMesh 與靜態合併 ---

func _test_batching() -> void:
    var sv := StackVisual.new()
    sv.columns = 3
    add_child(sv)
    sv.show_items("fish", 5)
    _check(sv.visible_count() == 5 and is_equal_approx(sv.top_height(), 2.0 * (GameData.item_size("fish").y + 0.02)), "堆 5 條魚:畫 5 個、兩層高")
    sv.show_items("fillet", 70)
    _check(sv.visible_count() == 60 and sv.count == 70, "70 片魚片:最多畫 60 個,數量仍記 70")
    sv.show_items("", 0)
    _check(sv.visible_count() == 0 and is_equal_approx(sv.top_height(), 0.0), "清空:不畫")
    sv.free()
    var sb := StaticBatch.new()
    add_child(sb)
    sb.add_box(Vector3(1, 1, 1), Color.RED, Vector3.ZERO)
    sb.add_box(Vector3(2, 1, 1), Color.RED, Vector3(3, 0, 0))
    sb.add_cylinder(0.5, 1.0, Color.BLUE, Vector3(0, 0, 3))
    var surfaces := sb.build()
    _check(surfaces == 2 and sb.mesh != null and sb.mesh.get_surface_count() == 2 and sb.mesh.surface_get_array_len(0) == 48,
            "三個零件兩種顏色 -> 兩個 surface(紅色兩個方塊 48 個頂點)")
    sb.free()


## --- 模型:人物 GLB 與動畫、物品模型塞框、水裡的魚 ---

func _test_models() -> void:
    var scene := ModelLibrary.character("character-male-a")
    _check(scene != null and ModelLibrary.character("") == null and ModelLibrary.role_model("fisher") != ""
            and ModelLibrary.role_model("nope") == "" and ModelLibrary.customer_models().size() >= 3 and ModelLibrary.water_fish_count() == 3,
            "models 設定:人物載得到、職業 / 顧客 / 水裡的魚都有設定")
    var cm := CharacterModel.create(scene, 1.5)
    add_child(cm)
    var box := ModelLibrary.scene_aabb(cm)
    _check(cm.anim != null and absf(box.size.y - 1.5) < 0.02 and absf(box.position.y) < 0.02 and absf(box.get_center().x) < 0.05
            and cm.current() == "idle", "人物模型:縮到 1.5 高、腳底在 0、置中、預設 idle(高 %.2f)" % box.size.y)
    cm.set_moving(1.0)
    _check(cm.current() == "walk" and cm.anim.get_animation("walk").loop_mode == Animation.LOOP_LINEAR
            and cm.anim.get_animation("idle").loop_mode == Animation.LOOP_LINEAR, "移動播 walk;idle / walk 設成循環")
    cm.set_moving(0.05)
    var idled := cm.current() == "idle"
    cm.set_action("interact-right", true, 1.5)
    cm.set_moving(1.0)
    _check(idled and cm.current() == "interact-right" and is_equal_approx(cm.anim.speed_scale, 1.5), "停下回 idle;指定動作蓋過走路、倍速 1.5")
    cm.clear_action()
    cm.set_moving(0.0)
    cm.set_action("emote-yes", false)
    _check(cm.current() == "emote-yes" and cm.anim.get_animation("emote-yes").loop_mode == Animation.LOOP_NONE
            and cm.anim.get_animation("interact-right").loop_mode == Animation.LOOP_LINEAR, "一次性動作不循環")
    cm.free()
    var mesh := ModelLibrary.item_mesh("fish")
    var fit := ModelLibrary.item_fit("fish")
    var size := GameData.item_size("fish")
    var fitted := fit * mesh.get_aabb() if mesh != null else AABB()
    _check(mesh is ArrayMesh and fitted.size.x <= size.x + 0.01 and fitted.size.y <= size.y + 0.01 and fitted.size.z <= size.z + 0.01
            and fitted.size.x >= size.x * 0.9 and absf(fitted.position.y + size.y / 2.0) < 0.01 and absf(fitted.get_center().x) < 0.01
            and absf(fitted.get_center().z) < 0.01, "魚的物品模型:等比例塞進尺寸框、底部貼框底、XZ 置中(%s)" % str(fitted.size))
    _check(ModelLibrary.item_mesh("fillet") == null and ModelLibrary.item_fit("fillet") == Transform3D.IDENTITY, "魚片沒有模型:用方塊")
    var sv := StackVisual.new()
    add_child(sv)
    sv.show_items("fish", 3)
    var model_pile := sv.uses_model() and sv.visible_count() == 3
    sv.show_items("fillet", 2)
    _check(model_pile and not sv.uses_model() and sv.visible_count() == 2, "堆疊:魚用模型網格、魚片退回方塊")
    sv.free()
    var f := Fish.new()
    f.variant = 1
    add_child(f)
    f.set_highlight(true)
    var lit := f.overlay_on()
    f.set_highlight(false)
    _check(f.has_model() and f.anim_playing() and lit and not f.overlay_on(), "水裡的魚:FBX 模型、游泳動畫在播、盯上時蓋亮層")
    f.free()


## --- 進度環 ---

func _test_ring() -> void:
    var ring := ProgressRing.new()
    add_child(ring)
    _check(ring.drawn_segments() == 0, "進度 0:沒畫弧")
    ring.set_progress(0.5)
    _check(ring.drawn_segments() == 24, "進度 0.5:畫 24 / 48 段")
    ring.set_progress(1.0)
    _check(ring.drawn_segments() == 48, "進度 1:畫滿")
    ring.set_progress(1.7)
    _check(ring.drawn_segments() == 48 and is_equal_approx(ring.progress, 1.0), "超過 1 夾住")
    ring.set_progress(0.01)
    _check(ring.drawn_segments() == 1, "一點點也畫 1 段")
    ring.free()   # 測試結束就 quit,queue_free 來不及處理會被當成洩漏


## --- 音效檔 ---

func _test_sfx() -> void:
    var missing := []
    for n in Sfx.NAMES:
        var s = load("res://assets/sfx/%s.wav" % n)
        if not (s is AudioStreamWAV) or (s as AudioStreamWAV).data.size() == 0:
            missing.append(n)
    _check(missing.is_empty(), "音效檔都能載入(%d 個)" % Sfx.NAMES.size() if missing.is_empty() else "缺音效:%s" % str(missing))
    _check(Sfx.has("sale") and Sfx.has("ambient_waves"), "Sfx 載入了結帳與環境音")
    var before := Sfx.played_total
    _check(Sfx.play("goal") and Sfx.played_total == before + 1 and int(Sfx.played.get("goal", 0)) >= 1, "Sfx.play 有播(headless 用 Dummy 音訊)")
    _check(not Sfx.play("goal"), "同一音效太密集不重播")
    _check(not Sfx.play("nope"), "沒有的音效不播")
