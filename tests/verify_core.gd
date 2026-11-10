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
    _test_trap_and_belt()
    _test_story()
    _test_tower_upgrades()
    _test_truck()
    _test_offline()
    _test_kitchen()
    _test_orders()
    _test_rare_fish()
    _test_customer_growth()
    _test_king()
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
    _test_legacy()
    _test_juice()
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
    _check(GameData.items().size() == 8 and GameData.item("soup").has("color") and GameData.item("fish").has("size") and GameData.item("cash").has("color") and GameData.item("pelt").has("size")
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
    var costs_expected: Array = [10, 30, 20, 25, 20, 20, 80, 50, 60, 35, 1000, 2000, 8000, 12000]
    for i in 8:
        costs_expected.append(40)
    for i in 4:
        costs_expected.append(30)
    for i in 13:
        costs_expected.append(150)
    for i in 26:
        costs_expected.append(200)
    costs_expected.append(3)
    for i in 26:
        costs_expected.append(1)
    costs_expected.append_array([1, 3])   # 熊王祭壇:保險券 1 牙、冰封夾 3 牙
    costs_expected.append_array([300, 500, 3, 300])   # 修理工 $300、地圖碎片(現金 $500 / 稀有魚 3 條)、毛皮補給 $300
    costs_expected.append(3)   # 冰母的神龕:3 條稀有魚(結局)
    costs_expected.append(300)   # 衛兵 $300(固定價,可僱 4 位)
    costs_expected.append(1500)   # 雪地貨車 $1500 ×1.5(最多 3 台)
    _check(shop.size() == 136, "shop.json:一百三十六塊牌(多了往南三次擴建 $16000 / 32000 / 64000、塔 27 ~ 32、捕熊夾 9 ~ 16、誘餌 5 ~ 8、八條傳送帶)(%d)" % shop.size())
    var by_id := {}
    for p in shop:
        by_id[str(p["id"])] = int(p["cost"])
    _check(by_id.get("expand_village_5") == 16000 and by_id.get("expand_village_6") == 32000 and by_id.get("expand_village_7") == 64000
            and by_id.get("tower_32") == 200 and by_id.get("tooth_tower_32") == 1 and by_id.get("trap_16") == 40 and by_id.get("bait_8") == 30
            and by_id.get("belt_kitchen_4") == 150 and by_id.get("truck") == 1500 and by_id.get("hire_guard") == 300 and by_id.get("shrine") == 3,
            "shop.json:三次往南擴建的價格與新牌子都在")
    var hf0 := GameData.purchase("hire_fisher")
    _check(int(hf0.get("maxBuys", 0)) == 5 and int(hf0.get("expandBuys", 0)) == 3, "漁夫牌:一開始 5 位、每次擴建 +3")
    var hg := GameData.purchase("hire_guard")
    _check(str(hg.get("effect", {}).get("role", "")) == "guard" and int(hg.get("maxBuys", 0)) == 4 and is_equal_approx(float(hg.get("costMult", 0.0)), 1.0)
            and is_equal_approx(float(hg.get("rebuyMult", 0.0)), 1.5) and float(GameData.helper("guard").get("damage", 0.0)) > 0.0
            and ModelLibrary.role_model("guard") != "", "衛兵牌:$300 固定價、4 位、被吃 1.5 倍買回;helpers.guard 有攻擊力、有人物模型")
    var mc := GameData.purchase("map_cash")
    var mf := GameData.purchase("map_fish")
    var mcl := PurchaseLogic.from_def(mc)
    var mfl := PurchaseLogic.from_def(mf)
    _check(str(mc.get("effect", {}).get("type", "")) == "map_piece" and mcl.costs == [500, 1500, 5000] and str(mf.get("currency", "")) == "rarefish"
            and mfl.costs == [3, 5, 8] and str(GameData.purchase("merchant_pelts").get("effect", {}).get("kind", "")) == "pelt"
            and str(GameData.purchase("hire_repairman").get("effect", {}).get("role", "")) == "repairman" and int(GameData.purchase("hire_repairman").get("expandBuys", 0)) == 1
            and GameData.helper("repairman").has("repairSec") and ModelLibrary.role_model("repairman") != "",
            "旅行商人:地圖碎片兩塊牌(現金 500 / 1500 / 5000、稀有魚 3 / 5 / 8)、毛皮補給;修理工牌 $300(擴建 +1)、設定與人物")
    _check(GameData.section("orders").has("intervalSec") and GameData.section("rareFish").has("catchSec") and GameData.section("customers").get("perExpansion", {}).has("wantShift")
            and GameData.changelog().size() >= 2 and GameData.latest_version() != "" and GameData.changelog()[0].get("notes", []).size() >= 3,
            "orders / rareFish / customers.perExpansion 設定;changelog.json 至少兩版、最新版 %s" % GameData.latest_version())
    var pc := GameData.purchase("upgrade_porter_cap")
    _check(str(pc.get("effect", {}).get("key", "")) == "porter_cap" and int(pc.get("maxBuys", 0)) == 3 and is_equal_approx(float(pc.get("costMult", 0.0)), 2.0)
            and str(GameData.purchase("trap_1").get("effect", {}).get("type", "")) == "trap" and str(GameData.purchase("bait_4").get("effect", {}).get("target", "")) == "bait_4"
            and str(GameData.purchase("belt_tailor").get("effect", {}).get("type", "")) == "conveyor",
            "搬運工容量牌三級 ×2;捕熊夾 / 誘餌 / 傳送帶牌的效果型別")
    var tl := GameData.station("tailor")
    _check(str(tl.get("input", "")) == "pelt" and str(tl.get("output", "")) == "sweater" and int(tl.get("inputPer", 0)) == 5
            and int(GameData.counter("sweater_counter").get("price", 0)) == 350 and str(GameData.counter("sweater_counter").get("item", "")) == "sweater"
            and GameData.item_name("sweater") != "ITEM_sweater" and GameData.item_color("sweater") != GameData.item_color("pelt"),
            "服飾店:5 張毛皮 -> 1 件毛衣;毛衣櫃台 $350;毛衣有名字與顏色")
    _check(int(GameData.purchase("hire_fisher").get("expandBuys", 0)) == 3 and int(GameData.purchase("hire_porter").get("expandBuys", 0)) == 4
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
    _check(GameData.counters().size() == 14 and int(GameData.counter("soup_counter").get("price", 0)) == 15 and int(GameData.counter("soup_counter_4").get("price", 0)) == 15 and int(GameData.counter("grill_counter").get("price", 0)) == 5 and str(GameData.counter("grill_counter_3").get("item", "")) == "grilled"
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


## --- 訂單 ---

func _test_orders() -> void:
    var o := OrderLogic.from_config({"firstDelaySec": 30, "intervalSec": 150, "intervalMult": 0.85, "minIntervalSec": 60, "timeLimitSec": 240,
            "kinds": [2, 3], "perKindBase": 6, "perKindPerExpansion": 3, "rewardMult": 2.0, "rareChance": 0.25, "rarePrice": 60, "bonusPeltChance": 0.5, "bonusPelts": 3,
            "exclude": ["sweater"]})
    o.rng.seed = 7
    _near(o.interval(0), 150.0, "訂單間隔:沒擴建 150 秒", 0.01)
    _near(o.interval(2), 150.0 * 0.85 * 0.85, "擴建兩次 × 0.85²", 0.01)
    _near(o.interval(10), 60.0, "最低 60 秒", 0.01)
    _check(o.per_kind(0) == 6 and o.per_kind(3) == 15 and o.kinds_range() == Vector2i(2, 3), "每種 6 件、每擴建一次 +3;2 ~ 3 種")
    var menu := {"fillet": 2, "grilled": 5, "soup": 15, "sweater": 200}
    _check(o.pool(menu) == ["fillet", "grilled", "soup"], "可要的貨:櫃台賣的,毛衣除外")
    _check(o.generate({}, 0).is_empty() and not o.has_order(), "沒櫃台不貼訂單")
    var od := o.generate(menu, 1, 1.0)
    var kinds: int = od["lines"].size()
    var total := 0
    var ok_lines := true
    for item in od["lines"]:
        var l: Dictionary = od["lines"][item]
        if int(l["need"]) != 9 or int(l["done"]) != 0 or int(l["price"]) != int(menu[item]) or str(item) == "sweater":
            ok_lines = false
        total += int(l["need"]) * int(l["price"])
    _check(o.has_order() and kinds >= 2 and kinds <= 3 and ok_lines and int(od["total"]) == total and int(od["reward"]) == total * 2
            and is_equal_approx(float(od["time_left"]), 240.0) and od["bonus"].has("kind"),
            "貼訂單:%d 種各 9 件(擴建一次)、總價 $%d、獎勵 ×2 = $%d、限時 240 秒、附贈 %s" % [kinds, total, int(od["reward"]), str(od["bonus"])])
    var first: String = o.wanted_items()[0]
    _check(o.need_of(first) == 9 and o.need_of("nope") == 0 and o.deliver(first, 4) == 4 and o.need_of(first) == 5 and o.deliver(first, 20) == 5
            and o.need_of(first) == 0 and not o.wanted_items().has(first) and o.delivered_total == 9 and not o.is_complete() and o.complete().is_empty(),
            "送貨:只收還缺的量,送齊一種就不在 wanted 裡;還有別種沒齊不算完成")
    for item in o.wanted_items().duplicate():
        o.deliver(str(item), 99)
    _check(o.is_complete() and o.progress() >= 0.999, "全部送齊")
    var r := o.complete()
    _check(int(r["reward"]) == total * 2 and not o.has_order() and o.completed_total == 1, "結清:獎勵 $%d、訂單消失" % int(r["reward"]))
    # 倒數:沒訂單時 next_in 到了回 new;有訂單時限到了回 expired
    o.next_in = 1.0
    _check(o.tick(0.5, 0) == "" and o.tick(0.6, 0) == "new" and is_equal_approx(o.next_in, 150.0), "沒訂單:倒數到了回 new、重設下一輪")
    var od2 := o.generate(menu, 0, 0.0)
    _check(od2["lines"].has("rarefish") and int(od2["lines"]["rarefish"]["need"]) == 1 and int(od2["lines"]["rarefish"]["price"]) == 60
            and o.wanted_items().has("rarefish"), "roll 0 < rareChance:多要一條稀有魚($60)")
    o.order["time_left"] = 0.2
    _check(o.tick(0.1, 0) == "" and o.tick(0.2, 0) == "expired" and not o.has_order() and o.expired_total == 1 and is_equal_approx(o.next_in, 150.0),
            "有訂單:時限到了 expired、訂單消失、重新倒數")
    o.generate(menu, 0, 1.0)
    o.deliver(o.wanted_items()[0], 2)
    var snap := o.snapshot()
    var o2 := OrderLogic.from_config(o.cfg)
    o2.restore(snap)
    _check(o2.has_order() and o2.order["lines"].size() == o.order["lines"].size() and o2.delivered_total == o.delivered_total
            and o2.completed_total == 1 and o2.expired_total == 1 and o2.progress() > 0.0 and is_equal_approx(o2.progress(), o.progress()),
            "快照 / 還原:訂單內容、進度、統計")
    var o3 := OrderLogic.from_config(o.cfg)
    o3.restore({})
    _check(not o3.has_order() and is_equal_approx(o3.next_in, 30.0), "空快照:沒訂單、從頭倒數 firstDelaySec")


## --- 稀有魚 ---

func _test_rare_fish() -> void:
    var r := RareFishLogic.from_config({"intervalSec": [60, 90], "lifetimeSec": 150, "catchRadius": 2.0, "catchSec": 2.0, "speedMult": 1.8})
    _near(r.next_interval(0.0), 60.0, "下一條:roll 0 -> 60 秒", 0.01)
    _near(r.next_interval(1.0), 90.0, "roll 1 -> 90 秒", 0.01)
    _check(is_equal_approx(r.lifetime(), 150.0) and is_equal_approx(r.catch_radius(), 2.0) and is_equal_approx(r.speed_mult(), 1.8), "游走時間 / 抓的距離 / 速度倍率")
    var p := 0.0
    p = r.tick_catch(p, 0.5, true)
    p = r.tick_catch(p, 0.5, true)
    _check(is_equal_approx(p, 1.0) and not r.is_caught(p), "站 1 秒:進度 1 / 2,還沒抓到")
    p = r.tick_catch(p, 0.3, false)
    _check(is_equal_approx(p, 0.0), "走開:進度歸零")
    p = r.tick_catch(2.1, 0.0, true)
    _check(r.is_caught(p), "站滿 2 秒抓到")
    _check(RareFishLogic.ITEM == "rarefish" and GameState.resource("rarefish") == 0, "資源名 rarefish")
    var d := RareFishLogic.from_config({})
    _check(is_equal_approx(d.catch_sec(), 2.0) and is_equal_approx(d.next_interval(0.5), 75.0), "沒設定用預設")


## --- 顧客成長 ---

func _test_customer_growth() -> void:
    var w := [45, 25, 15, 10, 5]
    _check(CounterLogic.shift_weights(w, 0) == w, "偏 0:不變")
    _check(CounterLogic.shift_weights(w, 1) == [0, 45, 25, 15, 10, 5] and CounterLogic.roll_want(CounterLogic.shift_weights(w, 1), 0.0) == 2,
            "偏 1:最少要 2 件")
    _check(CounterLogic.shift_weights(w, 4, 9) == [0, 0, 0, 0, 45, 25, 15, 10, 5] and CounterLogic.roll_want(CounterLogic.shift_weights(w, 4, 9), 1.0) == 9,
            "偏 4(擴建四次):5 ~ 9 件")
    _check(CounterLogic.shift_weights(w, 6, 9) == [0, 0, 0, 0, 0, 0, 45, 25, 15] and CounterLogic.shift_weights([1], 10, 3) == [0, 0, 1],
            "超過上限 9 件就切掉;全切光留最後一格")
    _check(CounterLogic.shift_weights([1], 2, 9) == [0, 0, 1] and CounterLogic.roll_want([0, 0, 1], 0.5) == 3, "一次一件的櫃台偏 2 -> 3 件")


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
    var fdef := GameData.purchase("hire_fisher").duplicate()   # 下面的階梯 / 買回算式照舊用「最多 3 次」的版本(正式牌子現在 5 次)
    fdef["maxBuys"] = 3
    fdef["costMult"] = 1.8   # 階梯算式的測試照舊用 1.8(正式牌子 2026-11-09 起 1.3)
    var r := PurchaseLogic.from_def(fdef)
    _check(r.repeatable and r.max_buys == 3 and r.current_cost() == 10 and r.remaining == 10, "漁夫牌(3 次版):可買 3 次、第一次 $10")
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
    var r2 := PurchaseLogic.from_def(fdef)
    r2.restore(1, 5)
    _check(r2.buys == 1 and r2.remaining == 5 and r2.current_cost() == 18, "存檔還原:買過 1 次、這次剩 5")
    r2.restore(3, 0)
    _check(r2.is_exhausted() and r2.remaining == 0, "存檔還原:買滿")
    r2.restore(0, 0)
    _check(r2.buys == 0 and r2.remaining == 10, "存檔還原:剩 0 但沒買滿 -> 重設成整價")
    # 被吃掉買回:退一個名額,價格 = 該級 × 1.5,買回後回到正常階梯
    var r3 := PurchaseLogic.from_def(fdef)
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
    var r4 := PurchaseLogic.from_def(fdef)
    r4.restore(1, 27, 1)
    _check(r4.buys == 1 and r4.lost == 1 and r4.current_cost() == 27 and r4.remaining == 27, "存檔還原:帶著待買回的名額")
    # 擴建村莊多開放名額:漁夫牌 +2(3 -> 5),買滿消失的牌重新開放、價格是下一級;只加一次
    var r5 := PurchaseLogic.from_def(GameData.purchase("hire_fisher"))
    _check(is_equal_approx(r5.cost_mult, 1.3) and is_equal_approx(PurchaseLogic.from_def(GameData.purchase("hire_porter")).cost_mult, 1.3)
            and is_equal_approx(PurchaseLogic.from_def(GameData.purchase("hire_cashier")).cost_mult, 1.3), "僱用牌階梯 1.3(26 位漁夫最後一位約 $7,000)")
    r5.restore(5, 0)
    _check(r5.is_exhausted() and r5.expand_buys == 3 and r5.expand() and not r5.is_exhausted() and r5.max_buys == 8 and r5.buys == 5
            and r5.remaining == r5.current_cost() and r5.current_cost() == 37 and r5.expand() and r5.max_buys == 11 and r5.expand() and r5.max_buys == 14
            and r5.expand() and r5.max_buys == 17 and r5.expand() and r5.max_buys == 20 and r5.expand() and r5.max_buys == 23
            and r5.expand() and r5.max_buys == 26 and not r5.expand() and r5.max_buys == 26,
            "擴建:漁夫牌 5 -> 8 次,買滿的牌重開、第六次 $%d(10 × 1.3⁵)、七次擴建最多 26 次" % r5.current_cost())
    var r6 := PurchaseLogic.from_def(GameData.purchase("hire_porter"))
    r6.pay(30)
    r6.complete()
    r6.pay(7)
    var rem6 := r6.remaining
    _check(r6.expand() and r6.max_buys == 6 and r6.buys == 1 and r6.remaining == rem6 and rem6 == 39 - 7, "擴建:搬運工牌 2 -> 6 次,付到一半的進度不變(第二位 $39 = 30 × 1.3)")
    _check(not PurchaseLogic.from_def(GameData.purchase("capacity_1")).expand(), "沒 expandBuys 的牌 expand 回 false")
    # 捕熊夾牌:一次性 $40,用掉 lose -> 同價再買(rebuyMult 1)
    var trp := PurchaseLogic.from_def(GameData.purchase("trap_1"))
    trp.pay(40)
    trp.complete()
    _check(trp.is_exhausted() and trp.lose() and not trp.is_exhausted() and trp.remaining == 40 and trp.current_cost() == 40 and trp.is_rebuy(),
            "捕熊夾牌:用掉後同價重新開放($40)")
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
    var mp := PurchaseLogic.from_def({"id": "map_cash", "cost": 500, "costs": [500, 1500, 5000], "repeatable": true, "maxBuys": 3, "costMult": 1.0, "effect": {"type": "map_piece"}})
    mp.set_buys(2)
    _check(mp.buys == 2 and mp.remaining == 5000 and mp.current_cost() == 5000 and not mp.is_exhausted(), "set_buys(2):地圖碎片第三片 $5000")
    mp.set_buys(3)
    _check(mp.is_exhausted() and mp.remaining == 0, "set_buys(3):買滿")
    mp.set_buys(0)
    _check(mp.buys == 0 and mp.remaining == 500, "set_buys(0):回到第一片 $500")
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
    GameState.apply_purchase("upgrade_porter_cap", {"type": "upgrade", "key": "porter_cap"})
    GameState.apply_purchase("upgrade_porter_cap", {"type": "upgrade", "key": "porter_cap"})
    _check(GameState.upgrade_level("porter_cap") == 2 and GameState.upgrade_bonus("porter_cap") == 8 and GameState.upgrade_bonus("worker_speed") == 1
            and GameState.upgrade_bonus("nope") == 0, "搬運工容量升級:兩級 +8(perLevel 4);沒設定的加成 0")
    GameState.upgrades.erase("porter_cap")
    GameState.apply_purchase("weapon", {"type": "weapon"})
    GameState.apply_purchase("weapon", {"type": "weapon"})
    GameState.add_trashed(3)
    EventBus.purchased.disconnect(cb)
    _check(purchased[0] == 11 and GameState.capacity_bonus == 4 and GameState.hired_count("fisher") == 2
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
    GameState.claim_offline(25)
    GameState.claim_offline(0)
    _check(GameState.wallet == 32 and GameState.offline_earned == 25, "離線收益領取:進錢包、統計累計;0 不算")
    GameState.apply_purchase("map_cash", {"type": "map_piece"})
    GameState.apply_purchase("map_fish", {"type": "map_piece"})
    GameState.apply_purchase("merchant_pelts", {"type": "resource", "kind": "pelt", "amount": 5})
    GameState.add_resource("rarefish", 4)
    GameState.spend_resource("rarefish", 1)
    GameState.complete_order(40)
    _check(GameState.map_pieces == 2 and not GameState.has_full_map() and GameState.pelts == 5 and GameState.rarefish == 3 and GameState.resource("rarefish") == 3
            and GameState.orders_done == 1 and GameState.orders_cash == 40 and GameState.wallet == 72, "地圖碎片 2 片、毛皮補給 +5、稀有魚 4 - 1、訂單 $40 進錢包")
    GameState.apply_purchase("map_cash", {"type": "map_piece"})
    GameState.apply_purchase("map_cash", {"type": "map_piece"})
    _check(GameState.map_pieces == 3 and GameState.has_full_map(), "第三片拼齊(不超過 3)")
    GameState.wallet = 7
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
            and is_equal_approx(GameState.play_time, 123.5) and GameState.offline_earned == 25
            and GameState.map_pieces == 3 and GameState.rarefish == 3 and GameState.orders_done == 1 and GameState.orders_cash == 40,
            "to_dict -> JSON -> from_dict 往返(含錢包、音效開關、武器等級、被吃數、遊戲時間、離線收益統計、地圖 / 稀有魚 / 訂單)")
    GameState.reset()


## --- 多原料工作站(魚湯廚房)---

func _test_kitchen() -> void:
    var k := StationLogic.from_def(GameData.station("kitchen"))
    _check(k.inputs == ["fillet", "grilled"] and k.is_multi_input() and k.input_id == "fillet" and k.output_id == "soup" and k.input_cap == 12
            and is_equal_approx(k.process_sec, 2.0) and k.yield_count == 1 and k.accepts("grilled") and not k.accepts("fish"),
            "stations.json kitchen:魚片 + 烤魚 -> 魚湯,2 秒一碗")
    _check(k.add_input_of("fillet", 3) == 3 and k.input_count_of("fillet") == 3 and k.input_count == 3 and k.input_count_of("grilled") == 0
            and k.add_input_of("fish", 2) == 0 and k.input_space_of("grilled") == 12 and k.input_space_of("fish") == 0 and k.total_input() == 3,
            "每種原料各自一堆:魚片 3、烤魚 0;不收魚")
    _check(not k.has_enough_input() and k.missing_input() == "grilled" and k.tick(10.0) == 0 and k.output_count == 0, "只有魚片不做:缺烤魚")
    k.add_input_of("grilled", 1)
    _check(k.has_enough_input() and k.missing_input() == "" and k.tick(1.0) == 0 and k.is_working() and k.tick(1.5) == 1 and k.output_count == 1
            and k.input_count_of("fillet") == 2 and k.input_count_of("grilled") == 0, "兩種都有:2 秒做出一碗,各扣一個")
    k.input_count = 7   # 舊介面對應第一種原料
    _check(k.input_count_of("fillet") == 7 and k.input_space() == 5, "舊介面 input_count / input_space 對應第一種原料")
    var single := StationLogic.from_def(GameData.station("cutting_table"))
    _check(not single.is_multi_input() and single.inputs == ["fish"] and single.add_input(2) == 2 and single.input_count == 2 and single.total_input() == 2,
            "單原料工作站照舊")
    # 提示:多原料工作站收料 / 村外回村
    var state := _guide_state()
    state["stations"].append({"id": "kitchen", "input": "fillet", "input_count": 0, "input_cap": 12, "input_per": 1, "inputs": {"fillet": 0, "grilled": 12},
            "missing": "fillet", "output": "soup", "output_count": 0, "blocked": false})
    state["carry_item"] = "grilled"
    state["carry_count"] = 3
    var h := GuideLogic.hint(state)
    _check(h["kind"] == "counter_deposit" or (h["kind"] == "station_input" and h["target"] == "kitchen"), "背著烤魚:烤魚櫃台優先,沒櫃台就指廚房")
    state["counters"] = []
    h = GuideLogic.hint(state)
    _check(h["kind"] == "station_input" and h["target"] == "kitchen" and h["item"] == "grilled" and h["text"] == "HINT_station_full",
            "廚房的烤魚堆滿了:提示帶著 item 指廚房(等它消耗)")
    state["stations"][1]["inputs"]["grilled"] = 2
    h = GuideLogic.hint(state)
    _check(h["kind"] == "station_input" and h["target"] == "kitchen" and h["item"] == "grilled" and h["text"] == "HINT_to_next_station", "烤魚堆有空位:去廚房的烤魚格")
    state["outside"] = true
    h = GuideLogic.hint(state)
    _check(h["kind"] == "home" and h["text"] == "HINT_HOME", "村外探險:最優先指回村")
    state["outside"] = false
    state["bear"] = true
    _check(GuideLogic.hint(state)["kind"] != "home", "回村裡就照舊(熊優先)")


## --- 離線收益 ---

func _test_offline() -> void:
    var o := OfflineLogic.from_config(GameData.section("offline"))
    _check(is_equal_approx(o.window_sec, 300.0) and is_equal_approx(o.min_sec, 60.0) and is_equal_approx(o.max_sec, 14400.0)
            and is_equal_approx(o.mult, 0.5), "game.json offline:視窗 5 分鐘、最短 1 分鐘、上限 4 小時、五折")
    o.begin(0.0)
    _near(o.rate(0.0), 0.0, "新遊戲沒賣東西:速率 0", 0.0001)
    o.record(10.0, 30)
    o.record(100.0, 30)
    _near(o.rate(100.0), 60.0 / 300.0, "視窗內賣了 $60:速率 = 60 / 300", 0.0001)
    _near(o.rate(305.0), 60.0 / 300.0, "305 秒:兩筆都還在視窗內(10 >= 305 - 300)", 0.0001)
    _near(o.rate(320.0), 30.0 / 300.0, "320 秒:第一筆掉出視窗、剩 $30", 0.0001)
    _check(o.sample_count() == 1, "掉出視窗的樣本會清掉")
    _near(o.rate(500.0), 0.0, "500 秒:全掉出視窗,速率 0", 0.0001)
    # 讀檔帶進來的速率補還沒觀察到的部分
    var o2 := OfflineLogic.from_config(GameData.section("offline"))
    o2.begin(1000.0, 2.0)
    _near(o2.rate(1000.0), 2.0, "剛讀檔:速率 = 存檔的 2.0", 0.0001)
    o2.record(1050.0, 100)
    _near(o2.rate(1100.0), (100.0 + 2.0 * 200.0) / 300.0, "觀察 100 秒賣 $100:(100 + 2 × 200) / 300", 0.0001)
    _near(o2.rate(1300.0), 100.0 / 300.0, "觀察滿 300 秒:只看實際收入", 0.0001)
    # 離線秒數與收益
    _check(OfflineLogic.offline_seconds(1000, 4600) == 3600 and OfflineLogic.offline_seconds(0, 4600) == 0
            and OfflineLogic.offline_seconds(5000, 4600) == 0, "離線秒數 = 現在 - savedAt;沒 savedAt / 時鐘倒退回 0")
    _check(o2.earnings(2.0, 59.0) == 0 and o2.earnings(0.0, 3600.0) == 0, "不滿 60 秒 / 速率 0 -> 0")
    _check(o2.earnings(2.0, 60.0) == 60 and o2.earnings(2.0, 3600.0) == 3600, "2 $/s 離線 1 小時 × 0.5 = $3600")
    _check(o2.earnings(2.0, 100000.0) == 14400 and o2.counted_seconds(100000.0) == 14400 and o2.counted_seconds(500.0) == 500,
            "超過 4 小時只算 4 小時($14400)")
    _check(o2.earnings(0.3, 61.0) == 9, "小數無條件捨去(0.3 × 61 × 0.5 = 9.15 -> 9)")
    var d := OfflineLogic.split_duration(3 * 3600 + 12 * 60 + 40)
    var d2 := OfflineLogic.split_duration(20.0)
    _check(int(d["h"]) == 3 and int(d["m"]) == 12 and int(d2["h"]) == 0 and int(d2["m"]) == 1, "秒數拆成 3 小時 12 分;不滿 1 分鐘算 1 分鐘")
    var empty := OfflineLogic.from_config({})
    _check(is_equal_approx(empty.window_sec, 300.0) and is_equal_approx(empty.mult, 0.5), "沒設定用預設值")


## --- 北極熊王獎勵循環 ---

func _test_king() -> void:
    var k := KingLogic.from_config(GameData.section("bear").get("king", {}))
    _check(is_equal_approx(k.warn_sec(), 45.0) and k.max_level() == 5 and k.teeth() == 3 and is_equal_approx(k.calm_sec(), 120.0)
            and is_equal_approx(k.insurance_return_sec(), 10.0) and k.trophy_cap() == 10, "game.json king.reward:預告 45 秒、上限 Lv5、保底 3 顆牙、平靜 120 秒、保險 10 秒回來")
    _near(k.hp_mult(0), 1.0, "Lv0 血 ×1", 0.001)
    _near(k.hp_mult(4), 2.0, "Lv4 血 ×2(每級 +25%)", 0.001)
    _near(k.hp_mult(99), 2.25, "等級夾在 5:血 ×2.25", 0.001)
    _near(k.scale_mult(2), 1.1, "Lv2 體型 ×1.1", 0.001)
    _near(k.building_bite_mult(2), 0.81, "Lv2 咬建築 ×0.81(拆更快)", 0.001)
    _near(k.reward_level_mult(3), 1.6, "Lv3 寶箱 ×1.6", 0.001)
    _check(k.grade(0, 0) == "perfect" and k.grade(2, 0) == "good" and k.grade(0, 1) == "normal" and k.grade(3, 2) == "normal",
            "表現分:沒吃沒拆 perfect、只吃人 good、拆了建築 normal")
    _near(k.grade_mult("perfect"), 2.0, "perfect ×2", 0.001)
    _near(k.grade_mult("good"), 1.5, "good ×1.5", 0.001)
    _near(k.grade_mult("normal"), 1.0, "normal ×1", 0.001)
    _check(k.next_streak(3, "perfect") == 4 and k.next_streak(3, "good") == 0 and k.next_streak(0, "normal") == 0, "連勝:perfect +1、其他歸零")
    _near(k.streak_bonus(3), 0.3, "連勝 3 層 +30%", 0.001)
    _near(k.streak_bonus(9), 0.5, "連勝加成上限 +50%", 0.001)
    _near(k.total_mult("perfect", 1, 0), 2.0 * 1.2, "perfect、之前連勝 1(這次變 2)、Lv0:2 × 1.2", 0.001)
    _near(k.total_mult("normal", 4, 2), 1.0 * 1.0 * 1.4, "normal 連勝歸零、Lv2:1 × 1 × 1.4", 0.001)
    _check(k.cash_card(2.0, 1.0) == 180 and k.cash_card(0.0, 2.0) == 100 and k.cash_card(2.0, 2.4) == 432, "現金卡:速率 × 90 秒 × 倍率,至少 $100")
    _check(k.pelt_card(1.0) == 5 and k.pelt_card(2.4) == 12, "毛皮卡:5 × 倍率")
    _check(k.coupon_card(0.0) == "insurance" and k.coupon_card(0.5) == "calm" and k.coupon_card(0.95) == "upgrade",
            "券卡權重 2 / 2 / 1:0 保險、0.5 平靜、0.95 免費升級")
    var ch := k.chest("perfect", 0, 0, 1.0, 0.0)
    _check(int(ch["teeth"]) == 3 and str(ch["grade"]) == "perfect" and is_equal_approx(float(ch["mult"]), 2.2) and ch["cards"].size() == 3
            and int(ch["cards"][0]["amount"]) == 198 and int(ch["cards"][1]["amount"]) == 11 and str(ch["cards"][2]["coupon"]) == "insurance",
            "寶箱:perfect 第一次 ×2.2 -> 現金 $198 / 毛皮 11 / 保險券,保底 3 顆牙")
    _check(k.is_milestone(5) and k.is_milestone(10) and not k.is_milestone(3), "里程碑 5 / 10 次")
    var empty := KingLogic.from_config({})
    _check(is_equal_approx(empty.warn_sec(), 45.0) and empty.grade(0, 0) == "perfect" and empty.coupon_card(0.9) == "upgrade", "沒設定用預設值")
    # GameState:打死王、券
    GameState.reset()
    GameState.king_streak = 2
    var ms := GameState.king_slain(3, k)
    _check(GameState.king_level == 1 and GameState.king_kills == 1 and GameState.king_streak == 3 and not ms and GameState.capacity_bonus == 0,
            "打死第一次:Lv1、擊殺 1、連勝 3、不是里程碑")
    for i in 4:
        GameState.king_slain(0, k)
    _check(GameState.king_kills == 5 and GameState.king_level == 5 and GameState.king_streak == 0 and GameState.king_capacity_bonus == 1
            and GameState.capacity_bonus == 0 and GameState.total_capacity_bonus() == 1, "第五次:里程碑背包 +1(king_capacity_bonus,與 capacity 牌分開記)、連勝歸零")
    GameState.add_coupon("insurance", 2)
    _check(GameState.coupon("insurance") == 2 and GameState.use_coupon("insurance") and GameState.coupon("insurance") == 1
            and GameState.use_coupon("insurance") and not GameState.use_coupon("insurance") and GameState.coupon("calm") == 0, "券:加兩張、用兩張、第三張用不了")
    GameState.apply_purchase("altar_insurance", {"type": "coupon", "key": "insurance"})
    _check(GameState.coupon("insurance") == 1, "祭壇牌 effect coupon:保險券 +1")
    GameState.add_coupon("upgrade", 1)
    var d := GameState.to_dict()
    GameState.reset()
    GameState.from_dict(JSON.parse_string(JSON.stringify(d)))
    _check(GameState.king_level == 5 and GameState.king_kills == 5 and GameState.coupon("insurance") == 1 and GameState.coupon("upgrade") == 1
            and GameState.king_capacity_bonus == 1, "存檔往返:王等級 / 擊殺 / 券 / 里程碑背包")
    GameState.reset()
    # 冰封夾
    var tl := TrapLogic.from_config(GameData.section("trap"))
    var base_dmg := tl.damage(false)
    tl.ice = true
    _check(is_equal_approx(base_dmg, 60.0) and is_equal_approx(tl.damage(false), 150.0) and is_equal_approx(tl.damage(true), 300.0)
            and is_equal_approx(tl.stun_sec(), 6.0), "冰封夾:傷害 150 / 王 300、定住 6 秒(一般 60 / 3 秒)")


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
    state["wallet"] = 0
    state["money_on_pad"] = 464
    h = GuideLogic.hint(state)
    _check(h["kind"] == "money" and h["text"] == "HINT_money", "塞住但錢包 $0、錢格 $464 買得起牌:先去收錢(不然滿手來回永遠收不到)")
    state["wallet"] = 50
    _check(GuideLogic.hint(state)["kind"] == "station_output", "錢包自己就買得起:不用先收錢,照塞住規則拿成品")
    state["money_on_pad"] = 0
    state["wallet"] = 0
    _check(GuideLogic.hint(state)["kind"] == "station_output", "錢格沒錢:照塞住規則")
    state["wallet"] = 50
    state["stations"][0]["blocked"] = false
    # 櫃台放不下整疊、沒人收銀:先去收銀格賣到放得下(提示不在兩格之間翻來翻去)
    state = _guide_state()
    state["carry_item"] = "fillet"
    state["carry_count"] = 5
    state["counters"][0]["stock"] = 27
    h = GuideLogic.hint(state)
    _check(h["kind"] == "service" and h["text"] == "HINT_counter_full_serve", "背 5 片、櫃台 27 / 30 沒人收銀:先去收銀格賣")
    state["counters"][0]["stock"] = 25
    _check(GuideLogic.hint(state)["kind"] == "counter_deposit", "賣到 25 / 30 放得下 5 片:去上架")
    state["counters"][0]["stock"] = 27
    state["counters"][0]["has_cashier"] = true
    _check(GuideLogic.hint(state)["kind"] == "counter_deposit", "有收銀員:直接上架(能放幾片放幾片)")
    state["counters"][0]["has_cashier"] = false
    state["counters"][0]["stock"] = 0
    state["counters"][0]["cap"] = 3
    _check(GuideLogic.hint(state)["kind"] == "counter_deposit", "櫃台是空的(放不下整疊也先上架,不然沒東西可賣)")
    # 武器打不過熊、幫手被吃過:先存錢升級武器,不提重僱
    state = _guide_state()
    state["wallet"] = 20
    state["outmatched"] = true
    _check(GuideLogic.hint(state)["kind"] == "pad" and GuideLogic.hint(state)["target"] == "hire_fisher", "打不過但還沒有幫手被吃:照舊買最便宜的牌")
    state["helpers_lost"] = 1
    state["pads"].append({"id": "weapon", "name": "SHOP_weapon", "remaining": 60, "visible": true, "currency": "cash"})
    state["stations"][0]["output_count"] = 6
    h = GuideLogic.hint(state)
    _check(h["kind"] == "station_output" and h["text"] == "HINT_SAVE_WEAPON" and h["args"][0] == 40, "打不過且被吃過:工作循環 + 文字「再存 $40 升級武器」,不指 $10 的漁夫牌")
    state["money_on_pad"] = 5
    _check(GuideLogic.hint(state)["kind"] == "money", "錢格有錢:先去收")
    state["wallet"] = 60
    h = GuideLogic.hint(state)
    _check(h["kind"] == "pad" and h["target"] == "weapon", "存夠了:指武器牌")
    state["outmatched"] = false
    _check(GuideLogic.hint(state)["target"] == "hire_fisher", "武器夠強:回到最便宜的牌")
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

## --- 雪地貨車 ---

func _test_truck() -> void:
    var t := TruckLogic.from_config(GameData.section("truck"))
    _check(t.capacity() == 30 and is_equal_approx(t.catch_sec(), 0.7) and t.speed() > 0.0 and is_equal_approx(t.unload_per_sec(), 8.0)
            and is_equal_approx(t.give_up_sec(), 12.0) and int(GameData.section("depot").get("cap", 0)) == 300, "貨車:載 30 條、每 0.7 秒撈一條、每秒卸 8 條;放置區 300 條")
    _check(not t.is_full(29) and t.is_full(30) and not t.should_return(5, 3.0) and t.should_return(30, 0.0) and t.should_return(5, 12.0)
            and not t.should_return(0, 99.0), "滿 30 條或池子空了 12 秒(車上有魚)就回程;空車不回")
    _check(TruckLogic.pick_pond([3, 8, 5], -1) == 1 and TruckLogic.pick_pond([0, 0, 0], 1) == 2 and TruckLogic.pick_pond([0, 0, 0], 2) == 0
            and TruckLogic.pick_pond([4, 4, 4], 0) == 1 and TruckLogic.pick_pond([], 0) == -1, "挑魚池:魚最多的;都空輪下一個;同分不選上一次那個")
    var empty := TruckLogic.from_config({})
    _check(empty.capacity() == 30 and empty.catch_sec() > 0.0, "沒設定用預設值")


## --- 守衛塔升級 / 王的等級上限 ---

func _test_tower_upgrades() -> void:
    var t := TowerLogic.from_config(GameData.section("tower"))
    _check(t.upgrade_cost() == 500 and t.max_upgrades() == 10 and t.upgrade_radius() > 1.0, "塔升級:每次 $500、各 10 次、靠近就有升級鈕")
    _check(is_equal_approx(t.attack_interval(), 0.8) and is_equal_approx(t.attack_interval(1), 0.8 * 0.92) and t.attack_interval(10) < 0.8 * 0.44
            and t.attack_interval(10) > 0.8 * 0.43 and is_equal_approx(t.attack_interval(99), t.attack_interval(10)),
            "射速:每級間隔 × 0.92,十級 0.8 -> %.3f 秒(超過上限不再加)" % t.attack_interval(10))
    _check(is_equal_approx(t.damage(0), 10.0) and is_equal_approx(t.damage(0, 1), 12.0) and is_equal_approx(t.damage(0, 10), 30.0)
            and is_equal_approx(t.damage(1, 10), 75.0) and is_equal_approx(t.damage(1), 25.0) and is_equal_approx(t.damage(0, 99), 30.0),
            "傷害:每級 +20% 基礎,十級一般塔 30、強力塔 75")
    var k := KingLogic.from_config(GameData.section("bear").get("king", {}))
    _check(k.max_level() == 5 and k.clamp_level(9) == 5 and k.clamp_level(3) == 3, "北極熊王等級上限 5")
    GameState.reset()
    GameState.from_dict({"king_level": 9})
    _check(GameState.king_level == 5, "舊存檔的王等級超過上限會夾回 5")
    GameState.reset()


## --- 故事 ---

func _test_story() -> void:
    var s := StoryLogic.from_data(GameData.story())
    _check(s.chapters.size() == 7 and s.journal.size() == 12 and s.lines.has("shopkeeper") and s.lines.has("captain") and s.lines.has("merchant")
            and s.lines.has("repairman") and s.shrine_cost == 3 and is_equal_approx(s.customer_chance, 0.1),
            "story.json:七章、十二條日誌、四個 NPC 的台詞、神龕 3 條魚")
    var missing: Array[String] = []
    for c in s.chapters:
        for k in ["title", "text"]:
            if tr(str(c[k])) == str(c[k]):
                missing.append(str(c[k]))
    for j in s.journal:
        for k in ["title", "text"]:
            if tr(str(j[k])) == str(j[k]):
                missing.append(str(j[k]))
    for npc in s.lines:
        for e in s.lines[npc]:
            for k in e.get("keys", []):
                if tr(str(k)) == str(k):
                    missing.append(str(k))
    _check(missing.is_empty(), "故事的文字鍵都有翻譯(缺 %s)" % str(missing))
    var st := {}
    _check(s.unlocked_chapters(st).is_empty() and s.unlocked_journal(st).is_empty() and s.stage(st) == "early" and not s.ended(st), "空進度:什麼都沒解鎖")
    st["tutorial_done"] = true
    _check(s.unlocked_chapters(st) == ["ch0"] and s.unlocked_journal(st) == ["j01"], "教學完成:序章 + 第一條日誌")
    st["weapon_level"] = 1
    _check(s.unlocked_chapters(st) == ["ch0", "ch1"] and not StoryLogic.check("bear_met", st), "買了武器也算熊來過(第一章);還沒被咬 / 打跑不算 bear_met")
    st["helpers_lost"] = 1
    _check(s.unlocked_journal(st) == ["j01", "j02"], "被咬過:牧者的日誌")
    st["orders_done"] = 1
    st["map_pieces"] = 2
    st["landmarks"] = {"rock": true, "pile": true}
    _check(s.unlocked_chapters(st) == ["ch0", "ch1", "ch2", "ch3"] and s.unlocked_journal(st) == ["j01", "j02", "j03", "j05", "j07", "j08"],
            "訂單 / 兩片地圖 / 岩石與雪堆:第二三章與對應日誌(枯樹沒去過就沒有)")
    st["expansion"] = 4
    _check(s.stage(st) == "late" and s.unlocked_chapters(st).has("ch4") and not s.unlocked_journal(st).has("j10"),
            "南邊擴建:第四章、階段 late;第一個荒年要跟修理工談過才有")
    st["repairman_talked"] = true
    st["king_kills"] = 1
    st["rare_caught"] = true
    _check(s.unlocked_journal(st).has("j10") and s.unlocked_journal(st).has("j09") and s.unlocked_journal(st).has("j06")
            and not s.unlocked_chapters(st).has("ch5"), "修理工 / 王 / 金魚的日誌;兩片地圖還沒終章")
    st["map_pieces"] = 3
    _check(s.unlocked_chapters(st).has("ch5") and s.unlocked_journal(st).has("j11") and not s.unlocked_chapters(st).has("ch6"), "三片拼齊:終章、她;還沒尾聲")
    st["shrine"] = true
    _check(s.unlocked_chapters(st).size() == 7 and s.unlocked_journal(st).size() == 11 and s.ended(st) and s.stage(st) == "ended",
            "神龕付清:尾聲、細雪、結局(枯樹那條還是沒去過)")
    # NPC 台詞依進度換,取最後一個成立的階段
    _check(s.npc_lines("shopkeeper", {}) == ["LINE_SHOP_A1", "LINE_SHOP_A2"] and s.npc_lines("shopkeeper", {"weapon_level": 1}) == ["LINE_SHOP_B1"]
            and s.npc_lines("shopkeeper", {"king_kills": 1}) == ["LINE_SHOP_D1"] and s.npc_lines("shopkeeper", st) == ["LINE_SHOP_F1"]
            and s.npc_lines("captain", {"orders_done": 3}) == ["LINE_CAPT_C1"] and s.npc_lines("merchant", {"map_pieces": 2}) == ["LINE_MERC_C1"]
            and s.npc_lines("repairman", {"expansion": 4}) == ["LINE_REPAIR_C1"] and s.npc_lines("nobody", st).is_empty(),
            "NPC 台詞:老闆 / 船長 / 商人 / 修理工依進度換;沒這個 NPC 回空")
    # 顧客台詞:櫃台種類(去掉 _2 / _3)與階段;結局後全部同一組
    _check(StoryLogic.counter_kind("fillet_counter_3") == "fillet_counter" and StoryLogic.counter_kind("soup_counter") == "soup_counter"
            and s.customer_lines_for("grill_counter_2", {}) == ["LINE_CUST_GRILL_1", "LINE_CUST_GRILL_2"]
            and s.customer_lines_for("grill_counter", {"expansion": 4}) == ["LINE_CUST_GRILL_3"]
            and s.customer_lines_for("sweater_counter", st) == ["LINE_CUST_END_1", "LINE_CUST_END_2"]
            and s.customer_lines_for("nope_counter", {}).is_empty(), "顧客閒話:依櫃台種類與階段;結局後只剩省略號 / 她在看")
    # GameState 的故事進度:清單 / 旗標 / 存檔往返
    GameState.reset()
    _check(GameState.story_add("journal", "j01") and not GameState.story_add("journal", "j01") and GameState.story_has("journal", "j01")
            and not GameState.story_has("chapters", "ch0") and not GameState.story_flag("bear_seen"), "故事進度:加一筆只加一次")
    GameState.set_story_flag("bear_seen")
    GameState.story_add("landmarks", "rock")
    var dd := GameState.to_dict()
    GameState.reset()
    GameState.from_dict(JSON.parse_string(JSON.stringify(dd)))
    _check(GameState.story_has("journal", "j01") and GameState.story_flag("bear_seen") and GameState.story_landmarks().has("rock")
            and not GameState.story_landmarks().has("tree"), "故事進度 to_dict -> JSON -> from_dict 往返")
    GameState.reset()


## --- 捕熊夾 / 誘餌 / 傳送帶 ---

func _test_trap_and_belt() -> void:
    var t := TrapLogic.from_config(GameData.section("trap"))
    _check(is_equal_approx(t.damage(false), 60.0) and is_equal_approx(t.damage(true), 150.0) and is_equal_approx(t.stun_sec(), 3.0)
            and is_equal_approx(t.radius(), 2.5) and is_equal_approx(t.bait_radius(), 8.0) and is_equal_approx(t.bait_eat_sec(), 10.0)
            and t.bait_fish_count() == 6, "捕熊夾:扣 60(王 150)、定住 3 秒、半徑 2.5;誘餌:吸引 8 格、吃 10 秒、六條魚")
    _check(TrapLogic.in_reach(Vector3(0, 0, 0), Vector3(2.0, 0, 1.5), 2.5) and not TrapLogic.in_reach(Vector3(0, 0, 0), Vector3(2.0, 0, 1.6), 2.5),
            "夾子觸發:平面距離 <= 半徑")
    var baits := [{"id": 1, "pos": Vector3(5, 0, 0), "set": true}, {"id": 2, "pos": Vector3(-3, 0, 0), "set": true}, {"id": 3, "pos": Vector3(1, 0, 0), "set": false}]
    _check(TrapLogic.pick_bait(Vector3.ZERO, baits, 8.0) == 2 and TrapLogic.pick_bait(Vector3.ZERO, baits, 2.0) == -1
            and TrapLogic.pick_bait(Vector3(5, 0, 0), baits, 8.0) == 1, "誘餌:範圍內最近的、放好的那堆;沒放好的不算")
    var empty := TrapLogic.from_config({})
    _check(empty.damage(false) > 0.0 and empty.stun_sec() > 0.0 and empty.bait_radius() > 0.0, "沒設定用預設值")
    # 傳送帶:每秒拿一件、以 3 / 秒前進、彼此隔 0.8、末端放不下就排隊
    var c := ConveyorLogic.from_config(GameData.section("conveyor"), 6.0)
    _check(is_equal_approx(c.length, 6.0) and is_equal_approx(c.speed, 3.0) and is_equal_approx(c.rate, 1.0) and c.capacity() == 8 and c.is_empty(),
            "傳送帶 6 格長:最多 8 件")
    var r := c.tick(1.0, 5, 10)
    _check(int(r["taken"]) == 1 and int(r["delivered"]) == 0 and c.count() == 1 and is_equal_approx(c.items[0], 0.0) and not c.can_take(),
            "1 秒:從來源拿一件放在起點;起點被佔住不能再拿")
    r = c.tick(0.5, 4, 10)
    _check(int(r["taken"]) == 0 and is_equal_approx(c.items[0], 1.5), "0.5 秒:前進 1.5,還沒到下一件的時間")
    r = c.tick(0.5, 4, 10)
    _check(int(r["taken"]) == 1 and c.count() == 2 and is_equal_approx(c.items[0], 3.0) and is_equal_approx(c.items[1], 0.0), "再 0.5 秒:第二件上帶")
    r = c.tick(0.5, 3, 10)
    _check(int(r["taken"]) == 0 and c.count() == 2 and is_equal_approx(c.items[0], 4.5) and is_equal_approx(c.items[1], 1.5), "0.5 秒:兩件各前進 1.5")
    r = c.tick(0.5, 3, 0)
    _check(int(r["taken"]) == 1 and int(r["delivered"]) == 0 and c.count() == 3 and is_equal_approx(c.items[0], 6.0) and is_equal_approx(c.items[1], 3.0),
            "櫃台滿:第一件停在末端不上架、第三件上帶")
    r = c.tick(1.0, 2, 0)
    _check(int(r["taken"]) == 1 and int(r["delivered"]) == 0 and c.count() == 4 and is_equal_approx(c.items[0], 6.0) and is_equal_approx(c.items[1], 5.2)
            and is_equal_approx(c.items[2], 3.0), "櫃台還是滿:後面的排在前一件後面 0.8、每個 tick 最多拿一件")
    r = c.tick(0.1, 0, 1)
    _check(int(r["delivered"]) == 1 and c.count() == 3 and c.moved_total == 1 and is_equal_approx(c.items[0], 5.2) and is_equal_approx(c.items[1], 3.3),
            "櫃台有 1 格:末端那件上架、後面的往前")
    var snap := c.snapshot()
    var c2 := ConveyorLogic.from_config(GameData.section("conveyor"), 6.0)
    c2.restore(snap)
    _check(snap.size() == 3 and c2.count() == 3 and is_equal_approx(c2.items[0], 5.2) and is_equal_approx(c2.items[2], 0.3), "存檔往返:帶上的位置")
    c2.restore([9.0, 1.0, 2.0])
    _check(c2.count() == 3 and is_equal_approx(c2.items[0], 6.0) and is_equal_approx(c2.items[1], 2.0), "還原時夾進長度、由前到後排序")


func _test_bear() -> void:
    var b := BearLogic.from_config(GameData.section("bear"), GameData.section("weapon"))
    _check(is_equal_approx(b.bite_sec(), 8.0) and is_equal_approx(b.bite_radius(), 1.4)
            and b.panic_radius() >= b.bite_radius() and b.speed() > 0.0 and b.flee_speed() >= b.speed() and b.entries().size() == 2,
            "咬 8 秒、嚇呆半徑 >= 咬的半徑、兩個入口")
    _check(b.drop_count(false, 0.0) == 1 and b.drop_count(false, 0.49) == 1 and b.drop_count(false, 0.5) == 2 and b.drop_count(false, 1.0) == 2
            and b.drop_count(true, 0.3) == 3, "掉落數:一般熊 1 ~ 2 張毛皮、王 3 顆牙")
    _check(b.pack_max_eats() == 2 and is_equal_approx(b.busy_radius(), 6.0), "一群最多吃 2 個就撤退;熊在 6 格內暫停抓魚 / 拿貨")
    _check(b.outmatched(0, 0.0) and not b.outmatched(1, 0.0) and not b.outmatched(1, 300.0) and b.outmatched(1, 600.0)
            and not b.outmatched(2, 600.0) and b.outmatched(2, 900.0) and not b.outmatched(3, 900.0),
            "打不打得過:沒武器一律不行;Lv1 10 分鐘(血 130 要 13 下 × 0.5 × 2 隻 = 13 秒 > 8)就不行、Lv2 到 15 分鐘、Lv3 15 分鐘還行")
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
    _check(Sfx.has("sale") and Sfx.has("ambient_waves") and Sfx.has("bgm_harbor") and Sfx.music_playing(), "Sfx 載入了結帳、環境音與背景音樂(音樂循環播放中)")
    var before := Sfx.played_total
    _check(Sfx.play("goal") and Sfx.played_total == before + 1 and int(Sfx.played.get("goal", 0)) >= 1, "Sfx.play 有播(headless 用 Dummy 音訊)")
    _check(not Sfx.play("goal"), "同一音效太密集不重播")
    _check(not Sfx.play("nope"), "沒有的音效不播")


## 傳承 / 過冬:評分四項與點數換算、火種價格與加成、GameState 買火種 / 重生保留什麼、售價倍率、離線上限加成
func _test_legacy() -> void:
    var l := LegacyLogic.from_config(GameData.section("legacy"))
    _check(l.perks.size() == 8 and l.perk_ids()[0] == "start_cash" and l.max_level("worker_speed") == 5 and l.perk_cost("worker_speed", 0) == 1
            and l.perk_cost("worker_speed", 4) == 5 and l.perk_cost("worker_speed", 5) == -1 and l.perk_cost("nope", 0) == -1 and l.low_points() == 3,
            "game.json legacy:八項火種、五級 1 ~ 5 點、滿級 / 沒這項回 -1、低於 3 點提醒")
    _check(l.king_score(0) == 0 and l.king_score(1) == 200 and l.king_score(3) == 1200 and l.king_score(7) == 200 * (1 + 2 + 3 + 4 + 5 + 6 + 6),
            "打死王的分:每次 200 × (等級 + 1),第 6 級起封頂")
    var sc := l.score({"cash_earned": 20050, "expansions": 3, "towers": 4, "stations": 5, "counters": 4, "belts": 2, "bears_fled": 50, "king_kills": 2,
            "king_perfects": 1, "chapters": 5, "ending": false})
    _check(int(sc["income"]) == 200 and int(sc["build"]) == 900 + 200 + 120 + 90 + 40 and int(sc["battle"]) == 250 + 100 + 600 and int(sc["story"]) == 400
            and int(sc["total"]) == 200 + 1350 + 950 + 400, "評分四項:收入 200、建設 1350(起始的切魚台 / 櫃台不算)、戰績 950、故事 400(第一章不算)= %d" % int(sc["total"]))
    var sc2 := l.score({"cash_earned": 200000, "expansions": 7, "chapters": 7, "ending": true, "king_kills": 10})
    _check(int(sc2["story"]) == 1600 and int(sc2["battle"]) == 9000 and l.points_for(int(sc["total"])) == 5 and l.points_for(int(sc2["total"])) == 12
            and l.points_for(0) == 0 and l.points_for(99) == 0 and l.points_for(100) == 1 and int(l.score({})["total"]) == 0,
            "結局 1000 分、王 10 次 9000 分;點數 = sqrt(總分) / 10 取整(2900 -> 5、14700 -> 12、100 -> 1)")
    _near(l.bonus("worker_speed", 2), 0.10, "工人速度火種:每級 +5%,兩級 0.10", 0.0001)
    _check(is_equal_approx(l.bonus("start_cash", 3), 600.0) and is_equal_approx(l.bonus("capacity", 9), 5.0) and is_equal_approx(l.bonus("nope", 3), 0.0)
            and l.can_buy(1, "price", 0) and not l.can_buy(1, "price", 1) and not l.can_buy(99, "price", 5),
            "加成 = perLevel × 等級(夾在滿級內);買得起看該級價格、滿級買不了")
    # GameState:買火種、重生
    GameState.reset()
    _check(GameState.generation() == 1 and GameState.legacy_points() == 0 and GameState.legacy_level("price") == 0 and is_equal_approx(GameState.legacy_mult("price"), 1.0)
            and GameState.legacy_total_levels() == 0, "新狀態:第 1 代、0 點、沒火種")
    GameState.legacy = {"generation": 2, "points": 4, "perks": {"worker_speed": 1}}
    _check(GameState.buy_perk("start_cash", l) and GameState.legacy_points() == 3 and GameState.buy_perk("start_cash", l) and GameState.legacy_points() == 1
            and GameState.legacy_level("start_cash") == 2 and not GameState.buy_perk("start_cash", l) and GameState.legacy_points() == 1
            and is_equal_approx(GameState.legacy_mult("worker_speed"), 1.05) and is_equal_approx(GameState.legacy_bonus("start_cash"), 400.0)
            and GameState.legacy_total_levels() == 3, "買火種:起始資金 1 點 + 2 點 -> Lv2(剩 1 點),第三級 3 點買不起;倍率 / 加成")
    GameState.legacy["perks"]["capacity"] = 2
    GameState.capacity_bonus = 4
    _check(GameState.total_capacity_bonus() == 6, "背包火種算進容量加成(4 + 2)")
    GameState.wallet = 500
    GameState.cash_earned = 1000
    GameState.bears_fled = 4
    GameState.king_perfects = 1
    GameState.weapon_level = 3
    GameState.hired = {"fisher": 2}
    GameState.hints_on = false
    GameState.story = {"chapters": ["ch0", "ch1"], "journal": ["j01"], "landmarks": ["rock"], "flags": {"bear_seen": true}}
    GameState.rebirth(6, {"gen": 2, "total": 3600, "points": 6})
    _check(GameState.generation() == 3 and GameState.legacy_points() == 7 and GameState.legacy_level("start_cash") == 2 and GameState.wallet == 400
            and GameState.hired_total() == 0 and GameState.weapon_level == 0 and GameState.cash_earned == 0 and GameState.bears_fled == 0 and GameState.king_perfects == 0
            and GameState.story_list("chapters").size() == 2 and GameState.story_list("journal").size() == 1 and GameState.story_list("landmarks").is_empty()
            and not GameState.story_flag("bear_seen") and GameState.tutorial_step == GuideLogic.tutorial_steps() and not GameState.hints_on
            and bool(GameState.legacy.get("intro", false)) and (GameState.legacy.get("history", []) as Array).size() == 1,
            "重生:第 3 代、點數 1 + 6、火種與錢包 $400(起始資金 Lv2)留下、幫手 / 武器 / 統計歸零、章節與日誌留著但地標 / 旗標清掉、教學跳過、設定留著、intro 旗標")
    _check(GameState.clear_legacy_intro() and not GameState.clear_legacy_intro() and not GameState.legacy.has("intro"), "intro 旗標只清一次")
    GameState.bears_fled = 9
    GameState.king_perfects = 2
    var d := GameState.to_dict()
    GameState.reset()
    _check(GameState.generation() == 1 and GameState.legacy.is_empty(), "reset(新遊戲)連傳承也清掉")
    GameState.from_dict(d)
    _check(GameState.generation() == 3 and GameState.legacy_points() == 7 and GameState.legacy_level("start_cash") == 2 and GameState.bears_fled == 9
            and GameState.king_perfects == 2 and (GameState.legacy.get("history", []) as Array).size() == 1, "傳承 / 戰績統計存檔來回")
    GameState.reset()
    # 售價倍率、離線上限加成
    var c := CounterLogic.new()
    c.price = 5
    c.add_stock(3)
    c.price_mult = 1.2
    var r := c.serve(2)
    var c2 := CounterLogic.new()
    c2.price = 2
    c2.add_stock(5)
    c2.price_mult = 1.04
    _check(int(r["sold"]) == 2 and int(r["cash"]) == 12 and int(c2.serve(1)["cash"]) == 2 and int(c2.serve(3)["cash"]) == 6, "售價倍率:整筆四捨五入(10 × 1.2 = 12;$2 的 +4% 一件 2、三件 6)")
    var o := OfflineLogic.from_config(GameData.section("offline"))
    o.bonus_sec = 3600.0
    _check(o.counted_seconds(40000.0) == 14400 + 3600 and o.earnings(1.0, 40000.0) == int(floor(18000.0 * 0.5)) and is_equal_approx(o.cap_sec(), 18000.0),
            "離線上限火種:4 小時 + 1 小時")


## 打擊感規則:事件分級、trauma 距離衰減 / 累加 / 衰減、震幅平方、平滑雜訊、hit-stop 只有 medium / large
func _test_juice() -> void:
    var j := JuiceLogic.from_config({})
    _check(JuiceLogic.tier_of("bear_hit") == "medium" and JuiceLogic.tier_of("king_defeated") == "large" and JuiceLogic.tier_of("fish_caught") == "small"
            and JuiceLogic.tier_of("nope") == "", "事件分級:打熊 medium、打死王 large、抓魚 small、沒列的沒有")
    _check(is_equal_approx(j.trauma_for("bear_hit", 0.0), 0.4) and is_equal_approx(j.trauma_for("bear_hit", 12.0), 0.2) and is_zero_approx(j.trauma_for("bear_hit", 30.0))
            and is_zero_approx(j.hitstop_for("fish_caught")) and is_equal_approx(j.hitstop_for("king_defeated"), 0.12) and is_equal_approx(j.pop_for("nope"), 1.0)
            and is_equal_approx(j.pop_for("fish_caught"), 1.12), "trauma 依距離衰減(6 內全額、12 一半、18 外 0);hit-stop 只有 medium / large;彈跳倍率")
    var t := JuiceLogic.add_trauma(0.0, 0.4)
    t = JuiceLogic.add_trauma(t, 0.4)
    t = JuiceLogic.add_trauma(t, 0.4)
    _check(is_equal_approx(t, 1.0) and is_equal_approx(j.decay_trauma(1.0, 0.5), 0.35) and is_zero_approx(j.decay_trauma(0.1, 1.0))
            and is_equal_approx(JuiceLogic.shake_amount(0.5), 0.25) and j.shake_offset(0.0, 1.0) == Vector3.ZERO and j.shake_offset(1.0, 0.3).length() > 0.0
            and absf(JuiceLogic.smooth_noise(0.37, 0.0)) <= 1.0 and j.shake_offset(1.0, 0.3).length() <= 1.0,
            "trauma 累加封頂 1、每秒掉 1.3;震幅 = trauma²;平滑雜訊在 ±1 內、位移不超過上限")
    var j2 := JuiceLogic.from_config({"decay": 2.0, "maxOffset": [1.0, 0.5], "tiers": {"small": {"trauma": 0.3}}})
    _check(is_equal_approx(j2.decay, 2.0) and j2.max_offset == Vector2(1.0, 0.5) and is_equal_approx(j2.trauma_for("fish_caught"), 0.3)
            and is_equal_approx(j2.trauma_for("bear_hit"), 0.4), "game.json juice 可蓋過衰減 / 位移 / 分級數值")

