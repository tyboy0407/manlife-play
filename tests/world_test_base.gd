class_name WorldTestBase
extends Node3D
## 世界整合測試共用底層(verify_world / verify_world2):建關卡、合成輸入走路、付牌、追熊、事件計數、存檔路徑與收尾。
## 子類別覆寫 _tag()(印在輸出前面)與 _run()(測試流程)。

const HARBOR := preload("res://game/levels/harbor.tscn")
const HANDOFF := "user://_verify_world_handoff.json"   # verify_world 跑完留給 verify_world2 接手的存檔

var _fails := 0
var _level: Harbor
var _player: Player
var _target := Vector3.ZERO
var _moving := false
var _events := {}
var _sales: Array = []   # [item, count, cash]


func _tag() -> String:
    return "WORLD"


func _run() -> void:
    pass


func _ready() -> void:
    print("VERIFY %s: begin" % _tag())
    SaveManager.save_path = "user://_verify_%s_save.json" % _tag().to_lower()
    SaveManager.delete()
    GameState.reset()
    Settings.path = "user://_verify_%s_settings.json" % _tag().to_lower()
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
    EventBus.chest_claimed.connect(func(_c: Dictionary) -> void: _bump("chest_claimed"))
    EventBus.helper_insured.connect(func(_r: String) -> void: _bump("helper_insured"))
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
        print("VERIFY %s: ALL OK" % _tag())
    else:
        print("VERIFY %s: %d FAILURES" % [_tag(), _fails])
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
    BearSpawner.auto_enabled = false   # 關卡一建好就不生熊(讀檔的冷卻可能已經到 0,等不到下面那行)
    _level = HARBOR.instantiate()
    add_child(_level)
    await _step(3)
    _player = _level.player
    _player.input_provider = _provide
    _level.bears.enabled = false   # 北極熊只在測試指定的時候出現(不然 45 秒後會自己來吃幫手)
    _level.juice.hitstop_enabled = false   # 停格會動 Engine.time_scale,計時的檢查別受影響(震動 / 彈出照常)
    _level.orders.next_in = 1.0e9  # 訂單 / 金魚也只在測試指定時出現(搬運工跑去碼頭、通知蓋掉別的會干擾檢查)
    FishArea.rare_auto = false


## 追著熊跑並打它(玩家帶武器靠近會自動攻擊;熊會動,每幀更新目標)直到牠血條歸零逃走 / 消失或超時
func _chase_bear(bear: Bear, max_frames: int) -> void:
    _moving = true
    _player.collects_cash = false   # 追熊會跑過價格牌 / 錢格:追的期間不付錢不收錢(站在被咬的幫手旁 8 秒會把牌子買下來)
    for i in max_frames:
        if bear == null or not is_instance_valid(bear) or bear.state == "fleeing":
            break
        _target = bear.global_position
        await get_tree().physics_frame
    _moving = false
    _player.collects_cash = true
    await _step(2)


## 追一群熊:每幀朝最近一隻還沒逃的走,全逃了或超時就停
func _chase_pack(bs: BearSpawner, max_frames: int) -> void:
    _moving = true
    _player.collects_cash = false
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
    _player.collects_cash = true
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


## 通知會排隊(前一則不到 0.9 秒就等):等到 HUD 顯示含 key 翻譯前幾個字的通知,最多 max_frames
func _notice_soon(key: String, max_frames: int = 240) -> bool:
    var head := tr(key).substr(0, 4)
    return await _wait_until(func() -> bool: return _level.hud.notice_text().contains(head), max_frames)


func _sales_of(item: String) -> int:
    var n := 0
    for s in _sales:
        if str(s[0]) == item:
            n += int(s[1])
    return n


