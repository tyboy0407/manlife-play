extends Node
## 自動試玩機器人:照著 Guide 的提示箭頭走(就像一個聽話的新手玩家),北極熊一律用預設規則出沒,
## 把一局的節奏記下來:每 10 秒的錢包 / 幫手 / 提示、每筆購買的時間、被吃的幫手、熊 / 王 / 塔 / 工作站事件、閒置(沒提示)時間、卡住次數。
## 跑法(headless 即可):godot --headless --path . res://tools/playtest.tscn -- <遊戲分鐘數 預設 20> <時間倍速 預設 3> <亂數種子 預設 1>
## 看輸出的 [T+秒] 事件與最後的 SUMMARY;數值只給平衡 / 體驗調整當參考。

const HARBOR := preload("res://game/levels/harbor.tscn")
const GATE_X := -12.6
const GATE_Z := 2.5
const REPORT_SEC := 10.0

var level: Harbor
var player: Player
var minutes := 20.0
var scale := 3.0
var seed_v := 1

var _moving := false
var _target := Vector3.ZERO
var _idle_sec := 0.0          # 沒有提示、也沒事做的時間
var _hint_sec := {}           # 每種提示 kind 累計多久
var _stuck_count := 0
var _stuck_timer := 0.0
var _last_pos := Vector3.ZERO
var _sidestep := 0.0
var _report_t := 0.0
var _events: Array[String] = []
var _purchases: Array[String] = []
var _bears_seen := 0
var _bears_defeated := 0
var _bears_left := 0
var _eaten := {}
var _wallet_log: Array[int] = []
var _real_start := 0
var _last_stack := 0
var _unloading := 0.0        # 背上的數量剛變少:像真人一樣先站著卸完再走
var _hold_target := Vector3.ZERO


func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() > 0:
        minutes = float(args[0])
    if args.size() > 1:
        scale = float(args[1])
    if args.size() > 2:
        seed_v = int(args[2])
    seed(seed_v)
    SaveManager.save_path = "user://_playtest_save_%d.json" % seed_v
    SaveManager.delete()
    GameState.reset()
    Settings.quality = Settings.SMOOTH
    level = HARBOR.instantiate()
    add_child(level)
    await get_tree().physics_frame
    await get_tree().physics_frame
    player = level.player
    player.input_provider = _provide
    _last_pos = player.global_position
    _connect_events()
    Engine.time_scale = scale
    _real_start = Time.get_ticks_msec()
    print("PLAYTEST: %.0f min 遊戲時間、%.0f 倍速、seed %d" % [minutes, scale, seed_v])


func _connect_events() -> void:
    EventBus.purchased.connect(func(id: String, _e: Dictionary) -> void:
        var pad: PricePad = level.price_pads.get(id, null)
        var cost := pad.logic.current_cost() if pad != null else 0
        _purchases.append("%s @%s(下一次 %s)" % [id, _t(), str(cost)])
        _log("買了 %s(錢包剩 $%d)" % [id, GameState.wallet]))
    EventBus.notice.connect(func(text: String) -> void: _log("通知:%s" % text))
    EventBus.bear_appeared.connect(func(_b: Node3D) -> void: _bears_seen += 1)
    EventBus.bear_defeated.connect(func(_b: Node3D, _by: Node3D) -> void: _bears_defeated += 1)
    EventBus.bear_left.connect(func(_r: String) -> void: _bears_left += 1)
    EventBus.helper_eaten.connect(func(role: String, _h: Node3D) -> void:
        _eaten[role] = int(_eaten.get(role, 0)) + 1
        _log("幫手被吃:%s(目前 漁夫 %d / 搬運工 %d / 收銀員 %d)" % [role, _count_role("fisher"), _count_role("porter"), _count_role("cashier")]))
    EventBus.tower_destroyed.connect(func(t: Node3D, _b: Node3D) -> void: _log("守衛塔塌了:%s" % t.name))
    EventBus.station_destroyed.connect(func(s: Node3D, _b: Node3D) -> void: _log("工作站被拆:%s" % s.name))
    EventBus.tutorial_finished.connect(func() -> void: _log("教學完成"))
    EventBus.tutorial_step_done.connect(func(step: int) -> void: _log("教學第 %d 步完成" % step))


func _t() -> String:
    return "%d:%02d" % [int(GameState.play_time) / 60, int(GameState.play_time) % 60]


func _log(s: String) -> void:
    var line := "[T+%s] %s" % [_t(), s]
    _events.append(line)
    print(line)


func _count_role(role: String) -> int:
    var n := 0
    for h in level.helpers:
        if h.role == role:
            n += 1
    return n


func _provide() -> MoveInput:
    if not _moving or player == null:
        return MoveInput.new()
    if _sidestep > 0.0:
        var d := (_target - player.global_position)
        var perp := Vector3(-d.z, 0, d.x).normalized()
        return MoveInput.toward(player.global_position, player.global_position + perp * 3.0, 0.25)
    return MoveInput.toward(player.global_position, _target, 0.25)


