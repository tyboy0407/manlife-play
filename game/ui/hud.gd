extends CanvasLayer
## HUD:左上角錢包 / 背包內容 / 累計,上方中央目標 / 提示文字(Guide 餵),中央通知(EventBus.notice,淡出),下方操作提示。
## 現金飛向錢包:聽 items_moved kind "cash",把 3D 位置投影到螢幕,生一個 "$" 飛到錢包數字再彈一下。只讀狀態,不改遊戲。

var player: Player = null

var _wallet: Label
var _info: Label
var _hint: Label
var _notice: Label
var _objective: Label
var _notice_timer := 0.0
var _objective_text := ""
var _chips := 0


func _ready() -> void:
    layer = 4
    _wallet = _make_label(24, Color(1.0, 0.88, 0.45))
    _wallet.position = Vector2(14, 10)
    add_child(_wallet)
    _info = _make_label(15, Color(0.95, 0.97, 1.0))
    _info.position = Vector2(14, 46)
    add_child(_info)
    _hint = _make_label(13, Color(0.8, 0.85, 0.95))
    _hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 14)
    _hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
    _hint.text = tr("HUD_HINT")
    add_child(_hint)
    _objective = _make_label(18, Color(1.0, 0.9, 0.55))
    _objective.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 14)
    _objective.grow_horizontal = Control.GROW_DIRECTION_BOTH
    add_child(_objective)
    _notice = _make_label(22, Color(1.0, 0.92, 0.6))
    _notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 70)
    _notice.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _notice.modulate.a = 0.0
    add_child(_notice)
    EventBus.notice.connect(show_notice)
    EventBus.items_moved.connect(_on_items_moved)


func _make_label(font_size: int, color: Color) -> Label:
    var l := Label.new()
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", color)
    l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    l.add_theme_constant_override("outline_size", 4)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l


func bind_player(p: Player) -> void:
    player = p


func show_notice(text: String) -> void:
    _notice.text = text
    _notice.modulate.a = 1.0
    _notice_timer = 2.6


## 目標 / 提示文字(Guide 每 0.1 秒餵;文字變了就閃一下)
func set_objective(text: String) -> void:
    if text == _objective_text:
        return
    _objective_text = text
    _objective.text = text
    if text != "":
        _objective.modulate = Color(1.6, 1.4, 1.0)
        var tw := _objective.create_tween()
        tw.tween_property(_objective, "modulate", Color.WHITE, 0.4)


func objective_text() -> String:
    return _objective_text


## 錢格的錢飛向錢包數字(2D)
func _on_items_moved(kind: String, _item: String, from: Vector3, _to: Vector3, _count: int) -> void:
    if kind != "cash" or _chips >= 12:
        return
    var cam := get_viewport().get_camera_3d()
    if cam == null:
        return
    var start := cam.unproject_position(from)
    var chip := _make_label(20, Color(0.55, 0.95, 0.45))
    chip.text = "$"
    chip.position = start
    add_child(chip)
    _chips += 1
    var end := _wallet.position + Vector2(10.0, 4.0)
    var tw := chip.create_tween()
    tw.tween_method(_step_chip.bind(chip, start, end), 0.0, 1.0, 0.35)
    tw.tween_callback(_chip_done.bind(chip))


func _step_chip(t: float, chip: Control, start: Vector2, end: Vector2) -> void:
    if is_instance_valid(chip):
        chip.position = start.lerp(end, t) + Vector2(0.0, -60.0 * sin(t * PI))


func _chip_done(chip: Control) -> void:
    _chips = maxi(_chips - 1, 0)
    if is_instance_valid(chip):
        chip.queue_free()
    _wallet.pivot_offset = _wallet.size / 2.0
    _wallet.scale = Vector2(1.25, 1.25)
    var tw := _wallet.create_tween()
    tw.tween_property(_wallet, "scale", Vector2.ONE, 0.15)


func _process(delta: float) -> void:
    if _notice_timer > 0.0:
        _notice_timer -= delta
        _notice.modulate.a = clampf(_notice_timer / 0.6, 0.0, 1.0)
    _wallet.text = tr("HUD_WALLET") % GameState.wallet
    if player == null or not is_instance_valid(player):
        return
    var carry := tr("HUD_EMPTY")
    if not player.stack.is_empty():
        carry = tr("HUD_CARRY") % [GameData.item_name(player.stack.item_id), player.stack.count, player.stack.capacity]
    else:
        carry = "%s(%d)" % [carry, player.stack.capacity]
    _info.text = "%s\n%s" % [carry, tr("HUD_STATS") % [GameState.cash_earned, GameState.fish_caught, GameState.items_sold,
            GameState.items_trashed, GameState.hired_count("fisher"), GameState.hired_count("porter"),
            GameState.hired_count("cashier"), GameState.upgrade_level("worker_speed"), GameState.upgrade_level("pile_cap")]]
