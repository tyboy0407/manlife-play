class_name Hud
extends CanvasLayer
## HUD:左上角錢包 / 背包內容 / 累計,上方目標 / 提示文字(Guide 餵),通知(淡出),下方操作提示(鍵盤版或觸控版);
## 右上角選單鈕(提示箭頭 / 音效 / 重新開始)取代 H 與 F9;浮動觸控搖桿(TouchJoystick)鋪滿畫面最底層。
## 現金飛向錢包:聽 items_moved kind "cash",把 3D 位置投影到螢幕,生一個 "$" 飛到錢包數字再彈一下。
## 只讀狀態,不改遊戲;音效開關自己處理,其他選單動作用 action 訊號交給關卡。

signal action(id: String)   # "hints" / "new_game"

var player: Player = null
var joystick: TouchJoystick
var menu_button: Button
var menu_panel: PanelContainer

var _wallet: Label
var _info: Label
var _hint: Label
var _notice: Label
var _objective: Label
var _hints_btn: Button
var _sound_btn: Button
var _quality_btn: Button
var _fps_btn: Button
var _new_game_btn: Button
var _fps: Label
var _notice_timer := 0.0
var _objective_text := ""
var _chips := 0
var _confirm_new_game := false
var _fps_timer := 0.0


func _ready() -> void:
    layer = 4
    joystick = TouchJoystick.new()
    joystick.name = "Joystick"
    add_child(joystick)
    _wallet = _make_label(26, Color(1.0, 0.88, 0.45))
    _wallet.position = Vector2(14, 10)
    add_child(_wallet)
    _info = _make_label(16, Color(0.95, 0.97, 1.0))
    _info.position = Vector2(14, 48)
    add_child(_info)
    _fps = _make_label(15, Color(0.6, 1.0, 0.6))
    _fps.position = Vector2(14, 104)
    _fps.visible = Settings.show_fps
    add_child(_fps)
    _objective = _make_label(20, Color(1.0, 0.9, 0.55))
    _wide(_objective, 136, 96)
    _objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    add_child(_objective)
    _notice = _make_label(22, Color(1.0, 0.92, 0.6))
    _wide(_notice, 210, 14)
    _notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _notice.modulate.a = 0.0
    add_child(_notice)
    _hint = _make_label(14, Color(0.8, 0.85, 0.95))
    _hint.anchor_left = 0.0
    _hint.anchor_right = 1.0
    _hint.anchor_top = 1.0
    _hint.anchor_bottom = 1.0
    _hint.offset_left = 14
    _hint.offset_right = -14
    _hint.offset_top = -14
    _hint.offset_bottom = -14
    _hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
    _hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _hint.text = tr("HUD_HINT_TOUCH") if is_touch_device() else tr("HUD_HINT")
    add_child(_hint)
    _build_menu()
    joystick.exclusions = [menu_button, menu_panel]
    EventBus.notice.connect(show_notice)
    EventBus.items_moved.connect(_on_items_moved)


## 手機 / 平板 / 觸控螢幕:提示文字講觸控,不講鍵盤
static func is_touch_device() -> bool:
    return Settings.is_touch_device()


## 橫跨整個寬度的一行(左右各留 margin,top 是從上緣算的位置),高度跟著內容長
static func _wide(c: Control, top: float, margin: float) -> void:
    c.anchor_left = 0.0
    c.anchor_right = 1.0
    c.anchor_top = 0.0
    c.anchor_bottom = 0.0
    c.offset_left = margin
    c.offset_right = -margin
    c.offset_top = top
    c.offset_bottom = top
    c.grow_vertical = Control.GROW_DIRECTION_END


## 靠右上角的控制項:寬度不夠時往左長,不會跑出畫面
static func _top_right(c: Control, width: float, height: float, top: float, margin: float) -> void:
    c.anchor_left = 1.0
    c.anchor_right = 1.0
    c.anchor_top = 0.0
    c.anchor_bottom = 0.0
    c.offset_right = -margin
    c.offset_left = -margin - width
    c.offset_top = top
    c.offset_bottom = top + height
    c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    c.grow_vertical = Control.GROW_DIRECTION_END


