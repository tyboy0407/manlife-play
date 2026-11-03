extends Node3D
## 世界整合 headless 驗證(3D 物理):建關卡 -> 抓魚到滿 -> 切魚台卸貨 / 切 / 取魚片 -> 櫃台上架 -> 沒人收銀不賣、玩家站收銀格才賣 ->
## 錢格收進錢包(不佔背包)、帶錢走過價格牌不付、站著才分期付 -> 僱收銀員(接手收銀)-> 垃圾桶丟魚 -> 僱搬運工(自己把成品送到櫃台)->
## 升級牌(工人速度 / 堆疊上限,越買越貴)-> 再僱漁夫(可重複牌)-> 增建烤魚攤(第二條貨物鏈:魚片 -> 烤魚 -> 烤魚櫃台 $5)->
## 搬運工送不出去會放回來源、空的烤魚攤原料區優先補 -> 北極熊(吃掉漁夫、買回 ×1.5、村外武器店買武器、打到血條歸零、Lv3 一群三隻)->
## 擴建村莊 $1000(東門拆掉、第二個水區、第二組工作站與櫃台)-> 北極熊王(5 分鐘出場、吃魚回血變大、打死)->
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
    EventBus.trap_triggered.connect(func(_t: Node3D, _b: Node3D) -> void: _bump("trap_triggered"))
    EventBus.bait_eaten.connect(func(_t: Node3D, _b: Node3D) -> void: _bump("bait_eaten"))
    EventBus.conveyor_built.connect(func(_c: Node3D) -> void: _bump("conveyor_built"))
    EventBus.items_moved.connect(func(kind: String, _i: String, _f: Vector3, _t: Vector3, n: int) -> void:
        _bump("moved", n)
        _bump("moved_" + kind, n))
    EventBus.tutorial_step_done.connect(func(_s: int) -> void: _bump("tut_step"))
    EventBus.tutorial_finished.connect(func() -> void: _bump("tut_done"))
    EventBus.bear_appeared.connect(func(_b: Node3D) -> void: _bump("bear_appeared"))
    EventBus.bear_biting.connect(func(_h: Node3D) -> void: _bump("bear_biting"))
    EventBus.bear_defeated.connect(func(_b: Node3D, _by: Node3D) -> void: _bump("bear_defeated"))
    EventBus.bear_hit.connect(func(_b: Node3D, _d: float, _hp: float) -> void: _bump("bear_hit"))
    EventBus.fish_eaten.connect(func(_b: Node3D) -> void: _bump("fish_eaten"))
    EventBus.bear_fed.connect(func(_b: Node3D) -> void: _bump("bear_fed"))
    EventBus.bear_left.connect(func(reason: String) -> void: _bump("bear_left_" + reason))
    EventBus.helper_eaten.connect(func(role: String, _h: Node3D) -> void: _bump("eaten_" + role))
    EventBus.tower_built.connect(func(_t: Node3D) -> void: _bump("tower_built"))
    EventBus.tower_shot.connect(func(_t: Node3D, _b: Node3D) -> void: _bump("tower_shot"))
    EventBus.tower_damaged.connect(func(_t: Node3D, _hp: float) -> void: _bump("tower_damaged"))
    EventBus.tower_destroyed.connect(func(_t: Node3D, _b: Node3D) -> void: _bump("tower_destroyed"))
    EventBus.loot_dropped.connect(func(_k: String, _p: Vector3) -> void: _bump("loot_dropped"))
    EventBus.loot_collected.connect(func(_k: String, _n: int) -> void: _bump("loot_collected"))
    EventBus.shop_upgraded.connect(func(_l: int) -> void: _bump("shop_upgraded"))
    EventBus.tower_upgraded.connect(func(_t: Node3D) -> void: _bump("tower_upgraded"))
    EventBus.station_destroyed.connect(func(_s: Node3D, _b: Node3D) -> void: _bump("station_destroyed"))
    EventBus.station_repaired.connect(func(_s: Node3D) -> void: _bump("station_repaired"))
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


## 玩家背上有幾個 item
func _carried(item: String) -> int:
    return _player.stack.count if _player != null and _player.stack.item_id == item else 0


## 第 from 筆之後第一筆賣 item 的紀錄 [item, n, cash];沒有回空陣列
func _sale_after(from: int, item: String) -> Array:
    for i in range(from, _sales.size()):
        if str(_sales[i][0]) == item:
            return _sales[i]
    return []


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
    var cur := pad.logic.currency
    if pad.logic.is_cash() and GameState.wallet < need:
        await _go(_level.money_pad.global_position)
        await _wait_until(func() -> bool: return GameState.wallet >= need or _level.money_pad.cash == 0, 240)
    await _go(pad.global_position)
    await _wait_until(func() -> bool: return pad.logic.buys > buys or pad.logic.is_exhausted() or GameState.resource(cur) == 0, 480)
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
    _level.bears.enabled = false   # 北極熊只在測試指定的時候出現(不然 45 秒後會自己來吃幫手)


## 追著熊跑並打它(玩家帶武器靠近會自動攻擊;熊會動,每幀更新目標)直到牠血條歸零逃走 / 消失或超時
func _chase_bear(bear: Bear, max_frames: int) -> void:
    _moving = true
    for i in max_frames:
        if bear == null or not is_instance_valid(bear) or bear.state == "fleeing":
            break
        _target = bear.global_position
        await get_tree().physics_frame
    _moving = false
    await _step(2)


## 追一群熊:每幀朝最近一隻還沒逃的走,全逃了或超時就停
func _chase_pack(bs: BearSpawner, max_frames: int) -> void:
    _moving = true
    for i in max_frames:
        var next: Bear = null
        var best := INF
        for b in bs.bears:
            if is_instance_valid(b) and b.state != "fleeing" and b.planar_distance_to(_player.global_position) < best:
                best = b.planar_distance_to(_player.global_position)
                next = b
        if next == null:
            break
        _target = next.global_position
        await get_tree().physics_frame
    _moving = false
    await _step(2)


