extends Node3D
## 幫手走位 headless 驗證:擴建村莊後東牆整段拆掉,搬運工 / 漁夫在主村與擴建區之間直線來回,不能卡在牆上。
## 跑法:godot --headless --path . res://tests/verify_nav.tscn(先 --import)

const HARBOR := preload("res://game/levels/harbor.tscn")

var _fails := 0
var _level: Harbor


func _check(cond: bool, label: String) -> void:
    if cond:
        print("  OK   %s" % label)
    else:
        _fails += 1
        print("  FAIL %s" % label)


func _step(frames: int) -> void:
    for i in frames:
        await get_tree().physics_frame


func _wait_until(pred: Callable, max_frames: int) -> bool:
    for i in max_frames:
        if pred.call():
            return true
        await get_tree().physics_frame
    return pred.call()


func _ready() -> void:
    print("VERIFY NAV: begin")
    SaveManager.save_path = "user://_verify_nav_save.json"
    SaveManager.delete()
    GameState.reset()
    Settings.path = "user://_verify_nav_settings.json"
    Settings.quality = Settings.FINE
    _level = HARBOR.instantiate()
    add_child(_level)
    await _step(3)
    _level.bears.enabled = false
    _level.orders.next_in = 1.0e9
    FishArea.rare_auto = false
    _level.player.input_provider = func() -> MoveInput: return MoveInput.new()
    GameState.tutorial_step = GuideLogic.tutorial_steps()
    GameState.apply_purchase("expand_village", {"type": "unlock", "target": "village_2"})
    await _step(3)
    var c2 := _level.counter_by_id("fillet_counter_2")
    var fa2: FishArea = _level.fish_areas[1] if _level.fish_areas.size() > 1 else null
    var walls_left := 0
    for n in _level.world.get_children():
        if n is StaticBody3D and absf((n as Node3D).position.x - 12.6) < 0.01:
            walls_left += 1
    _check(_level.is_expanded() and c2 != null and fa2 != null and _level.east_walls.is_empty() and _level.east_gate == null and walls_left == 0,
            "擴建好:東邊櫃台與第二個水區,x 12.6 的東牆整段拆掉(剩 %d 段)" % walls_left)
    # 搬運工:在主村拿著魚片,目的地是擴建區的櫃台(直線會撞在東牆上)
    var porter := _level.spawn_helper("porter", true)
    porter.global_position = Vector3(-6.0, 0, 2.2)
    for i in 4:
        porter.stack.push("fillet")
    porter.job = {"from": _level.stations[0], "to": c2, "item": "fillet", "amount": 4}
    porter._start_dropoff(c2)
    var crossed := await _wait_until(func() -> bool: return porter.global_position.x > 12.65, 600)
    var delivered := await _wait_until(func() -> bool: return porter.delivered_total >= 1, 600)
    _check(crossed and delivered, "搬運工直接穿過原本的東牆把魚片送到擴建區的櫃台(x %.1f, 送達 %d)" % [porter.global_position.x, porter.delivered_total])
    # 搬運工回來:擴建區的工作站成品送回主村的櫃台
    var st3 := _level.station_at("station_3")
    st3.logic.output_count = 6
    st3.refresh_piles()
    var c1 := _level.counter_by_id("fillet_counter")
    c1.logic.stock = 0
    c1.refresh_pile()
    porter.stack.clear()
    porter.state = "idle"
    porter.job = {"from": st3, "to": c1, "item": "fillet", "amount": 4}
    porter.target = st3.output_pad.global_position
    porter.state = "to_pickup"
    var back := await _wait_until(func() -> bool: return porter.global_position.x < 11.5 and not porter.stack.is_empty(), 900)
    var delivered2 := await _wait_until(func() -> bool: return porter.delivered_total >= 5, 600)
    _check(back and delivered2, "搬運工從擴建區拿成品直線送回主村(x %.1f, 送達 %d)" % [porter.global_position.x, porter.delivered_total])
    # 漁夫:在主村,被派去擴建區的水
    var fisher := _level.spawn_helper("fisher", true)
    fisher.global_position = Vector3(-3.0, 0, -6.0)
    fisher.fish_area = fa2
    fisher.state = "idle"
    var in_water := await _wait_until(func() -> bool: return fa2.contains(fisher.global_position), 900)
    _check(in_water, "漁夫直線走進擴建區的水(x %.1f z %.1f)" % [fisher.global_position.x, fisher.global_position.z])
    # 漁夫抓滿後回主村的切魚台卸貨(擴建區的切魚台先塞滿,逼它走回來)
    st3.logic.input_count = st3.logic.input_cap
    st3.refresh_piles()
    fisher.stack.clear()
    for i in fisher.stack.capacity:
        fisher.stack.push("fish")
    var st1: Station = _level.stations[0]
    st1.logic.input_count = 0
    st1.refresh_piles()
    var dep0 := fisher.deposited_total
    var deposited := await _wait_until(func() -> bool: return fisher.deposited_total > dep0 and st1.logic.input_count >= 1, 1200)
    _check(deposited and fisher.global_position.x < 12.0, "漁夫背著魚直線回主村的切魚台卸貨(x %.1f, state %s, dest %s, 卸 %d, st1 %d)" % [
            fisher.global_position.x, fisher.state, str(fisher._dest), fisher.deposited_total, st1.logic.input_count])
    _check(_level.route(Vector3(-5, 0, 8), Vector3(20, 0, 8)).is_empty() and _level.route(Vector3(20, 0, 8), Vector3(-5, 0, 8)).is_empty(),
            "route:村裡之間沒有牆要繞,空陣列")
    # 搬運工送訂單:碼頭在村外西北,要繞西門與武器店院子的西缺口(route 給中途點);送到後回村
    var o := _level.orders.generate({"fillet": 2}, 0, 1.0)
    _level._refresh_order_text()
    _check(o.has("lines") and _level.orders.need_of("fillet") == 6 and _level.porter_dests().size() >= 3, "貼一張只要魚片的訂單:碼頭進了搬運工的目的地清單")
    porter.stack.clear()
    for i in 4:
        porter.stack.push("fillet")
    porter.global_position = Vector3(-4.0, 0, 7.0)
    porter.job = {"from": st3, "to": _level.dock, "item": "fillet", "amount": 4}
    porter._start_dropoff(_level.dock)
    var routed := _level.route(porter.global_position, _level.dock.global_position).size()
    var out_gate := await _wait_until(func() -> bool: return porter.global_position.x < -13.0, 600)
    var out_yard := await _wait_until(func() -> bool: return porter.global_position.x < -24.0, 600)
    var dock_ok := await _wait_until(func() -> bool: return _level.orders.need_of("fillet") <= 2, 900)
    _check(routed == 5 and out_gate and out_yard and dock_ok and porter.stack.is_empty() and _level.orders.need_of("fillet") == 2,
            "搬運工帶 4 片魚片繞西門 / 院子缺口走到碼頭交貨(中途點 %d、x %.1f、訂單還缺 %d)" % [routed, porter.global_position.x, _level.orders.need_of("fillet")])
    # 回村:idle 後去拿擴建區切魚台的成品(路線倒著走)
    st3.logic.output_count = 6
    st3.refresh_piles()
    c1.logic.stock = 0
    c1.refresh_pile()
    var home := await _wait_until(func() -> bool: return porter.global_position.x > -12.0, 1200)
    _check(home and porter.global_position.z > -3.0 and porter.global_position.z < 12.0, "搬運工從碼頭倒著走回村裡(x %.1f z %.1f state %s)" % [porter.global_position.x, porter.global_position.z, porter.state])
    _level.orders.order = {}
    _level.queue_free()
    await _step(2)
    SaveManager.delete()
    SaveManager.save_path = SaveManager.DEFAULT_PATH
    Settings.delete_file()
    Settings.path = Settings.DEFAULT_PATH
    Settings.load_settings()
    GameState.reset()
    Sfx.stop_all()
    await _step(10)
    if _fails == 0:
        print("VERIFY NAV: ALL OK")
    else:
        print("VERIFY NAV: %d FAILURES" % _fails)
    get_tree().quit(1 if _fails > 0 else 0)
