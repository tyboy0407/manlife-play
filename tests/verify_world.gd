extends Node3D
## 世界整合 headless 驗證(3D 物理):建關卡 -> 抓魚到滿 -> 切魚台卸貨 / 切 / 取魚片 -> 櫃台上架 -> 沒人收銀不賣、玩家站收銀格才賣 ->
## 錢格收進錢包(不佔背包)、帶錢走過價格牌不付、站著才分期付 -> 僱收銀員(接手收銀)-> 垃圾桶丟魚 -> 僱搬運工(自己把成品送到櫃台)->
## 升級牌(工人速度 / 堆疊上限,越買越貴)-> 再僱漁夫(可重複牌)-> 增建烤魚攤(第二條貨物鏈:魚片 -> 烤魚 -> 烤魚櫃台 $5)->
## 搬運工送不出去會放回來源、最缺貨的櫃台優先補 ->
## 存檔 / 重建關卡還原 -> 清存檔。玩家用合成輸入(朝目標走);買東西的錢用 money_pad.add_cash 補。
## 跑法:godot --headless --path . res://tests/verify_world.tscn(先 --import)

const HARBOR := preload("res://game/levels/harbor.tscn")

var _fails := 0
var _level: Harbor
var _player: Player
var _target := Vector3.ZERO
var _moving := false
var _events := {}
var _sales: Array = []   # [item, count, cash]


func _ready() -> void:
    print("VERIFY WORLD: begin")
    SaveManager.save_path = "user://_verify_world_save.json"
    SaveManager.delete()
    GameState.reset()
    Settings.path = "user://_verify_world_settings.json"
    Settings.quality = Settings.FINE
    Settings.show_fps = false
    EventBus.fish_caught.connect(func(_c: Node3D) -> void: _bump("fish"))
    EventBus.sale_made.connect(func(item: String, n: int, cash: int) -> void:
        _bump("sale")
        _sales.append([item, n, cash]))
    EventBus.purchased.connect(func(id: String, _e: Dictionary) -> void: _bump("purchased_" + id))
    EventBus.helper_hired.connect(func(role: String, _h: Node3D) -> void: _bump("hired_" + role))
    EventBus.items_processed.connect(func(sid: String, n: int) -> void:
        _bump("processed", n)
        _bump("processed_" + sid, n))
    EventBus.cash_collected.connect(func(_c: Node3D, n: int) -> void: _bump("collected", n))
    EventBus.items_moved.connect(func(kind: String, _i: String, _f: Vector3, _t: Vector3, n: int) -> void:
        _bump("moved", n)
        _bump("moved_" + kind, n))
    EventBus.tutorial_step_done.connect(func(_s: int) -> void: _bump("tut_step"))
    EventBus.tutorial_finished.connect(func() -> void: _bump("tut_done"))
    await _run()
    Sfx.stop_all()   # 還在播的音效離開時會被報成洩漏
    await _step(25)   # 讓還在飛的幽靈物件飛完、queue_free 處理掉
    SaveManager.delete()
    SaveManager.save_path = SaveManager.DEFAULT_PATH
    Settings.delete_file()
    Settings.path = Settings.DEFAULT_PATH
    Settings.load_settings()
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
func _go(p: Vector3, max_frames: int = 420) -> bool:
    _target = p
    _moving = true
    var ok := await _wait_until(func() -> bool: return _player.planar_distance_to(p) < 0.4, max_frames)
    _moving = false
    await _step(2)
    return ok


## 手上有東西就丟進垃圾桶(要空手才能抓魚 / 拿貨)
func _empty_hands() -> void:
    if _player.stack.is_empty():
        return
    await _go(_level.trash_pad.global_position)
    await _wait_until(func() -> bool: return _player.stack.is_empty(), 180)


