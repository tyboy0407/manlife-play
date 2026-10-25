extends Node3D
## 世界整合 headless 驗證(3D 物理):建關卡 -> 走進水裡抓魚到滿 -> 切魚台輸入格卸貨 -> 工人切 -> 輸出格拿魚片 ->
## 櫃台上架 -> 顧客排隊購買、錢進錢格 -> 錢格撿錢 -> 價格牌分期付款 -> 僱漁夫(自己抓魚、卸貨)-> 擴充背包 -> 增建切魚台。
## 玩家用合成輸入(朝目標走)。跑法:godot --headless --path . res://tests/verify_world.tscn(先 --import)

const HARBOR := preload("res://game/levels/harbor.tscn")

var _fails := 0
var _level: Harbor
var _player: Player
var _target := Vector3.ZERO
var _moving := false
var _events := {}


func _ready() -> void:
    print("VERIFY WORLD: begin")
    GameState.reset()
    EventBus.fish_caught.connect(func(_c: Node3D) -> void: _bump("fish"))
    EventBus.sale_made.connect(func(_i: String, _n: int, _cash: int) -> void: _bump("sale"))
    EventBus.purchased.connect(func(id: String, _e: Dictionary) -> void: _bump("purchased_" + id))
    EventBus.helper_hired.connect(func(_r: String, _h: Node3D) -> void: _bump("hired"))
    EventBus.notice.connect(func(_t: String) -> void: _bump("notice"))
    EventBus.items_processed.connect(func(_s: String, n: int) -> void: _bump("processed", n))
    await _run()
    GameState.reset()
    if _fails == 0:
        print("VERIFY WORLD: ALL OK")
    else:
        print("VERIFY WORLD: %d FAILURES" % _fails)
    get_tree().quit(1 if _fails > 0 else 0)


## --- 工具 ---

func _check(cond: bool, label: String) -> void:
    if cond:
        print("  OK   %s" % label)
    else:
        _fails += 1
        print("  FAIL %s" % label)


func _bump(key: String, n: int = 1) -> void:
    _events[key] = int(_events.get(key, 0)) + n


func _count(key: String) -> int:
    return int(_events.get(key, 0))


func _step(frames: int) -> void:
    for i in frames:
        await get_tree().physics_frame


func _wait_until(pred: Callable, max_frames: int) -> bool:
    for i in max_frames:
        if pred.call():
            return true
        await get_tree().physics_frame
    return pred.call()


func _provide() -> MoveInput:
    if not _moving or _player == null:
        return MoveInput.new()
    return MoveInput.toward(_player.global_position, _target, 0.25)


## 走到 p(平面距離 < 0.4 算到),回傳有沒有在時限內到
func _go(p: Vector3, max_frames: int = 300) -> bool:
    _target = p
    _moving = true
    var ok := await _wait_until(func() -> bool: return _player.planar_distance_to(p) < 0.4, max_frames)
    _moving = false
    await _step(2)
    return ok


## 來回錢格與價格牌直到付清(或錢格沒錢)
func _pay_pad(pad: PricePad) -> void:
    for round in 10:
        if pad.logic.is_paid():
            return
        await _go(_level.money_pad.global_position)
        await _wait_until(func() -> bool: return _player.stack.is_full() or _level.money_pad.cash == 0, 120)
        if _player.stack.is_empty() or _player.stack.item_id != "cash":
            return
        await _go(pad.global_position)
        await _wait_until(func() -> bool: return pad.logic.is_paid() or _player.stack.is_empty(), 240)


## --- 流程 ---