func _make_label(font_size: int, color: Color) -> Label:
    var l := Label.new()
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", color)
    l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    l.add_theme_constant_override("outline_size", 4)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l


func _make_button(text: String, id: String) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(236, 56)
    b.add_theme_font_size_override("font_size", 20)
    b.pressed.connect(menu_action.bind(id))
    return b


## 右上角選單鈕 + 面板(提示箭頭 / 音效 / 重新開始 / 關閉)
func _build_menu() -> void:
    menu_button = Button.new()
    menu_button.name = "MenuButton"
    menu_button.text = tr("MENU_BUTTON")
    menu_button.add_theme_font_size_override("font_size", 20)
    _top_right(menu_button, 76, 56, 12, 14)
    menu_button.pressed.connect(menu_action.bind("toggle"))
    add_child(menu_button)
    menu_panel = PanelContainer.new()
    menu_panel.name = "MenuPanel"
    menu_panel.custom_minimum_size = Vector2(260, 0)   # 比按鈕寬一點,面板不用靠自動長大就放得下
    _top_right(menu_panel, 260, 0, 80, 14)
    menu_panel.visible = false
    add_child(menu_panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 8)
    menu_panel.add_child(box)
    _hints_btn = _make_button("", "hints")
    box.add_child(_hints_btn)
    _sound_btn = _make_button("", "sound")
    box.add_child(_sound_btn)
    _quality_btn = _make_button("", "quality")
    box.add_child(_quality_btn)
    _fps_btn = _make_button("", "fps")
    box.add_child(_fps_btn)
    _new_game_btn = _make_button("", "new_game")
    box.add_child(_new_game_btn)
    box.add_child(_make_button(tr("MENU_CLOSE"), "close"))
    _refresh_menu_labels()


func _refresh_menu_labels() -> void:
    _hints_btn.text = tr("MENU_HINTS_ON") if GameState.hints_on else tr("MENU_HINTS_OFF")
    _sound_btn.text = tr("MENU_SOUND_ON") if Sfx.enabled else tr("MENU_SOUND_OFF")
    _quality_btn.text = tr("MENU_QUALITY_SMOOTH") if Settings.is_smooth() else tr("MENU_QUALITY_FINE")
    _fps_btn.text = tr("MENU_FPS_ON") if Settings.show_fps else tr("MENU_FPS_OFF")
    _new_game_btn.text = tr("MENU_NEW_GAME_CONFIRM") if _confirm_new_game else tr("MENU_NEW_GAME")


func menu_open() -> bool:
    return menu_panel.visible


func confirming_new_game() -> bool:
    return _confirm_new_game


## 選單動作(按鈕與測試都走這裡):toggle 開關面板、sound 自己處理、hints / new_game 交給關卡,new_game 要按兩次
func menu_action(id: String) -> void:
    match id:
        "toggle":
            menu_panel.visible = not menu_panel.visible
            _confirm_new_game = false
        "close":
            menu_panel.visible = false
            _confirm_new_game = false
        "sound":
            Sfx.set_enabled(not Sfx.enabled)
            GameState.sound_on = Sfx.enabled
        "quality":
            Settings.toggle_quality()
            EventBus.notice.emit(tr("NOTICE_QUALITY_SMOOTH" if Settings.is_smooth() else "NOTICE_QUALITY_FINE"))
        "fps":
            Settings.set_show_fps(not Settings.show_fps)
            _fps.visible = Settings.show_fps
        "hints":
            action.emit("hints")
        "new_game":
            if not _confirm_new_game:
                _confirm_new_game = true
            else:
                _confirm_new_game = false
                menu_panel.visible = false
                action.emit("new_game")
    _refresh_menu_labels()


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


func fps_visible() -> bool:
    return _fps.visible


func _process(delta: float) -> void:
    if _notice_timer > 0.0:
        _notice_timer -= delta
        _notice.modulate.a = clampf(_notice_timer / 0.6, 0.0, 1.0)
    if _fps.visible:
        _fps_timer -= delta
        if _fps_timer <= 0.0:
            _fps_timer = 0.25
            _fps.text = "FPS %d" % Engine.get_frames_per_second()
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