## 錢包不夠就先到錢格收錢,再站到牌子上付清這一次(站上去要等 payDelaySec 才開始付);回傳有沒有買成
func _pay_pad(pad: PricePad) -> bool:
    var buys := pad.logic.buys
    var need := pad.logic.remaining
    if GameState.wallet < need:
        await _go(_level.money_pad.global_position)
        await _wait_until(func() -> bool: return GameState.wallet >= need or _level.money_pad.cash == 0, 240)
    await _go(pad.global_position)
    await _wait_until(func() -> bool: return pad.logic.buys > buys or pad.logic.is_exhausted() or GameState.wallet == 0, 480)
    var ok := pad.logic.buys > buys
    if not ok:
        print("  (pay_pad %s 沒買成:remaining %d buys %d wallet %d money %d)" % [pad.logic.id, pad.logic.remaining, pad.logic.buys,
                GameState.wallet, _level.money_pad.cash])
    return ok


## 下水掃幾個點直到手上有 count 條魚(或掃完)
func _fish_until(count: int, max_sweeps: int = 18) -> void:
    var sweep := [Vector3(-5, 0, -8.5), Vector3(5, 0, -8.5), Vector3(-5, 0, -5.5), Vector3(5, 0, -5.5), Vector3(0, 0, -9.5), Vector3(0, 0, -5)]
    var i := 0
    while (_player.stack.item_id != "fish" or _player.stack.count < count) and i < max_sweeps:
        await _go(sweep[i % sweep.size()], 240)
        i += 1


func _spawn_level() -> void:
    _level = HARBOR.instantiate()
    add_child(_level)
    await _step(3)
    _player = _level.player
    _player.input_provider = _provide


func _find_helper(role: String) -> Helper:
    for h in _level.helpers:
        if h.role == role:
            return h
    return null


func _any_visible(nodes: Array) -> bool:
    for n in nodes:
        if is_instance_valid(n) and (n as Node3D).visible:
            return true
    return false


func _all_visible(nodes: Array) -> bool:
    for n in nodes:
        if is_instance_valid(n) and not (n as Node3D).visible:
            return false
    return true


func _sales_of(item: String) -> int:
    var n := 0
    for s in _sales:
        if str(s[0]) == item:
            n += int(s[1])
    return n


## --- 流程 ---

