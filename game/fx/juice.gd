class_name Juice
extends Node
## 打擊感(掛在關卡下,純表現層):聽 EventBus 事件,依 JuiceLogic 的分級
## - 相機 trauma 震動(FollowCamera.add_trauma;離玩家越遠加越少)
## - hit-stop(Engine.time_scale 短暫放慢,用不吃 time_scale 的計時器還原;只有 medium / large,測試可用 hitstop_enabled 關掉)
## - 數字彈出(Label3D 物件池:打熊 -N、訂單 +$N、王升級 Lv)
## - 人物 / 堆疊的 squash & stretch 彈跳(抓到魚、撿到掉落物:縮一下再用 TRANS_BACK 彈回)
## - 大事件 HUD 白閃(Hud.flash)
## Settings.fx_on 關掉時不震、不閃、不停格(數字彈出與彈跳保留)。

var level: Node = null
var logic: JuiceLogic
var hitstop_enabled := true
var pops_total := 0
var shakes_total := 0
var hitstops_total := 0

var _pool: Array[Label3D] = []
var _hitstop_id := 0


func _ready() -> void:
    add_to_group("juice")
    logic = JuiceLogic.from_config(GameData.config().get("juice", {}))
    EventBus.fish_caught.connect(func(c: Node3D) -> void: _pop_node(c, "fish_caught"))
    EventBus.loot_collected.connect(func(_k: String, _n: int) -> void:
        if level != null and level.player != null:
            _pop_node(level.player, "loot_collected"))
    EventBus.bear_hit.connect(func(b: Node3D, dmg: float, _hp: float) -> void:
        _event("bear_hit", b)
        _pop_text(b.global_position + Vector3(0, 2.2, 0), "-%d" % int(round(dmg)), Color(1.0, 0.85, 0.3)))
    EventBus.bear_defeated.connect(func(b: Node3D, _by: Node3D) -> void:
        var king := b is Bear and (b as Bear).is_king
        _event("king_defeated" if king else "bear_defeated", b)
        if king:
            _flash(Color(1, 1, 1, 0.55), 0.18))
    EventBus.bear_appeared.connect(func(b: Node3D) -> void:
        _event("king_appeared" if (b is Bear and (b as Bear).is_king) else "bear_appeared", b))
    EventBus.trap_triggered.connect(func(t: Node3D, _b: Node3D) -> void: _event("trap_triggered", t))
    EventBus.tower_destroyed.connect(func(t: Node3D, _b: Node3D) -> void: _event("tower_destroyed", t))
    EventBus.station_destroyed.connect(func(s: Node3D, _b: Node3D) -> void: _event("station_destroyed", s))
    EventBus.helper_eaten.connect(func(_r: String, h: Node3D) -> void: _event("helper_eaten", h))
    EventBus.tower_built.connect(func(t: Node3D) -> void: _event("tower_built", t))
    EventBus.chest_opened.connect(func(_r: Dictionary) -> void: _event("chest_opened", null))
    EventBus.order_completed.connect(func(r: Dictionary) -> void:
        _event("order_completed", null)
        if level != null and level.player != null:
            _pop_text(level.player.global_position + Vector3(0, 2.4, 0), "+$%d" % int(r.get("cash", 0)), Color(0.6, 1.0, 0.6)))
    EventBus.king_leveled.connect(func(lv: int) -> void:
        if level != null and level.player != null:
            _pop_text(level.player.global_position + Vector3(0, 2.8, 0), tr("HUD_KING_LV") % lv, Color(1.0, 0.8, 0.3)))
    EventBus.cash_collected.connect(func(_c: Node3D, _amount: int) -> void:
        if level != null and level.hud != null and level.hud.has_method("pop_wallet"):
            level.hud.pop_wallet())


func fx_on() -> bool:
    return Settings.fx_on


## 一個分級事件:震動(依距離)+ hit-stop
func _event(event: String, at: Node3D) -> void:
    var cam = level.camera if level != null and "camera" in level else null
    var d := 0.0
    if at != null and is_instance_valid(at) and level != null and level.player != null and is_instance_valid(level.player):
        d = Vector2(at.global_position.x - level.player.global_position.x, at.global_position.z - level.player.global_position.z).length()
    var amount := logic.trauma_for(event, d)
    if amount > 0.0 and fx_on() and cam != null and cam.has_method("add_trauma"):
        cam.add_trauma(amount)
        shakes_total += 1
    var hs := logic.hitstop_for(event)
    if hs > 0.0 and fx_on() and hitstop_enabled and (at == null or d < logic.falloff_far):
        _hit_stop(hs)


## 短暫放慢時間再還原;只有最新一次 hit-stop 有權還原(兩下重疊時不會提早恢復)
func _hit_stop(duration: float, slow: float = 0.08) -> void:
    if get_tree().paused:
        return
    _hitstop_id += 1
    var my_id := _hitstop_id
    hitstops_total += 1
    Engine.time_scale = slow
    await get_tree().create_timer(duration, true, false, true).timeout
    if my_id == _hitstop_id and is_inside_tree():
        Engine.time_scale = 1.0


func _exit_tree() -> void:
    Engine.time_scale = 1.0   # 換場景時別把慢動作帶到下一關


## squash & stretch:先壓扁再用 TRANS_BACK 彈回(只動外觀節點,不動物理)
func _pop_node(n: Node, event: String) -> void:
    if n == null or not is_instance_valid(n):
        return
    var target: Node3D = null
    if "model" in n and n.model != null:
        target = n.model   # 人物:只縮模型,不動 CharacterBody3D
    elif n is Node3D and not (n is PhysicsBody3D):
        target = n
    if target == null or not is_instance_valid(target):
        return
    var k := logic.pop_for(event)
    pops_total += 1
    var base: Vector3 = target.get_meta("base_scale", target.scale)
    target.set_meta("base_scale", base)
    target.scale = Vector3(base.x * k, base.y * (2.0 - k), base.z * k)
    var tw := target.create_tween()
    tw.tween_property(target, "scale", base, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 數字 / 短字彈出:往上飄 1 格、淡出(物件池)
func _pop_text(pos: Vector3, text: String, color: Color) -> void:
    var l := _take_label()
    l.text = text
    l.modulate = color
    l.outline_modulate = Color(0, 0, 0, 0.9)
    l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0.0, 0.0)
    l.visible = true
    l.scale = Vector3.ONE * 0.6
    pops_total += 1
    var tw := l.create_tween()
    tw.set_parallel(true)
    tw.tween_property(l, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tw.tween_property(l, "global_position", l.global_position + Vector3(0, 1.0, 0), 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
    tw.chain().tween_callback(_release_label.bind(l))


func _take_label() -> Label3D:
    if not _pool.is_empty():
        return _pool.pop_back()
    var l := Label3D.new()
    l.font = VisualFactory.CJK_FONT
    l.font_size = 56
    l.outline_size = 10
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.no_depth_test = true
    l.pixel_size = 0.01
    l.set_meta("keep", true)   # 不吃 Harbor 的距離淡出
    add_child(l)
    return l


func _release_label(l: Label3D) -> void:
    if not is_instance_valid(l):
        return
    l.visible = false
    _pool.append(l)


func pooled() -> int:
    return _pool.size()


func _flash(color: Color, sec: float) -> void:
    if fx_on() and level != null and level.hud != null and level.hud.has_method("flash"):
        level.hud.flash(color, sec)