## 從村裡穿過西邊缺口走到村外(直線會撞牆,所以先到缺口)
func _go_outside() -> void:
    await _go(Vector3(-11.0, 0, 2.5))
    await _go(Vector3(-14.5, 0, 2.5))


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
            and _level.price_pads.size() == 87 and not _level.loaded_from_save, "關卡建好:玩家、水、切魚台、魚片櫃台、錢格、垃圾桶、八十六塊價格牌 + 切魚台的修復牌、沒有存檔")
    _check(_level.traps.size() == 8 and _level.baits.size() == 4 and _level.conveyors.is_empty() and (_level.price_pads["trap_1"] as PricePad).visible
            and (_level.price_pads["bait_1"] as PricePad).visible and not (_level.price_pads["trap_3"] as PricePad).visible
            and not (_level.price_pads["bait_2"] as PricePad).visible and (_level.price_pads["belt_station_1"] as PricePad).visible
            and not (_level.price_pads["belt_station_2"] as PricePad).visible and not (_level.price_pads["belt_grill"] as PricePad).visible
            and (_level.price_pads["upgrade_porter_cap"] as PricePad).visible and not _level.trap_by_id("trap_1").is_armed() and not _level.bait_by_id("bait_1").is_set()
            and Harbor.trap_area("trap_2") == 0 and Harbor.trap_area("trap_3") == 1 and Harbor.bait_area("bait_4") == 3,
            "捕熊夾 / 誘餌 / 傳送帶:主村的夾子與誘餌牌出現(擴建區的藏著)、只有切魚台 -> 魚片櫃台的傳送帶牌出現、搬運工容量牌在")
    var t5: Tower = _level.tower_by_id("tower_5")
    var t6: Tower = _level.tower_by_id("tower_6")
    _check(_level.towers.size() == 24 and _level.tower_by_id("tower_4") != null and _level.towers[0].state == "none" and not _level.towers[0]._built.visible
            and not _level.towers[0]._rubble.visible and (_level.price_pads["tower_1"] as PricePad).visible and _level.alive_towers().is_empty()
            and t5 != null and t6 != null and t5.position == Vector3(-3.0, 0, -2.9) and t6.position == Vector3(3.0, 0, -2.9)
            and (_level.price_pads["tower_5"] as PricePad).visible and _level.tower_pad_for("tower_6").position == t6.position
            and not (_level.price_pads["tooth_tower_5"] as PricePad).visible
            and not (_level.price_pads["tower_7"] as PricePad).visible and not (_level.price_pads["tower_13"] as PricePad).visible
            and not (_level.price_pads["expand_village_2"] as PricePad).visible and _level.tower_by_id("tower_18").position.x > 45.0
            and not (_level.price_pads["tower_19"] as PricePad).visible and not (_level.price_pads["expand_village_3"] as PricePad).visible
            and _level.tower_by_id("tower_24").position.x > 60.0
            and Harbor.tower_area("tower_6") == 0 and Harbor.tower_area("tower_7") == 1 and Harbor.tower_area("tower_13") == 2 and Harbor.tower_area("tower_19") == 3,
            "六座守衛塔待建:只有地基牌(中央兩座在 x ±3 水邊);擴建區的十八座塔牌與第二 / 三次擴建牌先藏著")
    _check(not _level.is_expanded() and _level.east_gate != null and _level.east_walls.size() == 5 and _level.fish_areas.size() == 1,
            "東牆還在(三段牆 + 兩段柵欄)、只有一個水區(還沒擴建)")
    _check(_level.bears != null and not _level.bears.has_bear() and _level.shopkeeper != null and _level.price_pads.has("weapon")
            and (_level.price_pads["weapon"] as PricePad).global_position.x < -13.0, "北極熊系統待命、村外有武器店老闆與武器牌")
    _check(_level.camera != null and _level.camera.current and _level.hud != null and _player.is_in_group("player")
            and _player.can_serve and _player.can_use_trash and _player.collects_cash and GameState.wallet == 0, "相機與 HUD、玩家分組與旗標、錢包 0")
    var pads := get_tree().get_nodes_in_group("pad").size()
    _check(pads == 93, "格子數:輸入 / 輸出 / 上架 / 收銀 / 錢 / 垃圾桶 / 八十六塊價格牌 / 修復牌(%d)" % pads)
    var tp0: PricePad = _level.price_pads.get("tooth_tower_1", null)
    var su0: PricePad = _level.price_pads.get("shop_upgrade", null)
    _check(tp0 != null and not tp0.visible and not tp0.logic.is_exhausted() and su0 != null and su0.visible and su0.logic.currency == "pelt"
            and su0.global_position.x < -13.0 and _level.loot.is_empty() and GameState.pelts == 0 and GameState.teeth == 0,
            "熊王牙牌藏著(塔沒蓋)、武器店升級牌在院子裡、沒有掉落物")
    var rp0: PricePad = _level.price_pads.get("repair_station_1", null)
    _check(rp0 != null and not rp0.visible and rp0.logic.is_exhausted() and rp0.global_position.distance_to(_level.stations[0].global_position) < 0.1
            and rp0.logic.effect.get("type", "") == "repair" and _level.repair_pad_for("station_1") == rp0, "切魚台完好:修復牌藏在桌子位置")
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
    _check(_player.model != null and _player.model.current() == "walk" and _player.body_mesh == null, "玩家用人物模型,走路時播 walk")
    _check(js.handle_event(lift) and not js.active and MoveInput.touch_dir == Vector2.ZERO, "放開搖桿:歸零")
    await _step(12)
    _check(_player.model != null and _player.model.current() == "idle" and _player.stack_visual.position.y > _player.model.height,
            "停下來播 idle;背上的堆疊在頭頂上方")
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
    var f0: Fish = _level.fish_area.fish[0]
    _check(f0.has_model() and f0.anim_playing(), "水裡的魚用模型、游泳動畫在播")
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
    _check(st.logic.is_working() and st.worker_model != null and st.worker_model.current() == "interact-right",
            "工人模型:處理中播 interact-right(%s)" % (st.worker_model.current() if st.worker_model != null else "無模型"))
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
    var cust0: Customer = cnt.customers[0] if cnt.customers.size() > 0 else null
    _check(cust0 != null and cust0.model != null and cust0.model.current() in ["idle", "walk"],
            "顧客用人物模型(%s)" % (cust0.model.current() if cust0 != null and cust0.model != null else "無"))
    _check(cust0 != null and cust0.want >= 1 and cust0.want <= 5 and cust0._bubble.text.ends_with(str(cust0.want)),
            "顧客要 %d 件(1 ~ 5),泡泡顯示數量" % (cust0.want if cust0 != null else 0))
    await _step(90)
    _check(waiting and _count("sale") == 0 and not cnt.has_server(), "有顧客在等,但沒人收銀就不賣")
    await _go(cnt.service_pad.global_position)
    var sold := await _wait_until(func() -> bool: return _count("sale") >= 2 and _level.money_pad.cash >= 6, 400)
    _check(sold and cnt.has_server(), "玩家站收銀格:賣出 %d 筆、錢格 $%d(顧客一次要 1 ~ 5 件,幾筆不一定)" % [_count("sale"), _level.money_pad.cash])
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
    if GameState.wallet < 10:
        _check(GameState.tutorial_step == 6 and str(g.current.get("text", "")) == "TUT_earn" and str(g.current.get("kind", "")) != "pad"
                and _level.hud.objective_text().contains(str(10 - GameState.wallet)),
                "教學第 7 步:錢包 $%d 不夠買 $10 的牌,箭頭回工作循環、文字說還差 $%d" % [GameState.wallet, 10 - GameState.wallet])
        _level.money_pad.add_cash(10)
        await _go(_level.money_pad.global_position)
        await _wait_until(func() -> bool: return GameState.wallet >= 10, 120)
    await _wait_until(func() -> bool: return str(g.current.get("kind", "")) == "pad", 40)   # Guide 每 0.1 秒才重算
    _check(GameState.tutorial_step == 6 and str(g.current.get("kind", "")) == "pad" and str(g.current.get("target", "")) == "hire_fisher"
            and g.target_pos.distance_to((_level.price_pads["hire_fisher"] as PricePad).global_position) < 0.1, "教學第 7 步:錢夠了指最便宜的牌(僱漁夫)(錢包 $%d、步 %d、提示 %s)" % [GameState.wallet, GameState.tutorial_step, str(g.current)])
    # 帶著錢直直走過擴充背包牌:沒停下來就不付
    var cap1: PricePad = _level.price_pads["capacity_1"]
    await _wait_until(func() -> bool: return _level.money_pad.cash == 0, 180)   # 顧客一次買好幾件,錢格可能還有錢;收光再記錢包
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
    # 搬運工容量升級:現有的搬運工馬上 +4
    _level.money_pad.add_cash(100)
    var pcp: PricePad = _level.price_pads["upgrade_porter_cap"]
    await _pay_pad(pcp)
    await _step(2)
    _check(GameState.upgrade_level("porter_cap") == 1 and porter != null and porter.stack.capacity == 12 and pcp.visible and pcp.logic.remaining == 160
            and _player.stack.capacity == 8, "搬運工容量 Lv1:8 -> 12、下一次 $160(玩家背包不變)")
    # 傳送帶:切魚台輸出格 -> 魚片櫃台上架格,$150;成品自己上帶、每秒一件送到櫃台
    _level.money_pad.add_cash(170)
    var bp1: PricePad = _level.price_pads["belt_station_1"]
    await _go(Vector3(-3.8, 0, 4.0))
    var belt_bought := await _pay_pad(bp1)
    await _step(2)
    var belt := _level.conveyor_by_id("belt_station_1")
    _check(belt_bought and belt != null and not bp1.visible and _level.conveyors.size() == 1 and _count("conveyor_built") == 1
            and belt.station == st and belt.counter == cnt and belt.length > 5.0 and belt.logic.capacity() >= 6,
            "買傳送帶 $150:架在切魚台輸出格到魚片櫃台之間(長 %.1f)" % (belt.length if belt != null else 0.0))
    if porter != null:
        porter.takes_output = false   # 搬運工先別搶這堆,看帶子自己搬
    st.logic.output_count = 6
    st.refresh_piles()
    await _go(Vector3(-3.8, 0, 6.5))
    var belt_moved := await _wait_until(func() -> bool: return belt.logic.moved_total >= 3, 900)
    _check(belt_moved and belt.logic.moved_total >= 3, "傳送帶把魚片送到櫃台(上架 %d 件)" % belt.logic.moved_total)
    if porter != null:
        porter.takes_output = true
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
    # 搬運工優先補最缺的:烤魚櫃台空、烤魚攤沒成品也沒原料,魚片櫃台還很多 -> 先送魚片去烤魚攤(玩家站在旁邊不插手;傳送帶先停,免得它把魚片櫃台補滿)
    var belt1 := _level.conveyor_by_id("belt_station_1")
    if belt1 != null:
        belt1.set_physics_process(false)
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
    if belt1 != null:
        belt1.set_physics_process(true)
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
    await _bear_section(g, fisher_pad)
    await _tower_section()
    await _trap_section()
    await _expand_section()
    await _king_section()
    await _tower_strong_section()
    # 表現層:飛行動畫事件、幽靈物件、音效
    _check(_count("moved") >= 30 and _count("moved_catch") >= 8 and _count("moved_to_station") >= 8 and _count("moved_from_station") >= 8
            and _count("moved_to_counter") >= 8 and _count("moved_sold") >= 3 and _count("moved_cash") >= 6 and _count("moved_pay") >= 20
            and _count("moved_trash") >= 2 and _count("moved_return") >= 3, "items_moved:抓魚 / 卸貨 / 取貨 / 上架 / 賣出 / 收錢 / 付錢 / 丟棄 / 放回都有發")
    _check(Fx.spawned_total >= 30 and Sfx.played_total >= 20 and Sfx.played.has("sale") and Sfx.played.has("unlock") and Sfx.played.has("hire")
            and Sfx.played.has("goal") and Sfx.played.has("catch") and Sfx.played.has("coin") and Sfx.played.has("roar") and Sfx.played.has("chomp"),
            "幽靈物件飛過 %d 個、音效播了 %d 次(含熊吼 / 咬)" % [Fx.spawned_total, Sfx.played_total])
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
    _check(_level.scenery != null and _level.scenery.mesh != null and _level.scenery.mesh.get_surface_count() <= 10
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
    var belt_saved_items := _level.conveyor_by_id("belt_station_1").logic.count()   # 讀檔後帶子馬上會動,堆 + 帶 + 櫃台的總數才守恆
    var grill_out := grill.logic.output_count
    var fstock := cnt.logic.stock
    var fp_rem := fisher_pad.logic.remaining
    var bear_cd := _level.bears.cooldown
    var king_next_saved := _level.bears.king_next_sec
    var play_time_saved := GameState.play_time
    var weapon_saved := GameState.weapon_level
    var lost_saved := GameState.helpers_lost
    var pelts_saved := GameState.pelts
    var loot_saved := _level.loot.size()
    var tower_saved: Tower = _level.tower_by_id("tower_1")
    var tower_hp_saved := tower_saved.hp
    var tower_alive_saved := tower_saved.is_alive()
    _check(saved and SaveManager.has_save() and int(snap["money"]) == cash_saved and snap["stations"].has("grill")
            and snap["counters"].has("grill_counter") and snap["pads"].has("hire_fisher") and is_equal_approx(float(snap["bear"]["cooldown"]), bear_cd)
            and snap["towers"].has("tower_1") and str(snap["towers"]["tower_1"]["state"]) == "alive",
            "存檔寫入、快照內容(含北極熊冷卻 %.0f 秒)" % bear_cd)
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
    var tailor2 := _level.station_at("tailor")
    _check(_level.stations.size() == 11 and grill2 != null and _level.counters.size() == 7 and _level.helpers.size() == hired_saved
            and _level.expansion_level() == 3 and _level.fish_areas.size() == 4 and _level.east_gate == null and _level.station_at("grill_2") != null
            and _level.station_at("grill_5") != null and _level.station_at("grill_7") != null and tailor2 != null and tailor2.logic.input_per == 5
            and _level.counter_by_id("sweater_counter") != null
            and _level.annex_east_walls[0].is_empty() and _level.annex_east_walls[1].is_empty() and not _level.annex_east_walls[2].is_empty()
            and (_level.price_pads["tower_13"] as PricePad).visible and (_level.price_pads["tower_24"] as PricePad).visible
            and not (_level.price_pads["expand_village_2"] as PricePad).visible and not (_level.price_pads["expand_village_3"] as PricePad).visible,
            "重建關卡:烤魚攤、烤魚櫃台、%d 個幫手、三塊擴建區(四個水區、十一座工作站含服飾店、七座櫃台、每塊的塔牌)都回來了" % hired_saved)
    var belt2 := _level.conveyor_by_id("belt_station_1")
    var fillets_now := st2.logic.output_count + cnt2.logic.stock + (belt2.logic.count() if belt2 != null else 0)
    _check(_level.money_pad.cash == cash_saved and st2 != null and grill2.logic.output_count == grill_out and cnt2 != null
            and fillets_now == st1_out + fstock + belt_saved_items and belt2 != null and belt2.logic.count() <= belt2.logic.capacity(),
            "重建關卡:錢格、工作站堆、櫃台庫存還原(切魚台堆 + 傳送帶 + 魚片櫃台 %d = 存檔時 %d)" % [fillets_now, st1_out + fstock + belt_saved_items])
    _check(_player.stack.item_id == pl_item and _player.stack.count == pl_count and _player.stack.capacity == 8, "重建關卡:玩家背上還原")
    var fp2: PricePad = _level.price_pads["hire_fisher"]
    var ug2: PricePad = _level.price_pads["unlock_grill"]
    _check(fp2.logic.buys == 1 and fp2.logic.remaining == fp_rem and fp2.logic.current_cost() == 18 and fp2.visible
            and not ug2.visible and ug2.logic.is_exhausted(), "重建關卡:價格牌進度還原(漁夫牌第二次 $18 剩 $%d、烤魚攤建地牌已用掉)" % fp_rem)
    var cashier2 := _find_helper("cashier")
    _check(cashier2 != null and cashier2.assigned_counter == cnt2 and is_equal_approx(st2.logic.speed_mult, 1.5), "重建關卡:收銀員指派、升級套回")
    _check(GameState.weapon_level == weapon_saved and GameState.helpers_lost == lost_saved and _player.weapon_prop != null
            and _find_helper("fisher") != null and absf(_level.bears.cooldown - bear_cd) < 0.5 and fp2.logic.lost == 0
            and absf(GameState.play_time - play_time_saved) < 0.5 and is_equal_approx(_level.bears.king_next_sec, king_next_saved),
            "重建關卡:武器 Lv%d 掛回腰間、買回的漁夫還在、北極熊冷卻 / 遊戲時間 / 王的下次時間還原" % weapon_saved)
    var tw2: Tower = _level.tower_by_id("tower_1")
    var wp3: PricePad = _level.price_pads["weapon"]
    _check(tw2 != null and tw2.tier == 1 and tw2.is_strong() and is_equal_approx(tw2.hp_max, 2000.0) and GameState.shop_level == 1
            and GameState.weapon_level == 4 and GameState.pelts == pelts_saved and GameState.teeth == 2 and _level.loot.size() == loot_saved
            and wp3.logic.max_buys == 4 and wp3.logic.is_exhausted() and not wp3.visible and _level.shop_sign.text.contains("1")
            and not (_level.price_pads["tooth_tower_1"] as PricePad).visible and not (_level.price_pads["tooth_tower_2"] as PricePad).visible,
            "重建關卡:強力守衛塔、武器店 Lv1(武器牌 4 級買滿)、毛皮 %d、地上 %d 個掉落物還原" % [pelts_saved, loot_saved])
    _check(_level.conveyors.size() == 1 and _level.conveyor_by_id("belt_station_1") != null and not (_level.price_pads["belt_station_1"] as PricePad).visible
            and (_level.price_pads["belt_grill"] as PricePad).visible and not _level.trap_by_id("trap_1").is_armed() and (_level.price_pads["trap_1"] as PricePad).visible
            and not _level.bait_by_id("bait_1").is_set() and (_level.price_pads["bait_1"] as PricePad).visible and GameState.upgrade_level("porter_cap") == 1
            and (_level.price_pads["upgrade_porter_cap"] as PricePad).logic.remaining == 160,
            "重建關卡:傳送帶蓋回來(牌藏著、烤魚攤的傳送帶牌開著)、用掉的捕熊夾 / 誘餌牌開著、搬運工容量 Lv1(帶 %d、帶牌 %s / %s、夾 %s 牌 %s、餌 %s 牌 %s、容量 Lv%d 剩 %d)"
            % [_level.conveyors.size(), str((_level.price_pads["belt_station_1"] as PricePad).visible), str((_level.price_pads["belt_grill"] as PricePad).visible),
            str(_level.trap_by_id("trap_1").is_armed()), str((_level.price_pads["trap_1"] as PricePad).visible), str(_level.bait_by_id("bait_1").is_set()),
            str((_level.price_pads["bait_1"] as PricePad).visible), GameState.upgrade_level("porter_cap"), (_level.price_pads["upgrade_porter_cap"] as PricePad).logic.remaining])
    _check(tower_alive_saved and tw2 != null and tw2.is_alive() and is_equal_approx(tw2.hp, tower_hp_saved) and tw2._built.visible
            and not (_level.price_pads["tower_1"] as PricePad).visible and _level.tower_by_id("tower_2").state == "none"
            and fp2.logic.max_buys == 9 and (_level.price_pads["hire_porter"] as PricePad).logic.max_buys == 14,
            "重建關卡:守衛塔 1 還在(血 %.0f)、沒蓋的還是地基、三次擴建後的僱用名額還原" % tower_hp_saved)
    # F9 新遊戲
    _level.clear_save_and_state()
    _check(GameState.weapon_level == 0 and GameState.helpers_lost == 0 and GameState.pelts == 0 and GameState.teeth == 0 and GameState.shop_level == 0,
            "新遊戲:武器、被吃數、毛皮 / 熊王牙 / 武器店等級歸零")
    _check(not SaveManager.has_save() and GameState.hired_total() == 0 and GameState.wallet == 0, "新遊戲:刪存檔、清狀態")
    _level.queue_free()
    await _step(2)


## --- 北極熊 ---
## 強制出現、指定盯上漁夫 -> 漁夫嚇呆 -> 咬 biteSec 秒吃掉(幫手少一個、僱用數 -1、牌子次數不退)-> 熊留著找下一個 ->
## 玩家穿過西邊缺口到村外武器店買 Lv1 -> 衝向熊把牠趕跑(冷卻 60 ~ 90 秒)-> 買到 Lv3 -> 熊再來時看到玩家就逃
func _bear_section(g: Guide, fisher_pad: PricePad) -> void:
    var bs: BearSpawner = _level.bears
    var fisher := _find_helper("fisher")
    var helpers_before := _level.helpers.size()
    var hired_fisher := GameState.hired_count("fisher")
    var fisher_buys := fisher_pad.logic.buys
    await _empty_hands()
    await _go(Vector3(0, 0, 7))
    if fisher == null:
        _fails += 1
        print("  FAIL 沒有漁夫可以給熊吃,北極熊段落略過")
        return
    bs.enabled = true
    var bear := bs.spawn(fisher)
    await _step(8)
    _check(bear != null and bs.has_bear() and bs.first_bear() == bear and bear.state == "hunting" and bear.target == fisher and GameState.weapon_level == 0
            and _count("bear_appeared") == 1 and bs.visits == 1, "北極熊從邊緣進來、盯上漁夫")
    _check(absf(bear.hp_max - bs.logic.hp(GameState.play_time)) < 1.0 and bear.hp_max > 30.0 and bear.hp_max < 90.0 and bear.hp == bear.hp_max
            and bear.hp_ratio() == 1.0 and GameState.play_time > 60.0, "熊的血量照遊戲時間算(%.0f 秒 -> %.0f 血)、血條滿" % [GameState.play_time, bear.hp_max])
    _check(bs.logic.interval(GameState.play_time).x >= 15.0 and bs.logic.interval(GameState.play_time).x <= 35.0, "出沒間隔照遊戲時間縮短")
    var bear_hint := str(g.current.get("text", ""))
    _check(bear_hint == "HINT_BEAR_EARN" or bear_hint == "HINT_BEAR_MONEY" or (bear_hint == "HINT_BEAR_WEAPON" and GameState.wallet >= 35),
            "提示:沒武器、錢不夠($%d)-> 先賺錢 / 收錢(%s)" % [GameState.wallet, bear_hint])
    var panicked := await _wait_until(func() -> bool: return fisher.panicked, 900)
    await _step(10)
    _check(panicked and fisher.velocity.length() < 0.2 and fisher.model != null and fisher.model.current() == "emote-no",
            "熊靠近:漁夫嚇呆不動、一直搖頭")
    var biting := await _wait_until(func() -> bool: return bear.state == "biting", 300)
    var bite_t0 := Time.get_ticks_msec()
    var eaten := await _wait_until(func() -> bool: return not is_instance_valid(fisher) or fisher.eaten, 600)
    var bite_sec := float(Time.get_ticks_msec() - bite_t0) / 1000.0
    _check(biting and _count("bear_biting") == 1 and eaten and bite_sec >= 3.0, "咬了 %.1f 秒才吃掉(設定 %.0f 秒)" % [bite_sec, bs.logic.bite_sec()])
    _check(_level.helpers.size() == helpers_before - 1 and GameState.hired_count("fisher") == hired_fisher - 1 and GameState.helpers_lost == 1
            and _count("eaten_fisher") == 1 and _find_helper("fisher") == null, "漁夫被吃掉:幫手少一個、僱用數 -1")
    _check(fisher_pad.visible and fisher_pad.logic.buys == fisher_buys - 1 and fisher_pad.logic.lost == 1 and fisher_pad.logic.is_rebuy()
            and fisher_pad.logic.remaining == 15 and fisher_pad.label.text.contains("×1.5"),
            "漁夫牌退一個名額:買回價 $10 × 1.5 = $%d、牌上標買回" % fisher_pad.logic.remaining)
    await _step(5)
    _check(is_instance_valid(bear) and bs.has_bear() and bear.state == "hunting" and bear.target != null and bear.target != fisher,
            "熊不走,盯上下一個幫手(%s)" % (bear.target.role if bear.target != null else "無"))
    # 買武器(先把熊定住,不然買武器的路上收銀員也會被吃掉)
    bear.set_physics_process(false)
    var wp: PricePad = _level.price_pads["weapon"]
    _level.money_pad.add_cash(60)
    await _go(_level.money_pad.global_position)
    await _wait_until(func() -> bool: return GameState.wallet >= 35, 240)
    await _step(8)
    _check(str(g.current.get("kind", "")) == "pad" and str(g.current.get("target", "")) == "weapon" and str(g.current.get("text", "")) == "HINT_BEAR_WEAPON"
            and g.target_pos.distance_to(wp.global_position) < 0.1, "錢夠 $35 了:提示指村外武器店的牌")
    await _go_outside()
    var bought := await _pay_pad(wp)
    await _step(2)
    _check(bought and GameState.weapon_level == 1 and _player.weapon_prop != null and wp.visible and wp.logic.remaining == 60 and wp.logic.buys == 1,
            "村外武器店:買到武器 Lv1、腰間掛著武器、下一級 $60")
    _check(_level.shopkeeper != null and _level.shopkeeper.get_child_count() >= 1 and _player.global_position.x < -13.0, "武器店老闆站在店前,玩家在村外")
    await _step(8)   # Guide 每 0.1 秒才重算
    _check(str(g.current.get("kind", "")) == "bear" and g.target_pos.distance_to(bear.global_position) < 0.5, "提示:有武器 -> 指向北極熊")
    # 趕熊:走回村裡追著熊跑,靠到 1.8 內牠就逃(熊先挪到缺口附近,免得它在村子另一頭先把收銀員吃了)
    await _go(Vector3(-14.5, 0, 2.5))
    await _go(Vector3(-11.0, 0, 2.5))
    bear.global_position = Vector3(-6.0, 0, 2.5)
    bear.set_physics_process(true)
    await _chase_bear(bear, 900)
    var hits_needed := int(ceil(bear.hp_max / 10.0)) if is_instance_valid(bear) else 0
    _check(is_instance_valid(bear) and bear.state == "fleeing" and _count("bear_defeated") == 1 and bear.hits_taken == hits_needed
            and _player.hits_total == hits_needed and _count("bear_hit") == hits_needed and bear.hp == 0.0
            and _player.model != null and _player.model.current() == "attack-melee-right",
            "Lv1 每下 10:打了 %d 下血條歸零才逃、玩家揮武器" % (bear.hits_taken if is_instance_valid(bear) else -1))
    var gone := await _wait_until(func() -> bool: return not bs.has_bear(), 600)
    _check(gone and _count("bear_left_fled") == 1 and bs.cooldown >= 33.0 and bs.cooldown <= 55.0 and _level.helpers.size() == helpers_before - 1,
            "熊逃到地圖邊緣消失,下一群 %.0f 秒後再來,沒有再損失幫手(gone %s、fled %d、幫手 %d / %d)" % [bs.cooldown, str(gone), _count("bear_left_fled"), _level.helpers.size(), helpers_before - 1])
    # 打跑的熊掉一張毛皮(掉在被打倒的地方,玩家就在旁邊,可能當場就撿到)
    var dropped := _count("loot_dropped")
    _check(dropped >= 1 and dropped <= 2 and GameState.pelts + _level.loot.size() == dropped, "打跑的熊掉下 1 ~ 2 張毛皮(%d)" % dropped)
    for l in _level.loot.duplicate():
        if is_instance_valid(l):
            await _go(l.global_position)
            await _step(3)
    _check(GameState.pelts == dropped and _level.loot.is_empty() and _count("loot_collected") == dropped, "走過去撿起毛皮(資源 +%d,不佔背包)" % dropped)
    await _step(8)   # Guide 每 0.1 秒才重算
    _check(str(g.current.get("kind", "")) != "bear", "熊走了:提示回到平常")
    # 買回漁夫(1.5 倍)
    _level.money_pad.add_cash(40)
    var rebought := await _pay_pad(fisher_pad)
    await _step(3)
    _check(rebought and _find_helper("fisher") != null and GameState.hired_count("fisher") == hired_fisher and _level.helpers.size() == helpers_before
            and fisher_pad.logic.buys == fisher_buys and fisher_pad.logic.lost == 0 and not fisher_pad.logic.is_rebuy() and fisher_pad.logic.remaining == 18,
            "花 $15 買回漁夫:幫手回來、名額補回、下一次回到正常的 $18(買成 %s、漁夫 %d / %d、幫手 %d / %d、buys %d / %d、lost %d、剩 %d)"
            % [str(rebought), GameState.hired_count("fisher"), hired_fisher, _level.helpers.size(), helpers_before, fisher_pad.logic.buys, fisher_buys, fisher_pad.logic.lost, fisher_pad.logic.remaining])
    # 升到 Lv3:看到玩家就逃
    _level.money_pad.add_cash(200)
    await _go(_level.money_pad.global_position)
    await _wait_until(func() -> bool: return GameState.wallet >= 161, 300)
    await _go_outside()
    var b2 := await _pay_pad(wp)
    await _go(Vector3(-16.0, 0, 2.5))
    var b3 := await _pay_pad(wp)
    _check(b2 and b3 and GameState.weapon_level == 3 and not wp.visible and wp.logic.is_exhausted() and _player.weapon_prop != null,
            "武器買到 Lv3(牌子用完消失)")
    await _go(Vector3(-14.5, 0, 2.5))
    await _go(Vector3(-11.0, 0, 2.5))
    await _go(Vector3(0.0, 0, 3.0))
    # 一群三隻:各盯不同的幫手;Lv3 看到玩家就逃
    var pack := bs.spawn_pack(3)
    await _step(8)
    var targets := {}
    for b in pack:
        if is_instance_valid(b) and b.target != null:
            targets[b.target.get_instance_id()] = true
    _check(pack.size() == 3 and bs.bear_count() == 3 and targets.size() == 3 and _count("bear_appeared") == 4
            and absf(pack[0].entry.z - pack[2].entry.z) > 4.0, "一群三隻從入口排開進來,各盯不同的幫手(%d 個目標)" % targets.size())
    _check(str(g.current.get("kind", "")) == "bear" and g.target_pos.distance_to(bs.nearest_bear(_player.global_position).global_position) < 0.5,
            "提示指最近的那隻熊")
    var hits0 := _player.hits_total
    await _chase_pack(bs, 1500)
    var all_fled := true   # 逃走中,或已經逃到邊緣被釋放
    var per_bear := 0
    var states := []
    for b in pack:
        if is_instance_valid(b):
            per_bear = int(ceil(b.hp_max / 35.0))
            states.append("%s/%d" % [b.state, b.hits_taken])
            if b.state != "fleeing":
                all_fled = false
        else:
            states.append("freed")
    if per_bear == 0:
        per_bear = int(ceil(bs.logic.hp(GameState.play_time) / 35.0))
    _check(all_fled and _count("bear_defeated") == 4 and _player.hits_total - hits0 == per_bear * 3,
            "Lv3 每下 35:三隻各打 %d 下都打跑(武器升級只加攻擊力;%s,玩家揮 %d 下,打跑 %d)" % [per_bear, str(states), _player.hits_total - hits0, _count("bear_defeated")])
    var gone2 := await _wait_until(func() -> bool: return not bs.has_bear(), 900)
    var iv := bs.logic.interval(GameState.play_time)
    _check(gone2 and _count("bear_left_fled") == 4 and bs.cooldown >= iv.x - 2.0 and bs.cooldown <= iv.y + 0.01
            and _level.helpers.size() == helpers_before, "三隻都逃光才重新倒數(%.0f 秒,此時間隔 %.0f ~ %.0f;gone %s、fled %d、幫手 %d / %d)" % [bs.cooldown, iv.x, iv.y, str(gone2), _count("bear_left_fled"), _level.helpers.size(), helpers_before])
    bs.enabled = false
    _check(_count("loot_dropped") >= 4 and _count("loot_dropped") <= 8, "三隻熊各掉 1 ~ 2 張毛皮(累計 %d 張)" % _count("loot_dropped"))
    # 毛皮升級武器店:湊 3 張站上升級牌 -> 武器店 Lv1、武器牌重新出現賣 Lv4($172)
    var su: PricePad = _level.price_pads["shop_upgrade"]
    var wp2: PricePad = _level.price_pads["weapon"]
    _check(su.visible and not su.logic.is_cash() and su.logic.remaining == 3 and su.label.text.contains(tr("COST_pelt") % 3)
            and _level.shop_sign != null and not wp2.visible and wp2.logic.is_exhausted(), "武器店旁有升級牌(收 3 張毛皮);武器牌買滿還是藏著")
    GameState.pelts = 3
    for l in _level.loot.duplicate():
        if is_instance_valid(l):
            l.collect(null)
    await _step(2)
    await _go_outside()
    var up := await _pay_pad(su)
    await _step(3)
    _check(up and GameState.shop_level == 1 and GameState.pelts == 0 and su.logic.remaining == 8 and su.logic.buys == 1 and su.visible
            and wp2.visible and not wp2.logic.is_exhausted() and wp2.logic.max_buys == 4 and wp2.logic.remaining == 172
            and _count("shop_upgraded") == 1 and _level.shop_sign.text.contains("1"),
            "3 張毛皮升級武器店 Lv1:下一級 8 張、武器牌重新出現賣 Lv4 $172、招牌顯示等級")
    GameState.add_wallet(172)
    wp2.logic.pay(100)
    wp2._update_label()
    await _go(Vector3(-16.0, 0, 2.5))
    var b4 := await _pay_pad(wp2)
    await _step(2)
    _check(b4 and GameState.weapon_level == 4 and not wp2.visible and wp2.logic.is_exhausted() and _player.weapon_prop != null
            and is_equal_approx(bs.logic.weapon_damage(GameState.weapon_level), 55.0), "買到 Lv4 武器(攻擊力 55、鎬子模型)、牌子又用完")
    await _go(Vector3(-14.5, 0, 2.5))
    await _go(Vector3(-11.0, 0, 2.5))
    await _go(Vector3(0, 0, 7))


## --- 守衛塔 ---
## 買 tower_1($200,牌就是地基)-> 塔蓋起來 -> 熊從西北入口進來:塔射箭、熊被射中改來拆塔、血條歸零逃走 ->
## 另一隻厚血的熊把只剩 10 血的塔咬塌 -> 牌子重現「修復」$200 -> 修好血回滿
func _tower_section() -> void:
    var bs: BearSpawner = _level.bears
    var pad: PricePad = _level.price_pads["tower_1"]
    var tower: Tower = _level.tower_by_id("tower_1")
    var tl: TowerLogic = tower.logic
    _check(tower != null and pad != null and tower.state == "none" and pad.visible and pad.logic.current_cost() == 200
            and pad.global_position.distance_to(tower.global_position) < 0.1 and _level.tower_pad_for("tower_1") == pad, "守衛塔牌 $200 就在塔的地基上")
    bs.enabled = false
    await _empty_hands()
    GameState.add_wallet(200)
    await _go(Vector3(-11.6, 0, 7.0))
    await _go(Vector3(-11.6, 0, -6.0))
    pad.logic.pay(80)   # 測試時間預算:$200 以每秒 30 要站 7 秒,先付 80
    pad._update_label()
    var bought := await _pay_pad(pad)
    await _step(3)
    _check(bought and tower.is_alive() and not pad.visible and pad.logic.is_exhausted() and is_equal_approx(tower.hp, tl.hp())
            and tower._built.visible and tower._hp_bar.visible and not tower._rubble.visible and _count("tower_built") == 1
            and GameState.is_unlocked("tower_1") and _level.alive_towers().size() == 1, "付清 $200:塔蓋好(血 %.0f)、牌消失" % tower.hp)
    # 玩家退到南邊不出手;熊放在西北入口(射程內):塔射箭,熊被射中改來拆塔,三箭就死(血先設 30)
    await _go(Vector3(-11.6, 0, -6.0))
    await _go(Vector3(-11.6, 0, 7.0))
    await _go(Vector3(0, 0, 9))
    bs.enabled = true
    bs.cooldown = 999.0
    var bear := bs.spawn()
    bear.entry = Vector3(-15.5, 0, -8.0)
    bear.global_position = bear.entry
    bear.hp_max = 30.0
    bear.hp = 30.0
    var hits0 := _player.hits_total
    var shot := await _wait_until(func() -> bool: return tower.shots_total >= 1, 120)
    var hit := await _wait_until(func() -> bool: return tower.hits_total >= 1, 120)
    await _step(2)
    _check(shot and hit and is_instance_valid(bear) and bear.hp < 30.0 and _count("tower_shot") >= 1 and tower.last_target == bear
            and bear.target == tower and bear.hits_taken >= 1, "塔射箭、射中熊(剩 %.0f 血);熊改來拆塔" % bear.hp)
    var fled := await _wait_until(func() -> bool: return not is_instance_valid(bear) or bear.state == "fleeing", 600)
    _check(fled and tower.hits_total >= 3 and _player.hits_total == hits0 and _count("bear_defeated") == 5 and tower.is_alive()
            and is_equal_approx(tower.damage_dealt, 30.0), "塔自己把熊射到血條歸零(射中 %d 箭,玩家沒出手)" % tower.hits_total)
    var gone := await _wait_until(func() -> bool: return not bs.has_bear(), 600)
    bs.cooldown = 999.0
    # 第二隻:血很厚、塔只剩 10 血 -> 咬一口塌掉
    tower.hp = 10.0
    tower._update_hp_bar()
    var bear2 := bs.spawn()
    bear2.entry = Vector3(-14.0, 0, -8.5)
    bear2.global_position = bear2.entry
    bear2.hp_max = 400.0
    bear2.hp = 400.0
    var broken := await _wait_until(func() -> bool: return tower.is_broken(), 600)
    await _step(2)
    _check(gone and broken and _count("tower_destroyed") == 1 and _count("tower_damaged") >= 1 and not tower._built.visible and tower._rubble.visible
            and not tower._hp_bar.visible and bear2.towers_broken == 1 and _level.alive_towers().is_empty(), "熊把塔咬塌:剩廢墟")
    _check(pad.visible and pad.logic.is_rebuy() and pad.logic.buys == 0 and pad.logic.lost == 1 and pad.logic.remaining == 100
            and pad.label.text.contains(tr("PAD_REPAIR")) and not pad.label.text.contains("×"), "牌子重現:修復 $200(不是 ×1.5 的買回)")
    bear2.defeat(_player)
    var gone2 := await _wait_until(func() -> bool: return not bs.has_bear(), 600)
    bs.cooldown = 999.0
    bs.enabled = false
    # 修好
    GameState.add_wallet(200)
    await _go(Vector3(-11.6, 0, 7.0))
    await _go(Vector3(-11.6, 0, -6.0))
    pad.logic.pay(80)
    pad._update_label()
    var repaired := await _pay_pad(pad)
    await _step(3)
    _check(gone2 and repaired and tower.is_alive() and is_equal_approx(tower.hp, tl.hp()) and not pad.visible and pad.logic.is_exhausted()
            and pad.logic.lost == 0 and _count("tower_built") == 2 and tower.times_built == 2 and tower.times_broken == 1 and tower._built.visible
            and not tower._rubble.visible, "花 $200 修好:塔回來、血回滿、牌消失")
    await _go(Vector3(-11.6, 0, -6.0))
    await _go(Vector3(-11.6, 0, 7.0))
    await _go(Vector3(0, 0, 7))


## --- 擴建村莊 ---
## 付 $1000(大額牌付得快)-> 東門拆掉、往東多一塊地:第二個水區有魚、第二座切魚台 + 烤魚攤、第二組櫃台有顧客來
## --- 捕熊夾 / 誘餌 ---
## 買捕熊夾 $40(夾子放好、牌子消失)-> 熊踩上去:扣 60、定住 3 秒、夾子用掉、牌子同價重現 -> 3 秒後恢復 ->
## 買誘餌 $30 -> 熊在 8 格內改去吃魚堆、咬 10 秒吃光:牌子重現、熊不算吃過東西
func _trap_section() -> void:
    var tp: PricePad = _level.price_pads["trap_1"]
    var trap := _level.trap_by_id("trap_1")
    _check(tp.visible and trap != null and not trap.is_armed() and tp.logic.current_cost() == 40
            and tp.global_position.distance_to(trap.global_position) < 0.1, "捕熊夾牌 $40 就在夾子的位置")
    GameState.add_wallet(40)
    await _go(Vector3(-11.6, 0, -3.0))
    var bought := await _pay_pad(tp)
    await _step(2)
    _check(bought and trap.is_armed() and not tp.visible and _count("purchased_trap_1") == 1, "買捕熊夾:夾子放好、牌子消失")
    await _go(Vector3(-7.5, 0, 0.5))   # 走開:玩家有武器,靠太近會自動打熊(也別站在搬運工容量牌 (-10, -1.5) 上)
    var bs: BearSpawner = _level.bears
    var bear := bs.spawn()
    bear.set_physics_process(false)
    bear.hp_max = 500.0
    bear.hp = 500.0
    bear.global_position = trap.global_position + Vector3(1.0, 0, 0)
    var tripped := await _wait_until(func() -> bool: return _count("trap_triggered") >= 1, 60)
    _check(tripped and not trap.is_armed() and bear.is_stunned() and bear.alive() and bear.hp <= 440.0 and bear.hits_taken >= 1
            and tp.visible and tp.logic.remaining == 40 and not tp.label.text.contains("買回") and trap.triggers_total == 1,
            "熊踩到夾子:扣 60(血 %.0f)、定住、夾子用掉、牌子同價 $40 重現" % bear.hp)
    bear.set_physics_process(true)
    var recovered := await _wait_until(func() -> bool: return not bear.is_stunned(), 300)
    _check(recovered and is_instance_valid(bear) and bear.alive() and bear.state == "hunting", "3 秒後熊恢復行動")
    # 誘餌
    bear.set_physics_process(false)
    var bp: PricePad = _level.price_pads["bait_1"]
    var bait := _level.bait_by_id("bait_1")
    GameState.add_wallet(30)
    var bought2 := await _pay_pad(bp)
    await _step(2)
    _check(bought2 and bait != null and bait.is_set() and not bp.visible and is_equal_approx(bait.lure_radius, 8.0), "買誘餌 $30:魚堆放好、牌子消失")
    await _go(Vector3(-7.5, 0, 0.5))   # 走開,免得站在魚堆旁邊順手打熊
    bear.hp_max = 3000.0
    bear.hp = 3000.0
    bear.global_position = bait.global_position + Vector3(5.0, 0, 2.5)
    bear.target = _find_helper("porter")
    bear.set_physics_process(true)
    var lured := await _wait_until(func() -> bool: return bear.target == bait, 60)
    var biting := await _wait_until(func() -> bool: return bear.state == "biting" and bear.target == bait, 300)
    _check(lured and biting, "熊在 8 格內被誘餌引走、走到魚堆開始吃(目標 %s、狀態 %s)" % [str(bear.target), bear.state if is_instance_valid(bear) else "freed"])
    var eaten := await _wait_until(func() -> bool: return not bait.is_set(), 900)
    await _step(2)
    _check(eaten and _count("bait_eaten") == 1 and bp.visible and bp.logic.remaining == 30 and is_instance_valid(bear) and bear.alive()
            and not (bear.target is Bait) and bear.eaten_total == 0 and bait.eaten_total == 1,
            "咬 10 秒吃光誘餌:牌子同價 $30 重現、熊不算吃過東西、改找下一個獵物")
    bear.set_physics_process(false)
    bear.queue_free()
    await _step(3)
    await _go(Vector3(-11.6, 0, 0.8))


func _expand_section() -> void:
    var pad: PricePad = _level.price_pads["expand_village"]
    var stations0 := _level.stations.size()
    var counters0 := _level.counters.size()
    GameState.add_wallet(1000)
    await _go(Vector3(9.0, 0, 2.5))   # 繞開烤魚攤的輸出格,免得順手拿走烤魚
    var t0 := Time.get_ticks_msec()
    var bought := await _pay_pad(pad)
    var pay_sec := float(Time.get_ticks_msec() - t0) / 1000.0
    await _step(3)
    _check(bought and pay_sec < 20.0 and not pad.visible and GameState.is_unlocked("village_2"), "擴建村莊:$1000 在 %.1f 秒內付清(大額牌加速)" % pay_sec)
    _check(_level.is_expanded() and _level.annex != null and _level.east_gate == null and _level.east_gate_mesh == null and _level.east_walls.is_empty()
            and _level.fish_areas.size() == 2 and _level.stations.size() == stations0 + 2 and _level.counters.size() == counters0 + 2
            and _level.station_at("station_3") != null and _level.station_at("grill_2") != null and _level.counter_by_id("fillet_counter_2") != null
            and _level.counter_by_id("grill_counter_2") != null, "東牆整段拆掉、第二個水區、切魚台 + 烤魚攤、兩座櫃台都蓋好")
    var fa2: FishArea = _level.fish_areas[1]
    await _step(30)
    _check(fa2.fish.size() >= 4 and fa2.rect.position.x > 13.0, "第二個水區有魚(%d)" % fa2.fish.size())
    var walked := await _go(Vector3(20.0, 0, 3.0), 600)
    _check(walked and _player.global_position.x > 14.0 and _level.nearest_fish_area(_player.global_position) == fa2, "玩家走得進擴建區;最近的水區是新的那個")
    var c2: Counter = _level.counter_by_id("fillet_counter_2")
    var came := await _wait_until(func() -> bool: return c2.customers.size() >= 1, 400)
    _check(came and c2.logic.item_id == "fillet" and c2.logic.price == 2, "新櫃台也有顧客排隊")
    _check(_level.bears.logic.entries(_level.expansion_level())[1].x > 30.0 and _level.expansion_level() == 1, "擴建後熊的東邊入口在 annex 外")
    var t7p: PricePad = _level.price_pads["tower_7"]
    var ev2: PricePad = _level.price_pads["expand_village_2"]
    _check(t7p.visible and (_level.price_pads["tower_12"] as PricePad).visible and not (_level.price_pads["tower_13"] as PricePad).visible
            and t7p.global_position.x > 13.0 and t7p.global_position.distance_to(_level.tower_by_id("tower_7").global_position) < 0.1
            and ev2.visible and ev2.logic.current_cost() == 2000 and ev2.global_position.x > 13.0 and ev2.global_position.x < 31.6,
            "擴建區的六座塔牌出現(第二塊的還藏著);第二次擴建牌 $2000 在擴建區裡")
    var hf: PricePad = _level.price_pads["hire_fisher"]
    var hpp: PricePad = _level.price_pads["hire_porter"]
    var hc: PricePad = _level.price_pads["hire_cashier"]
    _check(hf.logic.max_buys == 5 and hpp.logic.max_buys == 6 and hc.logic.max_buys == 4 and hf.visible and hpp.visible and hc.visible
            and not hf.logic.is_exhausted() and not hpp.logic.is_exhausted() and not hc.logic.is_exhausted() and hf.label.text.contains("/5")
            and (_level.price_pads["capacity_1"] as PricePad).logic.max_buys == 3,
            "擴建後僱用牌多開放名額:漁夫 5、搬運工 6、收銀員 4(其他牌不變)")

    # 第二次擴建 $2000:牌子在第一塊擴建區裡 -> 第一塊的東牆拆掉、再往東一塊:第三個水區、切魚台 + 烤魚攤、第三組櫃台、僱用牌再開名額、熊入口再往東
    var stations1 := _level.stations.size()
    var counters1 := _level.counters.size()
    GameState.add_wallet(2000)
    await _go(Vector3(29.5, 0, 3.5))
    var bought2 := await _pay_pad(ev2)
    await _step(3)
    _check(bought2 and not ev2.visible and GameState.is_unlocked("village_3") and _level.expansion_level() == 2 and _level.annexes.size() == 2
            and _level.fish_areas.size() == 3 and _level.stations.size() == stations1 + 4 and _level.counters.size() == counters1 + 2
            and _level.station_at("station_4") != null and _level.station_at("grill_3") != null and _level.station_at("grill_4") != null
            and _level.station_at("grill_5") != null and _level.station_at("grill_5").position.x < 50.0 and _level.counter_by_id("fillet_counter_3") != null
            and _level.counter_by_id("grill_counter_3") != null and _level.annex_east_walls[0].is_empty(),
            "第二次擴建:第三個水區、切魚台 + 三座烤魚攤、第三組櫃台,第一塊擴建區的東牆拆掉")
    var walked3 := await _go(Vector3(40.0, 0, 3.0), 600)
    var fa3: FishArea = _level.fish_areas[2]
    await _step(20)
    _check(walked3 and _player.global_position.x > 36.0 and fa3.rect.position.x > 31.0 and fa3.fish.size() >= 3
            and _level.nearest_fish_area(_player.global_position) == fa3, "走得進第二塊擴建區(x 31.6 沒有牆);第三個水區有魚(%d)" % fa3.fish.size())
    var ev3: PricePad = _level.price_pads["expand_village_3"]
    _check((_level.price_pads["tower_13"] as PricePad).visible and (_level.price_pads["tower_18"] as PricePad).visible
            and not (_level.price_pads["tower_19"] as PricePad).visible
            and _level.bears.logic.entries(_level.expansion_level())[1].x > 50.0 and hf.logic.max_buys == 7 and hpp.logic.max_buys == 10
            and hc.logic.max_buys == 6 and hf.label.text.contains("/7") and ev3.visible and ev3.logic.current_cost() == 8000
            and ev3.global_position.x > 31.6 and ev3.global_position.x < 50.2,
            "第二塊的六座塔牌出現(第三塊的還藏著)、熊的東邊入口在第二塊外、僱用名額 7 / 10 / 6;第三次擴建牌 $8000 在第二塊擴建區裡")
    await _third_expansion(ev3, hf, hpp, hc)
    await _go(Vector3(40.9, 0, 5.0), 900)
    await _go(Vector3(20.0, 0, 3.0), 600)
    await _go(Vector3(11.0, 0, 0.5))
    await _go(Vector3(0, 0, 7))


## 第三次擴建 $8000:牌在第二塊擴建區 -> 第二塊的東牆拆掉、第四個水區、兩座烤魚攤 + 服飾店 + 毛衣櫃台、僱用名額再開、第三塊的塔牌;
## 玩家把 10 張毛皮放進服飾店(站滿 0.8 秒才開始放)-> 工人 5 張做一件毛衣 -> 毛衣到毛衣櫃台賣 $200
func _third_expansion(ev3: PricePad, hf: PricePad, hpp: PricePad, hc: PricePad) -> void:
    var stations2 := _level.stations.size()
    var counters2 := _level.counters.size()
    GameState.add_wallet(8000)
    await _go(Vector3(40.9, 0, 7.0), 600)
    var t0 := Time.get_ticks_msec()
    var bought3 := await _pay_pad(ev3)
    var pay_sec := float(Time.get_ticks_msec() - t0) / 1000.0
    await _step(3)
    var tailor := _level.station_at("tailor")
    var sc: Counter = _level.counter_by_id("sweater_counter")
    _check(bought3 and pay_sec < 20.0 and not ev3.visible and GameState.is_unlocked("village_4") and _level.expansion_level() == 3
            and _level.annexes.size() == 3 and _level.fish_areas.size() == 4,
            "第三次擴建:$8000 在 %.1f 秒內付清;第三塊擴建區、第四個水區(買成 %s、等級 %d、水區 %d)" % [pay_sec, str(bought3), _level.expansion_level(), _level.fish_areas.size()])
    _check(_level.stations.size() == stations2 + 3 and _level.counters.size() == counters2 + 1 and _level.station_at("grill_6") != null
            and _level.station_at("grill_7") != null and tailor != null and tailor.logic.input_id == "pelt" and tailor.logic.output_id == "sweater"
            and tailor.logic.input_per == 5, "第三塊:兩座烤魚攤 + 服飾店(毛皮 -> 毛衣,一批 5 張)(工作站 %d / %d、櫃台 %d / %d)"
            % [_level.stations.size(), stations2 + 3, _level.counters.size(), counters2 + 1])
    _check(sc != null and sc.logic.item_id == "sweater" and sc.logic.price == 200 and sc.want_weights.size() == 1 and int(sc.want_weights[0]) == 1
            and CounterLogic.roll_want(sc.want_weights, 0.99) == 1, "毛衣櫃台 $200、顧客一次只買一件(權重 %s)" % str(sc.want_weights))
    _check(_level.annex_east_walls[1].is_empty() and not _level.annex_east_walls[2].is_empty(), "第二塊的東牆拆掉、第三塊的東牆還在")
    _check((_level.price_pads["tower_19"] as PricePad).visible and (_level.price_pads["tower_24"] as PricePad).visible
            and (_level.price_pads["tower_24"] as PricePad).global_position.x > 60.0
            and _level.bears.logic.entries(_level.expansion_level())[1].x > 70.0 and hf.logic.max_buys == 9 and hpp.logic.max_buys == 14
            and hc.logic.max_buys == 8 and hf.label.text.contains("/9"), "第三塊的六座塔牌出現、熊的東邊入口在第三塊外、僱用名額 9 / 14 / 8")
    # 毛皮放進服飾店:走過輸入格不會放(要站滿 0.8 秒),站著才一張張放
    GameState.pelts = 0   # 先前撿到的毛皮清掉,才能剛好做兩件
    GameState.add_resource("pelt", 10)
    var pelts0 := GameState.pelts
    await _go(Vector3(67.5, 0, 5.0), 900)
    await _go(Vector3(67.5, 0, -2.2), 600)
    var in_pad := tailor.input_pad.global_position
    await _go(Vector3(62.0, 0, -2.2), 600)   # 全速穿過輸入格(x 63.5 ~ 65.5,0.43 秒)
    _check(GameState.pelts == pelts0 and tailor.logic.input_count == 0, "帶著毛皮走過服飾店輸入格:不會放(要站滿 0.8 秒)")
    await _go(in_pad, 300)
    var fed := await _wait_until(func() -> bool: return tailor.logic.input_count >= 10, 300)
    _check(fed and GameState.pelts == pelts0 - 10 and tailor.logic.input_count == 10, "站在輸入格:10 張毛皮從資源扣進服飾店(毛皮 %d)" % GameState.pelts)
    var pt0 := _count("processed_tailor")
    var made := await _wait_until(func() -> bool: return _count("processed_tailor") >= pt0 + 2, 900)
    _check(made and tailor.logic.input_count == 0, "工人 5 張毛皮做一件毛衣:10 張做了 2 件(成品 %d、櫃台 %d、手上 %d)"
            % [tailor.logic.output_count, sc.logic.stock, _carried("sweater")])
    # 自己(或搬運工)把毛衣送到毛衣櫃台,站到收銀格賣 $200
    if not _player.stack.is_empty() and _player.stack.item_id != "sweater":
        print("  (玩家背上有 %s ×%d,先清掉再去拿毛衣)" % [_player.stack.item_id, _player.stack.count])
        _player.stack.clear()
    if tailor.logic.output_count > 0:
        await _go(tailor.output_pad.global_position, 300)
        await _wait_until(func() -> bool: return tailor.logic.output_count == 0, 120)
    if _carried("sweater") > 0:
        await _go(sc.deposit_pad.global_position + Vector3(0, 0, 0.0), 600)
        await _wait_until(func() -> bool: return _carried("sweater") == 0, 120)
    var stocked := await _wait_until(func() -> bool: return sc.logic.stock >= 1, 600)
    var cash0 := _level.money_pad.cash
    var sales0 := _sales.size()
    await _go(sc.service_pad.global_position, 600)
    var sold := await _wait_until(func() -> bool: return not _sale_after(sales0, "sweater").is_empty(), 900)
    var sale := _sale_after(sales0, "sweater")
    _check(stocked and sold and int(sale[1]) == 1 and int(sale[2]) == 200 and _level.money_pad.cash >= cash0 + 200,
            "毛衣上架、顧客一次買一件 $200(錢格 %d -> %d;上架 %s、庫存 %d、手上 %s ×%d、成品 %d、顧客 %d、收銀員 %s、拿貨 %s、玩家 (%.1f, %.1f))"
            % [cash0, _level.money_pad.cash, str(stocked), sc.logic.stock, _player.stack.item_id, _player.stack.count, tailor.logic.output_count,
            sc.customers.size(), str(sc.cashier != null), str(_player.takes_output), _player.global_position.x, _player.global_position.z])
    await _go(Vector3(59.5, 0, 5.0), 600)


## --- 北極熊王 ---
## 把遊戲時間撥到 5 分鐘 -> 王出場(更大、血量 ×4)-> 盯上水裡的魚吃掉:回血、變大 -> 玩家用 Lv3 武器打到血條歸零 -> 王倒下、下一次在 5 分鐘後
func _king_section() -> void:
    var bs: BearSpawner = _level.bears
    var fa: FishArea = _level.fish_areas[0]
    var fish0 := fa.fish.size()
    var t_before := GameState.play_time
    var t1: Tower = _level.tower_by_id("tower_1")
    var t1_alive := t1.is_alive()
    if t1_alive:
        t1.state = "none"   # 王吃魚會繞到西北角順手把塔拆了;這段先把塔收起來(存檔檢查要看它)
        t1._apply_state()
    GameState.play_time = bs.logic.king_at_sec() + 1.0
    bs.cooldown = 999.0   # 這段只看王,一般熊先不要來
    bs.enabled = true
    await _step(3)
    var king := bs.king
    _check(king != null and bs.has_king() and king.is_king and bs.kings_total == 1 and bs.king_next_sec == INF
            and king.size_scale > 1.5 and absf(king.hp_max - bs.logic.hp(GameState.play_time) * bs.logic.king_hp_mult()) < 2.0,
            "5 分鐘:北極熊王出場(體型 %.1f、血 %.0f)" % [king.size_scale if king != null else 0.0, king.hp_max if king != null else 0.0])
    if king == null:
        bs.enabled = false
        GameState.play_time = t_before
        return
    # 漁夫先調到擴建區的水,免得王順手把牠吃了(後面的存檔檢查要看漁夫)
    var fisher := _find_helper("fisher")
    if fisher != null:
        fisher.fish_area = _level.fish_areas[1]
        fisher.global_position = Vector3(22.0, 0, -7.0)
        fisher.state = "idle"
    # 先把王丟進水邊、血扣一半,看牠吃魚回血變大(玩家站遠一點不要打牠)
    await _go(Vector3(0, 0, 9))
    king.hp = king.hp_max * 0.5
    king.global_position = Vector3(0, 0, -5.0)
    var nearest_fish: Fish = null   # 直接盯最近的魚(王現在也會盯建築,別讓牠先跑去拆切魚台)
    for f in fa.fish:
        if nearest_fish == null or f.global_position.distance_to(king.global_position) < nearest_fish.global_position.distance_to(king.global_position):
            nearest_fish = f
    king.target = nearest_fish
    king.state = "hunting"
    var hp_before := king.hp
    var scale_before := king.size_scale
    var ate := await _wait_until(func() -> bool: return _count("fish_eaten") >= 1, 600)
    await _step(2)
    _check(ate and _count("bear_fed") >= 1 and absf(king.hp_ratio() - 0.5) < 0.01 and king.size_scale > scale_before and fish0 > 0,
            "王吃掉水裡的魚:不回血(血條還是 %.0f%%)、只變大(%.2f -> %.2f)" % [king.hp_ratio() * 100.0, scale_before, king.size_scale])
    # 王也會盯幫手:把搬運工放到牠旁邊,咬 2.5 秒吃掉 -> 不回血、變更大(後面的存檔檢查不看搬運工)
    var porter := _find_helper("porter")
    var helpers0 := _level.helpers.size()
    if porter != null:
        king.hp = king.hp_max * 0.3
        king.target = porter
        king.state = "hunting"
        porter.global_position = king.global_position + Vector3(1.0, 0, 0)
        var scale2 := king.size_scale
        var eaten := await _wait_until(func() -> bool: return not is_instance_valid(porter) or porter.eaten, 600)
        await _step(2)
        _check(eaten and _level.helpers.size() == helpers0 - 1 and absf(king.hp_ratio() - 0.3) < 0.01 and king.size_scale > scale2
                and (_level.price_pads["hire_porter"] as PricePad).logic.is_rebuy(), "王吃掉搬運工:不回血(血條 %.0f%%)、體型 %.2f -> %.2f、搬運工牌可買回" % [king.hp_ratio() * 100.0, scale2, king.size_scale])
    await _king_wreck_section(king)
    # 打死王
    king.hp = minf(king.hp, 35.0 * 4.0)   # 測試不想打幾十下:留四下的血(牠在水邊還會邊吃魚邊回血,所以實際會多幾下)
    var hp_left := king.hp
    await _chase_bear(king, 1200)
    var dead := await _wait_until(func() -> bool: return not bs.has_king(), 900)
    _check(dead and _count("bear_defeated") >= 5 and not is_instance_valid(king) and bs.kings_total == 1
            and bs.king_next_sec >= GameState.play_time + bs.logic.king_respawn_sec() - 5.0 and bs.king_next_sec < INF,
            "王被打到血條歸零(剩 %.0f 血)倒下,下一隻 %.0f 秒後(狀態 %s)" % [hp_left, bs.king_next_sec - GameState.play_time,
            (king.state + "/hp %.0f" % king.hp) if is_instance_valid(king) else "freed"])
    _check(str(_level.hud.objective_text()) != "" and _level.hud.stats_text().contains(":") and _level.hud._info.text.contains("Lv"), "HUD:左上只剩資源 / 武器,統計收進選單(有遊戲時間)")
    if t1_alive:
        t1.restore({"state": "alive", "hp": t1.hp_max})
    bs.enabled = false
    await _go(Vector3(0, 0, 7))


## 打死王掉下熊王牙 -> 撿起來 -> 完好的 tower_1 底下有熊王牙牌(沒蓋的塔沒有)-> 站上去付 1 顆 -> 強力守衛塔:血 2000、每箭 25
func _tower_strong_section() -> void:
    var t1: Tower = _level.tower_by_id("tower_1")
    var tp: PricePad = _level.price_pads["tooth_tower_1"]
    var tp2: PricePad = _level.price_pads["tooth_tower_2"]
    var teeth_on_ground := 0
    for l in _level.loot:
        if l.kind == "tooth":
            teeth_on_ground += 1
    _check(GameState.teeth + teeth_on_ground == 3, "打死王掉下 3 顆熊王牙")
    for l in _level.loot.duplicate():
        if is_instance_valid(l) and l.kind == "tooth":
            await _go(l.global_position)
            await _step(3)
    _check(GameState.teeth == 3 and t1.is_alive() and t1.tier == 0 and tp.visible and not tp.logic.is_exhausted() and tp.logic.currency == "tooth"
            and tp.logic.remaining == 1 and tp.label.text.contains(tr("COST_tooth") % 1) and not tp2.visible,
            "撿到熊王牙;完好的守衛塔底下有強化牌(收 1 顆),沒蓋的塔沒有")
    await _go(Vector3(-11.6, 0, 7.0))
    await _go(Vector3(-11.6, 0, -6.0))
    var paid := await _pay_pad(tp)
    await _step(3)
    _check(paid and GameState.teeth == 2 and t1.tier == 1 and t1.is_strong() and is_equal_approx(t1.hp_max, 2000.0) and is_equal_approx(t1.hp, 2000.0)
            and not tp.visible and tp.logic.is_exhausted() and _count("tower_upgraded") == 1 and t1._strong_band.visible
            and t1.logic.bites_to_break(t1.tier) == 50 and is_equal_approx(t1.logic.damage(t1.tier), 25.0),
            "1 顆熊王牙強化守衛塔:血 2000(扛 50 口)、每箭 25、金色塔環、牌消失")
    await _go(Vector3(-11.6, 0, -6.0))
    await _go(Vector3(-11.6, 0, 7.0))
    await _go(Vector3(0, 0, 7))


## 王拆建築:把牠放到第二座切魚台旁邊盯著咬,10 秒就拆掉 -> 廢墟、工人不見、格子停用、搬運工 / 漁夫不再送去、修復牌出現 $200;
## 站上廢墟付清修好 -> 桌子回來、牌消失。存檔快照記 broken。
func _king_wreck_section(king: Bear) -> void:
    var st1 := _level.station_at("station_1")
    var rp: PricePad = _level.price_pads.get("repair_station_1", null)
    if st1 == null or rp == null:
        _check(false, "找不到 station_1 或它的修復牌")
        return
    var bite_sec: float = king.logic.king_building_bite_sec()
    _check(not rp.visible and rp.logic.is_exhausted() and rp.global_position.distance_to(st1.global_position) < 0.1 and not st1.is_broken()
            and st1._built.visible and not st1._rubble.visible, "切魚台完好:修復牌藏著")
    await _go(Vector3(0, 0, 9))
    king.global_position = Vector3(-6, 0, -4.0)
    king.target = st1
    king.state = "hunting"
    var t0 := GameState.play_time
    var biting := await _wait_until(func() -> bool: return king.state == "biting" and king.target == st1, 300)
    var wrecked := await _wait_until(func() -> bool: return st1.is_broken(), int(bite_sec * 60.0) + 240)
    var took := GameState.play_time - t0
    await _step(3)
    var dests_ok := true
    for d in _level.porter_dests():
        if d.get("node", null) == st1:
            dests_ok = false
    for s in _level.porter_sources():
        if s.get("node", null) == st1:
            dests_ok = false
    _check(biting and wrecked and took >= bite_sec - 0.5 and king.buildings_broken == 1 and _count("station_destroyed") == 1
            and not st1._built.visible and st1._rubble.visible and not st1.logic.is_working() and not st1.input_pad.monitoring
            and not st1.output_pad.monitoring and not st1.input_pad.visible,
            "王盯著切魚台咬 %.1f 秒(規則 %.0f 秒)就拆掉:廢墟、工人不見、格子停用" % [took, bite_sec])
    _check(dests_ok and _level.find_station_accepting("fish") != st1 and _level.find_station_with_input("fish") != st1
            and _level.find_station_with_output("fillet") != st1, "被拆的切魚台不再是搬運工 / 漁夫的目的地或來源")
    _check(rp.visible and rp.logic.is_rebuy() and rp.logic.buys == 0 and rp.logic.lost == 1 and rp.logic.remaining == 100
            and rp.label.text.contains(tr("PAD_REPAIR")) and rp.label.text.contains(tr("STATION_cutting_table")) and not rp.label.text.contains("×")
            and bool(_level.snapshot()["stations"]["station_1"].get("broken", false)), "廢墟上出現修復牌 $200(存檔記 broken)")
    # 王先定住、挪遠一點,玩家去修
    king.set_physics_process(false)
    king.target = null
    king.state = "hunting"
    king.global_position = Vector3(-6, 0, -7.0)
    GameState.add_wallet(200)
    rp.logic.pay(80)   # 測試時間預算:先付 80
    rp._update_label()
    var repaired := await _pay_pad(rp)
    await _step(3)
    _check(repaired and not st1.is_broken() and st1._built.visible and not st1._rubble.visible and st1.input_pad.monitoring and st1.output_pad.monitoring
            and not rp.visible and rp.logic.is_exhausted() and rp.logic.lost == 0 and _count("station_repaired") == 1 and st1.times_broken == 1
            and st1.times_repaired == 1 and not bool(_level.snapshot()["stations"]["station_1"].get("broken", true)),
            "花 $200 修好:切魚台回來、牌消失、存檔不再記 broken")
    await _go(Vector3(0, 0, 9))
    await _empty_hands()
    king.set_physics_process(true)
