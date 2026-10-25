extends CanvasLayer
## HUD:左上角背包內容 / 現金與累計,中央通知(EventBus.notice,淡出),下方操作提示。只讀狀態,不改遊戲。

var player: Player = null

var _info: Label
var _hint: Label
var _notice: Label
var _notice_timer := 0.0


func _ready() -> void:
    layer = 4
    _info = _make_label(16, Color(0.95, 0.97, 1.0))
    _info.position = Vector2(14, 12)
    add_child(_info)
    _hint = _make_label(13, Color(0.8, 0.85, 0.95))
    _hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 14)
    _hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
    _hint.text = tr("HUD_HINT")
    add_child(_hint)
    _notice = _make_label(22, Color(1.0, 0.92, 0.6))
    _notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 70)
    _notice.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _notice.modulate.a = 0.0
    add_child(_notice)
    EventBus.notice.connect(show_notice)


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


func _process(delta: float) -> void:
    if _notice_timer > 0.0:
        _notice_timer -= delta
        _notice.modulate.a = clampf(_notice_timer / 0.6, 0.0, 1.0)
    if player == null or not is_instance_valid(player):
        return
    var carry := tr("HUD_EMPTY")
    if not player.stack.is_empty():
        carry = tr("HUD_CARRY") % [GameData.item_name(player.stack.item_id), player.stack.count, player.stack.capacity]
    else:
        carry = "%s(%d)" % [carry, player.stack.capacity]
    _info.text = "%s\n%s" % [carry, tr("HUD_STATS") % [GameState.cash_earned, GameState.fish_caught, GameState.items_sold,
            GameState.hired_count("fisher")]]