func _run() -> void:
    _level = HARBOR.instantiate()
    add_child(_level)
    await _step(3)
    _player = _level.player
    _player.input_provider = _provide
    _check(_player != null and _level.fish_area != null and _level.stations.size() == 1 and _level.counter != null
            and _level.money_pad != null and _level.price_pads.size() == 3, "關卡建好:玩家、水、切魚台、櫃台、錢格、三塊價格牌")
    _check(_level.camera != null and _level.camera.current and _level.hud != null and _player.is_in_group("player"),
            "相機與 HUD、玩家分組")
    _check(_player.stack.capacity == 8 and _player.stack.is_empty() and _player.speed > 0.0, "玩家背包 8、空手")
    await _step(30)
    _check(_level.fish_area.fish.size() >= 8, "水裡有魚(%d)" % _level.fish_area.fish.size())
    _check(get_tree().get_nodes_in_group("pad").size() >= 7, "格子:輸入 / 輸出 / 上架 / 錢 / 三塊價格牌(%d)" % get_tree().get_nodes_in_group("pad").size())
    # 抓魚
    var ok := await _go(Vector3(0, 0, -7.5), 240)
    var first := await _wait_until(func() -> bool: return _player.stack.item_id == "fish", 120)
    _check(ok and first, "走進水裡開始抓魚")
    var sweep := [Vector3(-5, 0, -8.5), Vector3(5, 0, -8.5), Vector3(-5, 0, -5.5), Vector3(5, 0, -5.5), Vector3(0, 0, -9.5), Vector3(0, 0, -5)]
    var i := 0
    while not _player.stack.is_full() and i < 18:
        await _go(sweep[i % sweep.size()], 240)
        i += 1
    _check(_player.stack.is_full() and _player.stack.count == 8 and _player.stack.item_id == "fish", "背包抓滿 8 條魚(%d)" % _player.stack.count)
    _check(_count("fish") >= 8 and GameState.fish_caught >= 8 and _player.caught_total >= 8, "fish_caught 事件與統計(%d)" % _count("fish"))
    _check(not _level.fish_area.fish.is_empty(), "魚會補生")
    # 放到輸入格
    var st: Station = _level.stations[0]
    ok = await _go(st.input_pad.global_position)
    var emptied := await _wait_until(func() -> bool: return _player.stack.is_empty(), 120)
    _check(ok and emptied and st.logic.input_count >= 1, "輸入格:魚卸進切魚台(輸入堆 %d)" % st.logic.input_count)
    # 工人切
    var produced := await _wait_until(func() -> bool: return st.logic.output_count >= 4, 300)
    _check(produced and _count("processed") >= 4, "工人切魚:輸出堆 %d 片、items_processed" % st.logic.output_count)
    _check(st.output_pile.count == st.logic.output_count and st.input_pile.count == st.logic.input_count, "格子上的堆疊外觀與數量一致")
    # 取魚片
    ok = await _go(st.output_pad.global_position)
    var got := await _wait_until(func() -> bool: return _player.stack.item_id == "fillet" and _player.stack.count >= 4, 120)
    _check(ok and got, "輸出格:拿到魚片 %d" % _player.stack.count)
    # 上架
    var cnt: Counter = _level.counter
    ok = await _go(cnt.deposit_pad.global_position)
    var stocked := await _wait_until(func() -> bool: return cnt.logic.stock >= 4, 120)
    _check(ok and stocked and _player.stack.is_empty(), "櫃台上架 %d 件" % cnt.logic.stock)
    # 顧客購買
    var sold := await _wait_until(func() -> bool: return _count("sale") >= 2 and _level.money_pad.cash >= 4, 600)
    _check(sold, "顧客排隊購買:賣出 %d 筆、錢格 $%d" % [_count("sale"), _level.money_pad.cash])
    _check(get_tree().get_nodes_in_group("customer").size() >= 1 and GameState.cash_earned >= 4 and GameState.items_sold >= 2,
            "有顧客在排隊、統計累計")
    # 撿錢
    ok = await _go(_level.money_pad.global_position)
    var picked := await _wait_until(func() -> bool: return _player.stack.item_id == "cash" and _player.stack.count >= 4, 120)
    _check(ok and picked, "錢格撿錢 %d" % _player.stack.count)
    # 僱漁夫:分期付款
    var pad: PricePad = _level.price_pads["hire_fisher"]
    _level.money_pad.add_cash(40)
    await _go(_level.money_pad.global_position)
    await _wait_until(func() -> bool: return _player.stack.is_full(), 120)
    _check(_player.stack.item_id == "cash" and _player.stack.count == 8, "撿滿 8 現金")
    ok = await _go(pad.global_position)
    var partial := await _wait_until(func() -> bool: return pad.logic.remaining == 2 and _player.stack.is_empty(), 120)
    _check(ok and partial and not pad.logic.is_paid() and pad.visible, "價格牌分期:付了 8 剩 2,牌子還在")
    await _go(_level.money_pad.global_position)
    await _wait_until(func() -> bool: return _player.stack.count >= 2, 120)
    await _go(pad.global_position)
    var paid := await _wait_until(func() -> bool: return pad.logic.is_paid(), 120)
    await _step(2)
    _check(paid and not pad.visible and _count("purchased_hire_fisher") == 1 and _count("hired") == 1
            and _level.helpers.size() == 1 and GameState.hired_count("fisher") == 1 and GameState.is_unlocked("hire_fisher"),
            "付清 $10:牌子消失、僱到漁夫")
    _check(_player.stack.item_id == "cash" and _player.stack.count == 6, "付完剩 6 元在手上(%d)" % _player.stack.count)
    # 漁夫 AI
    var h: Helper = _level.helpers[0]
    _check(not h.takes_output and not h.collects_cash and h.can_fish and h.stack.capacity == 6 and h.station == st, "漁夫旗標與容量")
    var fished := await _wait_until(func() -> bool: return h.caught_total >= 1, 600)
    _check(fished, "漁夫自己下水抓魚(%d)" % h.caught_total)
    var deposited := await _wait_until(func() -> bool: return h.deposited_total >= 1, 1200)
    _check(deposited, "漁夫把魚卸進切魚台(%d)" % h.deposited_total)
    # 擴充背包
    var cap_pad: PricePad = _level.price_pads["capacity_1"]
    _level.money_pad.add_cash(60)
    await _pay_pad(cap_pad)
    _check(cap_pad.logic.is_paid() and _player.stack.capacity == 12 and GameState.capacity_bonus == 4, "擴充背包:容量 8 -> 12")
    # 增建切魚台
    var ex: PricePad = _level.price_pads["expand_table"]
    _check(ex.build_spot and ex.visible, "建地牌是橘色建地")
    _level.money_pad.add_cash(80)
    await _pay_pad(ex)
    await _step(2)
    _check(ex.logic.is_paid() and _level.stations.size() == 2 and not ex.visible
            and get_tree().get_nodes_in_group("station").size() == 2 and GameState.is_unlocked("station_2"),
            "增建切魚台:第二座出現、建地牌消失")
    _check(_count("notice") >= 3, "通知事件(%d)" % _count("notice"))
    _level.queue_free()
    await _step(2)