func _physics_process(delta: float) -> void:
    if level == null or player == null:
        return
    if GameState.play_time >= minutes * 60.0:
        _finish()
        return
    var g: Guide = level.guide
    var kind := str(g.current.get("kind", "none")) if g != null else "none"
    _hint_sec[kind] = float(_hint_sec.get(kind, 0.0)) + delta
    var cnt := player.stack.count
    if cnt < _last_stack and cnt > 0:
        _unloading = 0.6
        _hold_target = _target
    _last_stack = cnt
    if _unloading > 0.0:
        _unloading -= delta
        _moving = true
        _target = _hold_target
        _idle_tick(false, delta)
    elif g != null and g.has_target:
        _moving = true
        var tp := g.target_pos
        # 工作站塞住(輸出滿 -> 停工 -> 輸入也滿),提示只會叫你「等」:真人會把手上的魚丟掉、去拿成品賣
        # 櫃台滿了、沒人收銀,提示也只會指上架格:真人會站到收銀格賣
        if kind == "counter_deposit" and str(g.current.get("text", "")) == "HINT_counter_full":
            var cf := level.counter_by_id(str(g.current.get("target", "")))
            if cf != null and cf.cashier == null:
                tp = cf.service_pad.global_position
                _hint_sec["(櫃台滿了改去收銀)"] = float(_hint_sec.get("(櫃台滿了改去收銀)", 0.0)) + delta
        if kind == "station_input" and str(g.current.get("text", "")) == "HINT_station_full" and level.trash_pad != null:
            tp = level.trash_pad.global_position
            _hint_sec["(工作站塞住改丟魚)"] = float(_hint_sec.get("(工作站塞住改丟魚)", 0.0)) + delta
        # 教學最後一步 / 提示指著牌子但錢包空、錢格也空:真人會回去做工賺錢,不會呆站在牌子上
        if kind == "pad" and GameState.wallet == 0:
            var pad: PricePad = level.price_pads.get(str(g.current.get("target", "")), null)
            if pad != null and pad.logic.is_cash():
                var w := level.money_pad.global_position if level.money_pad.cash > 0 else _work_target()
                if w != Vector3.INF:
                    tp = w
                    _hint_sec["(牌子沒錢改去做工)"] = float(_hint_sec.get("(牌子沒錢改去做工)", 0.0)) + delta
        _target = _route(tp)
        _idle_tick(false, delta)
    else:
        _moving = false
        _idle_tick(true, delta)
    # 卡住偵測:要走卻 2 秒沒移動
    if _moving:
        _stuck_timer += delta
        if _stuck_timer >= 2.0:
            if player.global_position.distance_to(_last_pos) < 0.3 and player.planar_distance_to(_target) > 0.6:
                _stuck_count += 1
                _sidestep = 0.8
                _log("卡住 #%d:在 (%.1f, %.1f) 要去 (%.1f, %.1f) 提示 %s" % [_stuck_count, player.global_position.x, player.global_position.z,
                        _target.x, _target.z, kind])
            _stuck_timer = 0.0
            _last_pos = player.global_position
    if _sidestep > 0.0:
        _sidestep -= delta
    _report_t += delta
    if _report_t >= REPORT_SEC:
        _report_t = 0.0
        _wallet_log.append(GameState.wallet)
        print("[T+%s] 錢包 $%d 毛皮 %d 牙 %d | 漁 %d 搬 %d 收 %d | 賣出 %d 抓魚 %d | 提示 %s %s | 熊 %d 王 %s | 塔 %d | 玩家 (%.1f, %.1f) 背 %s×%d 錢格 $%d" % [
                _t(), GameState.wallet, GameState.pelts, GameState.teeth, _count_role("fisher"), _count_role("porter"), _count_role("cashier"),
                GameState.items_sold, GameState.fish_caught, kind, str(g.current.get("target", "")) if g != null else "",
                level.bears.bears.size(), "在" if level.bears.king != null and is_instance_valid(level.bears.king) else "無", level.alive_towers().size(),
                player.global_position.x, player.global_position.z, player.stack.item_id, player.stack.count, level.money_pad.cash])
        if kind == "station_input" and player.planar_distance_to(_target) < 0.5:
            var st0 := level.station_at(str(g.current.get("target", "")))
            if st0 != null:
                print("    切魚台 %s:輸入 %d/%d 輸出 %d/%d 阻塞 %s 處理中 %s 廢墟 %s | 格子 monitoring %s 重疊 %d | 玩家 layer %d 背 %s×%d/%d" % [
                        st0.spot_id, st0.logic.input_count, st0.logic.input_cap, st0.logic.output_count, st0.logic.output_cap,
                        str(st0.logic.is_blocked()), str(st0.logic.processing), str(st0.is_broken()), str(st0.input_pad.monitoring),
                        st0.input_pad.get_overlapping_bodies().size(), player.collision_layer, player.stack.item_id, player.stack.count, player.stack.capacity])
        if kind == "pad":
            var pid := str(g.current.get("target", ""))
            var pd: PricePad = level.price_pads.get(pid, null)
            var st := g.build_state()
            var cheap: Array[String] = []
            for e in st.get("pads", []):
                if bool(e.get("visible", true)) and str(e.get("currency", "cash")) == "cash" and int(e.get("remaining", 0)) <= GameState.wallet:
                    cheap.append("%s:%d" % [e.get("id", ""), int(e.get("remaining", 0))])
            print("    牌 %s 剩 %d buys %d lost %d 可見 %s | 熊旗標 %s | 買得起 %s" % [pid, pd.logic.remaining if pd else -1, pd.logic.buys if pd else -1,
                    pd.logic.lost if pd else -1, str(pd.visible) if pd else "?", str(st.get("bear", false)), str(cheap)])