func _run() -> void:
    await _spawn_level()
    _check(_player != null and _level.fish_area != null and _level.stations.size() == 1 and _level.counters.size() == 1
            and _level.counters[0].def_id == "fillet_counter" and _level.money_pad != null and _level.trash_pad != null
            and _level.price_pads.size() == 8 and not _level.loaded_from_save, "關卡建好:玩家、水、切魚台、魚片櫃台、錢格、垃圾桶、八塊價格牌、沒有存檔")
    _check(_level.camera != null and _level.camera.current and _level.hud != null and _player.is_in_group("player")
            and _player.can_serve and _player.can_use_trash and _player.collects_cash and GameState.wallet == 0, "相機與 HUD、玩家分組與旗標、錢包 0")
    var pads := get_tree().get_nodes_in_group("pad").size()
    _check(pads == 14, "格子數:輸入 / 輸出 / 上架 / 收銀 / 錢 / 垃圾桶 / 八塊價格牌(%d)" % pads)
    # 直式 + 觸控:相機以寬為準;浮動搖桿按哪裡都能推;選單鈕區域不算搖桿
    var js: TouchJoystick = _level.hud.joystick
    _check(js != null and _level.camera.is_portrait() and _level.camera.keep_aspect == Camera3D.KEEP_WIDTH and _level.hud.menu_button != null
            and not _level.hud.menu_open(), "直式視窗:相機以寬為準;HUD 有搖桿與選單鈕(viewport %s, keep_aspect %d)" % [
            str(get_viewport().get_visible_rect().size), _level.camera.keep_aspect])
    var press := InputEventScreenTouch.new()
    press.index = 0
    press.pressed = true
    press.position = Vector2(300, 900)
    var drag := InputEventScreenDrag.new()
    drag.index = 0
    drag.position = Vector2(372, 900)
    var lift := InputEventScreenTouch.new()
    lift.index = 0
    lift.pressed = false
    lift.position = Vector2(372, 900)
    _check(js.handle_event(press) and js.active and js.handle_event(drag) and MoveInput.touch_dir.is_equal_approx(Vector2(0.8, 0.0)),
            "浮動搖桿:按下的地方是中心,往右拖 72 像素 = 0.8")
    _player.input_provider = Callable()
    await _step(12)
    var vx := _player.velocity.x
    _check(vx > 2.0 and absf(_player.velocity.z) < 0.5, "搖桿往右推,玩家往 +X 走(vx %.1f)" % vx)
    _check(js.handle_event(lift) and not js.active and MoveInput.touch_dir == Vector2.ZERO, "放開搖桿:歸零")
    await _step(12)
    _player.input_provider = _provide
    var menu_center := _level.hud.menu_button.get_global_rect().get_center()
    var press_menu := InputEventScreenTouch.new()
    press_menu.index = 0
    press_menu.pressed = true
    press_menu.position = menu_center
    _check(js.is_excluded(menu_center) and not js.handle_event(press_menu) and not js.active, "按在選單鈕上不算搖桿")
    _level.hud.menu_action("toggle")
    _level.hud.menu_action("new_game")
    var confirming := _level.hud.menu_open() and _level.hud.confirming_new_game()
    _level.hud.menu_action("close")
    _check(confirming and not _level.hud.menu_open() and not _level.hud.confirming_new_game() and GameState.hired_total() == 0,
            "選單:重新開始要按兩次,關閉就取消")
    var g: Guide = _level.guide
    _check(g != null and GameState.tutorial_step == 0 and g.in_tutorial and str(g.current.get("kind", "")) == "water" and g.marker.visible
            and g.head_arrow.visible and _level.hud.objective_text().begins_with(tr("HUD_OBJECTIVE").substr(0, 2)),
            "教學第 1 步:指水邊,目標箭頭與頭上箭頭都亮著,HUD 顯示目標")
    await _step(30)
    _check(_level.fish_area.fish.size() >= 8, "水裡有魚(%d)" % _level.fish_area.fish.size())
    # 抓魚 -> 切 -> 取
    await _fish_until(8)
    _check(_player.stack.is_full() and _player.stack.item_id == "fish" and _count("fish") >= 8, "背包抓滿 8 條魚")
    var st: Station = _level.stations[0]
    await _step(8)
    _check(GameState.tutorial_step == 1 and str(g.current.get("kind", "")) == "station_input"
            and g.target_pos.distance_to(st.input_pad.global_position) < 0.1, "教學第 2 步:指切魚台輸入格")
    await _go(st.input_pad.global_position)
    var emptied := await _wait_until(func() -> bool: return _player.stack.is_empty(), 120)
    _check(emptied and st.logic.input_count >= 1, "輸入格:魚卸進切魚台(%d)" % st.logic.input_count)
    await _step(8)
    _check(GameState.tutorial_step == 2 and str(g.current.get("kind", "")) == "station_output"
            and g.target_pos.distance_to(st.output_pad.global_position) < 0.1, "教學第 3 步:指輸出格")
    var produced := await _wait_until(func() -> bool: return st.logic.output_count >= 8, 400)
    _check(produced and _count("processed") >= 8, "工人切魚:輸出堆 %d 片" % st.logic.output_count)
    await _go(st.output_pad.global_position)
    var got := await _wait_until(func() -> bool: return _player.stack.item_id == "fillet" and _player.stack.is_full(), 120)
    _check(got, "輸出格:拿滿 8 片魚片")
    # 上架 -> 沒人收銀不賣 -> 站收銀格才賣
    var cnt: Counter = _level.counters[0]
    await _step(8)
    _check(GameState.tutorial_step == 3 and str(g.current.get("kind", "")) == "counter_deposit"
            and g.target_pos.distance_to(cnt.deposit_pad.global_position) < 0.1, "教學第 4 步:指櫃台上架格")
    await _go(cnt.deposit_pad.global_position)
    var stocked := await _wait_until(func() -> bool: return cnt.logic.stock >= 8, 120)
    _check(stocked and _player.stack.is_empty(), "櫃台上架 %d 件" % cnt.logic.stock)
    await _step(8)
    _check(GameState.tutorial_step == 4 and str(g.current.get("kind", "")) == "service"
            and g.target_pos.distance_to(cnt.service_pad.global_position) < 0.1, "教學第 5 步:指收銀格")
    await _go(Vector3(0, 0, 7))
    var waiting := await _wait_until(func() -> bool: return cnt.waiting_customers() >= 1, 240)
    await _step(90)
    _check(waiting and _count("sale") == 0 and not cnt.has_server(), "有顧客在等,但沒人收銀就不賣")
    await _go(cnt.service_pad.global_position)
    var sold := await _wait_until(func() -> bool: return _count("sale") >= 3 and _level.money_pad.cash >= 6, 400)
    _check(sold and cnt.has_server(), "玩家站收銀格:賣出 %d 筆、錢格 $%d" % [_count("sale"), _level.money_pad.cash])
    _check(GameState.cash_earned >= 6 and GameState.items_sold >= 3, "統計累計")
    await _step(8)
    _check(GameState.tutorial_step == 5 and str(g.current.get("kind", "")) == "money"
            and g.target_pos.distance_to(_level.money_pad.global_position) < 0.1, "教學第 6 步:指錢格")
    # 錢格 -> 錢包(不佔背包)
    await _go(_level.money_pad.global_position)
    var picked := await _wait_until(func() -> bool: return GameState.wallet >= 6, 120)
    _check(picked and _player.stack.is_empty() and _count("collected") == GameState.wallet
            and GameState.cash_earned == GameState.wallet + _level.money_pad.cash,
            "錢格收錢進錢包 $%d,背包仍是空的,賺的錢 = 錢包 + 錢格" % GameState.wallet)
    await _step(8)
    _check(GameState.tutorial_step == 6 and str(g.current.get("kind", "")) == "pad" and str(g.current.get("target", "")) == "hire_fisher"
            and g.target_pos.distance_to((_level.price_pads["hire_fisher"] as PricePad).global_position) < 0.1, "教學第 7 步:指最便宜的牌(僱漁夫)")
    # 帶著錢直直走過擴充背包牌:沒停下來就不付
    var cap1: PricePad = _level.price_pads["capacity_1"]
    var wallet0 := GameState.wallet
    await _go(Vector3(2, 0, 8.2))
    await _go(Vector3(2, 0, 1.8))
    _check(cap1.logic.remaining == 25 and GameState.wallet == wallet0, "帶錢走過價格牌不會付(要站 %.1f 秒才開始)" % cap1.pay_delay)
    # 站到牌子上:停一下開始分期付
    var hc: PricePad = _level.price_pads["hire_cashier"]
    await _go(hc.global_position)
    var partial := await _wait_until(func() -> bool: return hc.logic.remaining < 20, 120)
    _check(partial and hc.logic.buys == 0 and hc.logic.remaining > 0 and wallet0 - GameState.wallet == 20 - hc.logic.remaining,
            "價格牌分期:站著從錢包付了 %d、剩 $%d" % [wallet0 - GameState.wallet, hc.logic.remaining])
    _check(hc.ring != null and hc.ring.progress > 0.0 and hc.ring.drawn_segments() >= 1 and is_equal_approx(hc.ring.progress, hc.logic.progress()),
            "價格牌進度環跟著付款比例(%d 段)" % hc.ring.drawn_segments())
    # 僱收銀員
    _level.money_pad.add_cash(60)
    await _pay_pad(hc)
    await _step(3)
    var cashier := _find_helper("cashier")
    _check(_count("purchased_hire_cashier") == 1 and _count("hired_cashier") == 1 and _level.helpers.size() == 1
            and cashier != null and GameState.hired_count("cashier") == 1, "僱到收銀員")
    _check(cashier != null and cashier.assigned_counter == cnt and cnt.cashier == cashier and cashier.can_serve
            and not cashier.takes_output and not cashier.collects_cash, "收銀員指派到魚片櫃台")
    _check(hc.visible and hc.logic.buys == 1 and hc.logic.current_cost() == 36 and hc.logic.remaining == 36,
            "收銀員牌可再買一次:第二次 $36(付清後站著不會接著付,剩 $%d)" % hc.logic.remaining)
    _check(_player.stack.is_empty() and GameState.wallet >= 0, "錢不佔背包:買完後背包仍空、錢包 $%d" % GameState.wallet)
    await _step(8)
    _check(GameState.tutorial_step == 7 and not g.in_tutorial and _count("tut_done") == 1 and _count("tut_step") == 7
            and str(g.current.get("kind", "")) != "", "買了第一樣東西 -> 教學完成,箭頭轉成提示")
    # 玩家離開,收銀員接手
    if cnt.logic.stock < 2:
        cnt.logic.stock = 4
        cnt.refresh_pile()
    await _go(Vector3(0, 0, 7))
    var cashier_on := await _wait_until(func() -> bool: return cnt.has_server() and _player.planar_distance_to(cnt.service_pad.global_position) >= 1.0, 400)
    var sales_before := _count("sale")
    var sold_more := await _wait_until(func() -> bool: return _count("sale") >= sales_before + 1, 400)
    _check(cashier_on and sold_more, "收銀員站到收銀格,玩家不在也賣得出去")
    # 垃圾桶:丟魚
    await _empty_hands()
    await _fish_until(2, 8)
    var fish_n := _player.stack.count
    await _step(8)
    _check(str(g.current.get("kind", "")) == "station_input" and g.marker.visible, "提示:背著魚 -> 指切魚台")
    _level.hud.menu_action("hints")
    await _step(2)
    _check(not GameState.hints_on and not g.marker.visible and not g.head_arrow.visible and _level.hud.objective_text() == tr("HUD_HINTS_OFF"),
            "選單 / H:關掉提示,箭頭都收起來")
    g.toggle_hints()
    await _step(2)
    _check(GameState.hints_on and g.marker.visible, "H:再開")
    var trashed_before := GameState.items_trashed
    await _go(_level.trash_pad.global_position)
    var trashed := await _wait_until(func() -> bool: return _player.stack.is_empty(), 120)
    _check(fish_n >= 2 and trashed and GameState.items_trashed >= trashed_before + fish_n and _level.trash_pad.trashed_total >= fish_n,
            "垃圾桶:丟掉 %d 條魚" % fish_n)
    # 僱搬運工
    _level.money_pad.add_cash(60)
    await _pay_pad(_level.price_pads["hire_porter"])
    await _step(3)
    var porter := _find_helper("porter")
    _check(porter != null and _count("hired_porter") == 1 and porter.takes_output and not porter.can_fish and not porter.collects_cash, "僱到搬運工")
    if st.logic.output_count < 6:
        st.logic.output_count = 10
        st.refresh_piles()
    var delivered := await _wait_until(func() -> bool: return porter != null and porter.delivered_total >= 1, 1200)
    _check(delivered, "搬運工把魚片送到櫃台(送達 %d)" % (porter.delivered_total if porter != null else 0))
    # 升級牌
    _level.money_pad.add_cash(60)
    var ws: PricePad = _level.price_pads["upgrade_worker_speed"]
    await _pay_pad(ws)
    _check(GameState.upgrade_level("worker_speed") == 1 and is_equal_approx(st.logic.speed_mult, 1.5) and ws.visible and ws.logic.remaining == 34,
            "工人速度 Lv1:速度 ×1.5、下一次 $34")
    _level.money_pad.add_cash(60)
    await _pay_pad(_level.price_pads["upgrade_pile_cap"])
    _check(GameState.upgrade_level("pile_cap") == 1 and st.logic.input_cap == 18 and st.logic.output_cap == 36 and cnt.logic.stock_cap == 45,
            "堆疊上限 Lv1:切魚台 18 / 36、櫃台 45")
    # 再僱漁夫(可重複牌)
    _level.money_pad.add_cash(40)
    await _pay_pad(_level.price_pads["hire_fisher"])
    await _step(3)
    var fisher_pad: PricePad = _level.price_pads["hire_fisher"]
    _check(_count("hired_fisher") == 1 and fisher_pad.visible and fisher_pad.logic.buys == 1 and fisher_pad.logic.remaining == 18
            and GameState.hired_total() == 3, "僱到漁夫,牌子留著、第二次 $18")
    # 增建烤魚攤(從錢格斜穿過擴充背包牌過去,一樣不該付到它)
    _level.money_pad.add_cash(120)
    var bought := await _pay_pad(_level.price_pads["unlock_grill"])
    await _step(3)
    var grill := _level.station_at("grill")
    var gcnt := _level.counter_by_id("grill_counter")
    _check(bought and grill != null and gcnt != null and _level.stations.size() == 2 and _level.counters.size() == 2
            and not (_level.price_pads["unlock_grill"] as PricePad).visible, "烤魚攤 + 烤魚櫃台出現、建地牌消失")
    if grill == null or gcnt == null:
        _fails += 1
        print("  FAIL 烤魚攤沒蓋出來,後面的鏈與存檔檢查略過")
        _level.queue_free()
        await _step(2)
        return
    _check(grill.logic.input_id == "fillet" and grill.logic.output_id == "grilled" and gcnt.logic.item_id == "grilled" and gcnt.logic.price == 5,
            "烤魚攤 魚片 -> 烤魚;烤魚櫃台賣烤魚 $5")
    _check(is_equal_approx(grill.logic.speed_mult, 1.5) and grill.logic.input_cap == 18, "新建的烤魚攤也吃到升級")
    _check(cap1.logic.remaining == 25 and cap1.logic.buys == 0, "一路帶著錢走來走去,沒站過的擴充背包牌一毛都沒收到")
    # 搬運工不會卡住:全部目的地都滿、沒人收銀、烤魚攤因輸出滿而停工 -> 手上的魚片沒地方去 -> 放回切魚台輸出堆
    if cashier != null:
        cashier.assigned_counter = null
        cnt.cashier = null
        cashier.global_position = Vector3(0, 0, -3)   # 搬離收銀格站著,不然櫃台還是會一直賣
    await _step(5)   # 等收銀格「有人」的幀戳過期,之後才填滿,免得最後一筆交易又騰出空位
    cnt.logic.stock = cnt.logic.stock_cap
    cnt.refresh_pile()
    gcnt.logic.stock = gcnt.logic.stock_cap
    gcnt.refresh_pile()
    grill.logic.input_count = grill.logic.input_cap
    grill.logic.output_count = grill.logic.output_cap
    grill.logic.processing = false   # 手上那一份也停掉,輸入堆才會一直是滿的
    grill.logic.progress = 0.0
    grill.refresh_piles()
    st.logic.output_count = 8
    st.refresh_piles()
    var ret0 := 0
    if porter != null:
        porter.stack.clear()
        porter.job = {}
        porter.takes_output = true
        porter.state = "idle"
        ret0 = porter.returned_total
        for i in 3:
            porter.stack.push("fillet")
    await _step(2)
    _check(porter != null and _level.find_dest_for("fillet", null) == null and _level.find_porter_job(8).is_empty(),
            "魚片沒地方去、也沒有工作可派(魚片櫃台 %d/%d、烤魚攤原料 %d/%d)" % [cnt.logic.stock, cnt.logic.stock_cap, grill.logic.input_count, grill.logic.input_cap])
    var returned := await _wait_until(func() -> bool: return porter != null and porter.returned_total >= ret0 + 3, 900)
    var stepped := await _wait_until(func() -> bool: return porter != null and porter.state == "idle", 300)
    _check(returned and stepped and porter.stack.is_empty() and porter.takes_output,
            "搬運工抱著送不出去的魚片:放回切魚台輸出堆(放回 %d)、走開後恢復收貨、回到待命" % ((porter.returned_total - ret0) if porter != null else 0))
    if cashier != null:
        cashier.assigned_counter = cnt
        cnt.cashier = cashier
    # 搬運工優先補最缺的:烤魚櫃台空、烤魚攤沒成品也沒原料,魚片櫃台還很多 -> 先送魚片去烤魚攤(玩家站在旁邊不插手)
    cnt.logic.stock = 40
    cnt.refresh_pile()
    grill.logic.input_count = 0
    grill.logic.output_count = 0
    grill.refresh_piles()
    gcnt.logic.stock = 0
    gcnt.refresh_pile()
    st.logic.output_count = 16
    st.refresh_piles()
    await _go(Vector3(0, 0, 7))
    var pg0 := _count("processed_grill")
    var grill_fed := await _wait_until(func() -> bool: return grill.logic.input_count >= 1 or _count("processed_grill") > pg0, 900)
    _check(grill_fed and cnt.logic.stock <= 40 and (porter != null and (porter.job.get("to", null) == grill or porter.delivered_total > 0)),
            "搬運工:烤魚櫃台空、烤魚攤沒料 -> 先把魚片送去烤魚攤,而不是補還有 40 份的魚片櫃台")
    # 手動跑第二條鏈:魚片 -> 烤魚 -> 烤魚櫃台 -> 自己收銀 $5(搬運工可能同時在搬,檢查放寬)
    if st.logic.output_count < 12:
        st.logic.output_count = 16
        st.refresh_piles()
    await _empty_hands()
    await _go(st.output_pad.global_position)
    var fillets := await _wait_until(func() -> bool: return _player.stack.item_id == "fillet" and _player.stack.count >= 3, 120)
    await _go(grill.input_pad.global_position)
    var fed := await _wait_until(func() -> bool: return grill.logic.input_count >= 1 or _count("processed_grill") >= 1, 120)
    var grilled := await _wait_until(func() -> bool: return _count("processed_grill") >= 2, 400)
    _check(fillets and fed and grilled, "烤魚攤:魚片進、烤出 %d 份" % _count("processed_grill"))
    await _empty_hands()
    await _go(grill.output_pad.global_position)
    var took := await _wait_until(func() -> bool: return (_player.stack.item_id == "grilled" and _player.stack.count >= 1) or gcnt.logic.stock >= 1, 240)
    await _go(gcnt.deposit_pad.global_position)
    var gstock := await _wait_until(func() -> bool: return gcnt.logic.stock >= 1, 240)
    await _go(gcnt.service_pad.global_position)
    var gsold := await _wait_until(func() -> bool: return _sales_of("grilled") >= 1, 600)
    var five := false
    for s in _sales:
        if str(s[0]) == "grilled" and int(s[2]) == 5 * int(s[1]):
            five = true
    _check(took and gstock and gsold and five, "烤魚上架、顧客以 $5 買走")
    # 表現層:飛行動畫事件、幽靈物件、音效
    _check(_count("moved") >= 30 and _count("moved_catch") >= 8 and _count("moved_to_station") >= 8 and _count("moved_from_station") >= 8
            and _count("moved_to_counter") >= 8 and _count("moved_sold") >= 3 and _count("moved_cash") >= 6 and _count("moved_pay") >= 20
            and _count("moved_trash") >= 2 and _count("moved_return") >= 3, "items_moved:抓魚 / 卸貨 / 取貨 / 上架 / 賣出 / 收錢 / 付錢 / 丟棄 / 放回都有發")
    _check(Fx.spawned_total >= 30 and Sfx.played_total >= 20 and Sfx.played.has("sale") and Sfx.played.has("unlock") and Sfx.played.has("hire")
            and Sfx.played.has("goal") and Sfx.played.has("catch") and Sfx.played.has("coin"), "幽靈物件飛過 %d 個、音效播了 %d 次" % [Fx.spawned_total, Sfx.played_total])
    _check(st.ring != null and st.ring.visible == st.logic.is_working(), "工作站進度環只在工作時顯示")
    _level.hud.menu_action("sound")
    var muted := not Sfx.enabled and not GameState.sound_on and not Sfx.play("goal")
    _level.hud.menu_action("sound")
    _check(muted and Sfx.enabled and GameState.sound_on, "選單:音效關掉就不播、再開回來")
    # 畫質:精細 = 即時陰影、全解析度、沒圓影;流暢 = 反過來
    var blobs := get_tree().get_nodes_in_group("blob_shadow")
    _check(_level.light != null and _level.light.shadow_enabled and is_equal_approx(get_viewport().scaling_3d_scale, 1.0) and blobs.size() >= 4
            and not _any_visible(blobs), "精細模式:陰影開、3D 全解析度、%d 個圓影都藏著" % blobs.size())
    _level.hud.menu_action("quality")
    await _step(2)
    _check(Settings.is_smooth() and not _level.light.shadow_enabled and is_equal_approx(get_viewport().scaling_3d_scale, 0.75) and _all_visible(blobs),
            "流暢模式:陰影關、3D 0.75 倍、圓影全亮")
    _level.hud.menu_action("quality")
    await _step(2)
    _check(not Settings.is_smooth() and _level.light.shadow_enabled and not _any_visible(blobs), "切回精細")
    _level.hud.menu_action("fps")
    await _step(2)
    var fps_on := Settings.show_fps and _level.hud.fps_visible()
    _level.hud.menu_action("fps")
    _check(fps_on and not Settings.show_fps and not _level.hud.fps_visible(), "選單:FPS 顯示開關")
    _check(_level.scenery != null and _level.scenery.mesh != null and _level.scenery.mesh.get_surface_count() <= 8
            and _level.stations[0].input_pile.visible_count() == mini(_level.stations[0].logic.input_count, 60), "布景合併成 %d 個 surface;堆疊用 MultiMesh 畫" % _level.scenery.mesh.get_surface_count())
    # 存檔 -> 重建 -> 還原
    var saved := _level.save_now()
    var snap := _level.snapshot()
    var cash_saved := _level.money_pad.cash
    var wallet_saved := GameState.wallet
    var earned_saved := GameState.cash_earned
    var hired_saved := GameState.hired_total()
    var pl_item := _player.stack.item_id
    var pl_count := _player.stack.count
    var st1_out := st.logic.output_count
    var grill_out := grill.logic.output_count
    var fstock := cnt.logic.stock
    var fp_rem := fisher_pad.logic.remaining
    _check(saved and SaveManager.has_save() and int(snap["money"]) == cash_saved and snap["stations"].has("grill")
            and snap["counters"].has("grill_counter") and snap["pads"].has("hire_fisher"), "存檔寫入、快照內容")
    _level.queue_free()
    await _step(3)
    GameState.reset()
    _check(GameState.hired_total() == 0 and GameState.wallet == 0, "reset 後狀態清空")
    await _spawn_level()
    await _step(2)
    var st2 := _level.station_at("station_1")
    var grill2 := _level.station_at("grill")
    var cnt2 := _level.counter_by_id("fillet_counter")
    _check(_level.loaded_from_save and GameState.cash_earned == earned_saved and GameState.hired_total() == hired_saved
            and GameState.upgrade_level("worker_speed") == 1 and GameState.wallet == wallet_saved and GameState.tutorial_step == 7
            and not _level.guide.in_tutorial, "重建關卡:讀回 GameState(含錢包 $%d、教學已完成)" % wallet_saved)
    _check(_level.stations.size() == 2 and grill2 != null and _level.counters.size() == 2 and _level.helpers.size() == hired_saved,
            "重建關卡:烤魚攤、烤魚櫃台、%d 個幫手都回來了" % hired_saved)
    _check(_level.money_pad.cash == cash_saved and st2 != null and st2.logic.output_count == st1_out and grill2.logic.output_count == grill_out
            and cnt2 != null and cnt2.logic.stock == fstock, "重建關卡:錢格、工作站堆、櫃台庫存還原")
    _check(_player.stack.item_id == pl_item and _player.stack.count == pl_count and _player.stack.capacity == 8, "重建關卡:玩家背上還原")
    var fp2: PricePad = _level.price_pads["hire_fisher"]
    var ug2: PricePad = _level.price_pads["unlock_grill"]
    _check(fp2.logic.buys == 1 and fp2.logic.remaining == fp_rem and fp2.logic.current_cost() == 18 and fp2.visible
            and not ug2.visible and ug2.logic.is_exhausted(), "重建關卡:價格牌進度還原(漁夫牌第二次 $18 剩 $%d、烤魚攤建地牌已用掉)" % fp_rem)
    var cashier2 := _find_helper("cashier")
    _check(cashier2 != null and cashier2.assigned_counter == cnt2 and is_equal_approx(st2.logic.speed_mult, 1.5), "重建關卡:收銀員指派、升級套回")
    # F9 新遊戲
    _level.clear_save_and_state()
    _check(not SaveManager.has_save() and GameState.hired_total() == 0 and GameState.wallet == 0, "新遊戲:刪存檔、清狀態")
    _level.queue_free()
    await _step(2)