func _idle_tick(idle: bool, delta: float) -> void:
    if idle:
        _idle_sec += delta


## 自己找事做(沒錢付牌子時):手上有貨 -> 收它的工作站 / 櫃台;空手 -> 有貨沒人收銀的櫃台 > 有成品的工作站 > 去抓魚
func _work_target() -> Vector3:
    var item := player.stack.item_id
    if player.stack.count > 0:
        for c in level.counters:
            if c.logic.item_id == item and c.logic.space() > 0:
                return c.deposit_pad.global_position
        var st := level.find_station_accepting(item)
        if st != null:
            return st.input_pad.global_position
        return level.trash_pad.global_position
    for c in level.counters:
        if c.logic.stock > 0 and not c.has_server() and c.cashier == null:
            return c.service_pad.global_position
    for st in level.stations:
        if not st.is_broken() and st.logic.output_count > 0:
            return st.output_pad.global_position
    var fa := level.nearest_fish_area(player.global_position)
    if fa != null:
        var f := fa.nearest_fish_to(player.global_position)
        if f != null:
            return f.global_position
        return Vector3(fa.rect.get_center().x, 0, fa.rect.get_center().y)
    return Vector3.INF


## 要跨西牆(x -12.6)就先走到缺口(z 2.5)再穿過去;其他目的地直線走
func _route(dest: Vector3) -> Vector3:
    var p := player.global_position
    var in_x := GATE_X + 1.2
    var out_x := GATE_X - 1.2
    var dest_inside := dest.x > GATE_X
    if p.x >= out_x and p.x <= in_x:
        # 在門洞裡:先走到目的地那一側、門洞外一點的位置(超過停下的死區),再直線走(斜著走會擦牆)
        if absf(p.z - GATE_Z) > 0.5:
            return Vector3(p.x, 0, GATE_Z)
        return Vector3(in_x + 0.7 if dest_inside else out_x - 0.7, 0, GATE_Z)
    var inside := p.x > in_x
    if inside == dest_inside:
        return dest
    # 要跨牆:先走進門洞(門洞內 0.5,到了一定算在門洞裡)
    return Vector3(in_x - 0.5 if inside else out_x + 0.5, 0, GATE_Z)


func _finish() -> void:
    Engine.time_scale = 1.0
    set_physics_process(false)
    var real_sec := (Time.get_ticks_msec() - _real_start) / 1000.0
    print("")
    print("===== SUMMARY(%.0f 分鐘遊戲時間,實際 %.0f 秒)=====" % [GameState.play_time / 60.0, real_sec])
    print("錢包 $%d、累計收入 $%d、賣出 %d 件、抓魚 %d 條、丟掉 %d 件" % [GameState.wallet, GameState.cash_earned, GameState.items_sold, GameState.fish_caught, GameState.items_trashed])
    print("幫手:漁夫 %d 搬運工 %d 收銀員 %d;被吃 %d(%s)" % [_count_role("fisher"), _count_role("porter"), _count_role("cashier"), GameState.helpers_lost, str(_eaten)])
    print("熊:出現 %d 隻、打跑 / 打死 %d、離開 %d;毛皮 %d 牙 %d 武器 Lv%d 武器店 Lv%d" % [_bears_seen, _bears_defeated, _bears_left, GameState.pelts, GameState.teeth, GameState.weapon_level, GameState.shop_level])
    print("守衛塔活著 %d / 6;擴建 %s;升級 %s" % [level.alive_towers().size(), str(level.is_expanded()), str(GameState.upgrades)])
    print("閒置(沒提示)%.0f 秒 = %.0f%%;卡住 %d 次" % [_idle_sec, 100.0 * _idle_sec / maxf(GameState.play_time, 1.0), _stuck_count])
    var hk := _hint_sec.keys()
    hk.sort()
    var parts: Array[String] = []
    for k in hk:
        parts.append("%s %.0fs" % [k, float(_hint_sec[k])])
    print("提示種類時間:%s" % ", ".join(parts))
    print("錢包每 10 秒:%s" % str(_wallet_log))
    print("購買順序:")
    for p in _purchases:
        print("  " + p)
    SaveManager.delete()
    SaveManager.save_path = SaveManager.DEFAULT_PATH
    GameState.reset()
    Sfx.stop_all()
    await get_tree().process_frame
    await get_tree().process_frame
    get_tree().quit(0)
