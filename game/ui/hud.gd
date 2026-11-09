class_name Hud
extends CanvasLayer
## HUD:左上角錢包 / 背包內容 / 累計,上方目標 / 提示文字(Guide 餵),通知(淡出),下方操作提示(鍵盤版或觸控版);
## 右上角選單鈕(提示箭頭 / 音效 / 重新開始)取代 H 與 F9;浮動觸控搖桿(TouchJoystick)鋪滿畫面最底層。
## 現金飛向錢包:聽 items_moved kind "cash",把 3D 位置投影到螢幕,生一個 "$" 飛到錢包數字再彈一下。
## 只讀狀態,不改遊戲;音效開關自己處理,其他選單動作用 action 訊號交給關卡。
## 訂單一行(set_order,關卡餵)在資源行下方;選單多三個面板:地圖(show_map,資料由關卡的 map_source 給,拼齊三片有「回村」鈕 action map_home)、
## 玩法說明(show_help,分頁 HELP_*)、新版內容(show_changelog,data/changelog.json)。

signal action(id: String)   # "hints" / "new_game" / "offline_claim" / "map_home"

var player: Player = null
var joystick: TouchJoystick
var menu_button: Button
var menu_panel: PanelContainer
var offline_panel: PanelContainer   # 離線收益面板(回來時彈出,領取前遊戲暫停)
var choice_panel: PanelContainer    # 三選一面板(熊王寶箱),選之前遊戲暫停
var income_rate := 0.0              # 每秒收入速率(關卡每幀餵,統計面板顯示)
var map_source: Callable = Callable()   # 關卡給的地圖資料(Harbor.map_data)
var map_panel: PanelContainer = null
var help_panel: PanelContainer = null
var changelog_panel: PanelContainer = null

var _wallet: Label
var _info: Label
var _hint: Label
var _notice: Label
var _objective: Label
var _hints_btn: Button
var _sound_btn: Button
var _quality_btn: Button
var _fps_btn: Button
var _fx_btn: Button                        # 特效開關(震動 / 閃光 / 停格)
var _flash_rect: ColorRect                 # 大事件的全畫面閃光(Juice 叫 flash)
var _new_game_btn: Button
var _fps: Label
var _stats: Label            # 詳細統計(收進選單面板)
var _offline_dim: ColorRect
var _offline_body: Label
var _offline_cash := 0
var _choice_title: Label
var _choice_body: Label
var _choice_box: VBoxContainer
var _choice_buttons: Array[Button] = []
var _warning: Label                 # 北極熊王來襲倒數(目標文字下方,紅字)
var _order: Label                   # 碼頭訂單(資源行下方)
var _map_title: Label
var _map_canvas: Control
var _map_home_btn: Button
var _map_hint: Label
var _help_tabs: TabContainer
var _changelog_title: Label
var _changelog_body: Label
var story_panel: PanelContainer = null     # 章節短文(故事解鎖時彈)
var journal_panel: PanelContainer = null   # 日誌頁(選單)
var _story_title: Label
var _story_body: Label
var _journal_box: VBoxContainer
var tower_panel: PanelContainer = null     # 守衛塔升級(站在塔旁 5 秒)
var _tower_body: Label
var _tower_rate_btn: Button
var _tower_dmg_btn: Button
var _upgrade_btn: Button                   # 走到守衛塔旁出現的「升級」鈕(畫面下方中央)
var legacy_panel: PanelContainer = null    # 傳承 / 過冬面板(火堆或選單開):本輪分數、火種清單、過冬鈕(按兩次)
var _legacy_body: Label
var _legacy_box: VBoxContainer
var _legacy_buttons: Array[Button] = []
var _legacy_rebirth_btn: Button
var _legacy_cache := {}
var _confirm_rebirth := false
var _map_cache := {}                # 上次 show_map 拿到的地圖資料
var _notice_timer := 0.0
var _notice_queue: Array[String] = []   # 一秒內連來好幾則通知(撿毛皮 ×3)時排隊,不把前一則蓋掉
var _objective_text := ""
var _chips := 0
var _chip_pool: Array[Label] = []   # 飛完的 $(藏著,下次重用)
var _wallet_shown := -1             # 上次畫的錢包數字(沒變就不重排文字)
var _info_key := ""                 # 上次畫的背包 / 資源狀態(沒變就不重排文字)
var _tabs: TabContainer
var _stat_pages: Array[Label] = []
var _confirm_new_game := false
var _fps_timer := 0.0
var _stats_timer := 0.0
var _hud_box: PanelContainer               # 左上角 HUD 區塊(半透明底):錢包 / 背包 / 資源小籤 / 訂單小卡
var _res_chips := {}                       # 資源小籤 pelt / tooth / rarefish / weapon -> Label
var _order_card: PanelContainer
var _toast: CenterContainer                # 通知 toast(置中深底圓角),淡出用它的 modulate
var _toast_panel: PanelContainer
var _hint_timer := HINT_SEC                # 底部操作提示開局 HINT_SEC 秒後淡出(玩法說明裡還看得到)
var _pulse_t := 0.0                        # 守衛塔「升級」鈕的脈動
var stats_panel: PanelContainer = null     # 統計頁(從選單搬出來):三個分頁 + 關閉

const HINT_SEC := 30.0
const CHIP_COLORS := {"pelt": Color(0.72, 0.46, 0.26), "tooth": Color(0.92, 0.9, 0.8), "rarefish": Color(1.0, 0.8, 0.2), "weapon": Color(0.6, 0.72, 0.9)}


func _ready() -> void:
    layer = 4
    joystick = TouchJoystick.new()
    joystick.name = "Joystick"
    add_child(joystick)
    _flash_rect = ColorRect.new()
    _flash_rect.name = "Flash"
    _flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _flash_rect.color = Color(1, 1, 1, 0)
    add_child(_flash_rect)
    _build_hud_box()
    _fps = _make_label(15, Color(0.6, 1.0, 0.6))
    _fps.position = Vector2(14, 164)
    _fps.visible = Settings.show_fps
    add_child(_fps)
    _objective = _make_label(20, Color(1.0, 0.9, 0.55))
    _wide(_objective, 150, 96)
    _objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    add_child(_objective)
    _toast = CenterContainer.new()
    _toast.name = "Toast"
    _wide(_toast, 236, 14)
    _toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _toast.modulate.a = 0.0
    add_child(_toast)
    _toast_panel = PanelContainer.new()
    _toast_panel.add_theme_stylebox_override("panel", UiTheme.toast_style())
    _toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _toast.add_child(_toast_panel)
    _notice = _make_label(19, Color(1.0, 0.94, 0.7))
    _notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _notice.custom_minimum_size = Vector2(300, 0)
    _toast_panel.add_child(_notice)
    _hint = _make_label(15, Color(0.85, 0.9, 0.98))
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
    _warning = _make_label(20, Color(1.0, 0.45, 0.4))
    _wide(_warning, 200, 14)
    _warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _warning.visible = false
    add_child(_warning)
    _build_menu()
    _build_offline_panel()
    _build_choice_panel()
    _build_map_panel()
    _build_help_panel()
    _build_changelog_panel()
    _build_story_panel()
    _build_journal_panel()
    _build_tower_panel()
    _build_legacy_panel()
    _build_stats_panel()
    _upgrade_btn = Button.new()
    _upgrade_btn.name = "UpgradeButton"
    _upgrade_btn.text = tr("MENU_UPGRADE_TOWER")
    UiTheme.style_button(_upgrade_btn, "primary", 22)
    _upgrade_btn.anchor_left = 0.5
    _upgrade_btn.anchor_right = 0.5
    _upgrade_btn.anchor_top = 1.0
    _upgrade_btn.anchor_bottom = 1.0
    _upgrade_btn.offset_left = -80
    _upgrade_btn.offset_right = 80
    _upgrade_btn.offset_top = -132
    _upgrade_btn.offset_bottom = -72
    _upgrade_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _upgrade_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
    _upgrade_btn.visible = false
    _upgrade_btn.pressed.connect(panel_action.bind("tower_upgrade_open"))
    add_child(_upgrade_btn)
    joystick.exclusions = [menu_button, menu_panel, offline_panel, choice_panel, map_panel, help_panel, changelog_panel, story_panel, journal_panel, tower_panel,
        legacy_panel, stats_panel, _upgrade_btn]
    EventBus.notice.connect(show_notice)
    EventBus.items_moved.connect(_on_items_moved)
    UiTheme.attach_press_fx(self)   # 所有按鈕:按下縮一下 + tap 音效(之後動態生的卡片 / 清單列自己接)


## 左上角 HUD 區塊:錢包大字、背包一行、四個資源小籤、訂單小卡;整塊半透明深底,不再和 3D 標籤打架
func _build_hud_box() -> void:
    _hud_box = PanelContainer.new()
    _hud_box.name = "HudBox"
    _hud_box.position = Vector2(10, 10)
    _hud_box.add_theme_stylebox_override("panel", UiTheme.hud_style())
    _hud_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_hud_box)
    var box := VBoxContainer.new()
    box.name = "Box"
    box.add_theme_constant_override("separation", 4)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _hud_box.add_child(box)
    _wallet = _make_label(28, UiTheme.GOLD)
    _wallet.name = "Wallet"
    box.add_child(_wallet)
    _info = _make_label(15, UiTheme.TEXT)
    _info.name = "Carry"
    box.add_child(_info)
    var chips := HBoxContainer.new()
    chips.name = "Chips"
    chips.add_theme_constant_override("separation", 6)
    chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_child(chips)
    for kind in CHIP_COLORS:
        var c := UiTheme.chip("", CHIP_COLORS[kind], 14)
        c.name = "Chip_" + str(kind)
        chips.add_child(c)
        _res_chips[kind] = c
    _order_card = PanelContainer.new()
    _order_card.name = "OrderCard"
    _order_card.add_theme_stylebox_override("panel", UiTheme.card_style(Color(0.45, 0.7, 1.0)))
    _order_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _order_card.visible = false
    box.add_child(_order_card)
    _order = _make_label(15, Color(0.84, 0.94, 1.0))
    _order.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _order.custom_minimum_size = Vector2(280, 0)
    _order_card.add_child(_order)


## 面板裡的一般文字(沒有描邊;描邊的 _make_label 是給疊在 3D 畫面上的 HUD 文字)
func _plain(font_size: int, color: Color) -> Label:
    var l := Label.new()
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", color)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l


## 大事件的全畫面閃光(Juice:王倒下);sec 秒內淡掉
func flash(color: Color, sec: float) -> void:
    _flash_rect.color = color
    var tw := _flash_rect.create_tween()
    tw.tween_property(_flash_rect, "color:a", 0.0, maxf(sec, 0.05)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func flash_alpha() -> float:
    return _flash_rect.color.a


## 收到錢:錢包數字彈一下(TRANS_BACK 回到 1)
func pop_wallet() -> void:
    _wallet.pivot_offset = Vector2(0, _wallet.size.y / 2.0)
    _wallet.scale = Vector2(1.18, 1.18)
    var tw := _wallet.create_tween()
    tw.tween_property(_wallet, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 背包那行 + 四個資源小籤(測試用)
func info_text() -> String:
    var parts: Array[String] = [_info.text]
    for k in _res_chips:
        parts.append((_res_chips[k] as Label).text)
    return "\n".join(parts)


func hint_visible() -> bool:
    return _hint.modulate.a > 0.05


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


func _make_button(text: String, id: String, width: float = 240.0, font_size: int = 18) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(width, UiTheme.BUTTON_H)
    UiTheme.style_button(b, "secondary", font_size)
    b.pressed.connect(menu_action.bind(id))
    return b


## 選單上排的方格開關:兩行字(名稱 / 狀態),開著綠底、關著灰底
func _toggle_button(id: String) -> Button:
    var b := Button.new()
    b.name = "Toggle_" + id
    b.custom_minimum_size = Vector2(50, 56)
    UiTheme.style_button(b, "toggle_off", 13)
    b.pressed.connect(menu_action.bind(id))
    return b


func _set_toggle(b: Button, label: String, on: bool, state: String) -> void:
    b.text = "%s\n%s" % [label, state]
    UiTheme.style_button(b, "toggle_on" if on else "toggle_off", 13)


## 右上角選單鈕 + 面板:上排四格開關(提示箭頭 / 音效 / 畫質 / FPS)、中間 2 × 3 頁面格(地圖 / 說明 / 日誌 / 統計 / 火種 / 新版)、
## 最底「重新開始」紅色獨立一顆 + 關閉;統計搬到自己的面板
func _build_menu() -> void:
    menu_button = Button.new()
    menu_button.name = "MenuButton"
    menu_button.text = tr("MENU_BUTTON")
    UiTheme.style_button(menu_button, "secondary", 20)
    _top_right(menu_button, 76, 56, 12, 14)
    menu_button.pressed.connect(menu_action.bind("toggle"))
    add_child(menu_button)
    menu_panel = PanelContainer.new()
    menu_panel.name = "MenuPanel"
    menu_panel.custom_minimum_size = Vector2(300, 0)   # 比內容寬一點(五格開關 5 × 50 + 4 × 8),面板不用靠自動長大就放得下
    menu_panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
    _top_right(menu_panel, 300, 0, 80, 14)
    menu_panel.visible = false
    add_child(menu_panel)
    var box := VBoxContainer.new()
    box.name = "Box"
    box.add_theme_constant_override("separation", 10)
    menu_panel.add_child(box)
    var toggles := GridContainer.new()
    toggles.name = "Toggles"
    toggles.columns = 5
    toggles.add_theme_constant_override("h_separation", 8)
    box.add_child(toggles)
    _hints_btn = _toggle_button("hints")
    _sound_btn = _toggle_button("sound")
    _fx_btn = _toggle_button("fx")
    _quality_btn = _toggle_button("quality")
    _fps_btn = _toggle_button("fps")
    for b in [_hints_btn, _sound_btn, _fx_btn, _quality_btn, _fps_btn]:
        toggles.add_child(b)
    box.add_child(UiTheme.divider())
    var pages := GridContainer.new()
    pages.name = "Pages"
    pages.columns = 2
    pages.add_theme_constant_override("h_separation", 8)
    pages.add_theme_constant_override("v_separation", 8)
    box.add_child(pages)
    for e in [["MENU_MAP", "map"], ["MENU_HELP", "help"], ["MENU_JOURNAL", "journal"], ["MENU_STATS", "stats"], ["MENU_LEGACY", "legacy"], ["MENU_CHANGELOG", "changelog"]]:
        pages.add_child(_make_button(tr(e[0]), e[1], 132, 16))
    box.add_child(UiTheme.divider())
    _new_game_btn = _make_button("", "new_game", 272, 16)
    UiTheme.style_button(_new_game_btn, "danger", 16)
    box.add_child(_new_game_btn)
    box.add_child(_make_button(tr("MENU_CLOSE"), "close", 272, 18))
    _refresh_menu_labels()


func _refresh_menu_labels() -> void:
    _set_toggle(_hints_btn, tr("MENU_T_HINTS"), GameState.hints_on, tr("MENU_ON") if GameState.hints_on else tr("MENU_OFF"))
    _set_toggle(_sound_btn, tr("MENU_T_SOUND"), Sfx.enabled, tr("MENU_ON") if Sfx.enabled else tr("MENU_OFF"))
    _set_toggle(_fx_btn, tr("MENU_T_FX"), Settings.fx_on, tr("MENU_ON") if Settings.fx_on else tr("MENU_OFF"))
    _set_toggle(_quality_btn, tr("MENU_T_QUALITY"), not Settings.is_smooth(), tr("MENU_Q_SMOOTH") if Settings.is_smooth() else tr("MENU_Q_FINE"))
    _set_toggle(_fps_btn, tr("MENU_T_FPS"), Settings.show_fps, tr("MENU_ON") if Settings.show_fps else tr("MENU_OFF"))
    _new_game_btn.text = tr("MENU_NEW_GAME_CONFIRM") if _confirm_new_game else tr("MENU_NEW_GAME")


## 統計頁(從選單搬出來):三個分頁(經濟 / 幫手與熊 / 王與券),開著每 0.5 秒重算
func _build_stats_panel() -> void:
    var parts := _centered_panel("StatsPanel", 420, "STATS_TITLE")
    stats_panel = parts["panel"]
    var box: VBoxContainer = parts["box"]
    _tabs = TabContainer.new()
    _tabs.name = "StatsTabs"
    _tabs.custom_minimum_size = Vector2(392, 0)
    box.add_child(_tabs)
    for key in ["TAB_economy", "TAB_helpers", "TAB_king"]:
        var l := _plain(16, UiTheme.TEXT)
        l.name = tr(key)
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        l.custom_minimum_size = Vector2(380, 0)
        _tabs.add_child(l)
        _stat_pages.append(l)
    _stats = _stat_pages[0]
    box.add_child(_close_button("stats_close"))


func show_stats() -> void:
    _refresh_stats()
    _stats_timer = 0.5
    menu_panel.visible = false
    stats_panel.visible = true


func stats_open() -> bool:
    return stats_panel != null and stats_panel.visible


func menu_open() -> bool:
    return menu_panel.visible


## 離線收益面板:置中,整個畫面蓋一層半透明黑擋住觸控;領取鈕走 offline_action
func _build_offline_panel() -> void:
    _offline_dim = ColorRect.new()
    _offline_dim.name = "OfflineDim"
    _offline_dim.color = Color(0, 0, 0, 0.55)
    _offline_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _offline_dim.mouse_filter = Control.MOUSE_FILTER_STOP
    _offline_dim.visible = false
    add_child(_offline_dim)
    offline_panel = PanelContainer.new()
    offline_panel.name = "OfflinePanel"
    offline_panel.custom_minimum_size = Vector2(360, 0)
    offline_panel.anchor_left = 0.5
    offline_panel.anchor_right = 0.5
    offline_panel.anchor_top = 0.4
    offline_panel.anchor_bottom = 0.4
    offline_panel.offset_left = -180
    offline_panel.offset_right = 180
    offline_panel.offset_top = 0
    offline_panel.offset_bottom = 0
    offline_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
    offline_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
    offline_panel.visible = false
    offline_panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
    add_child(offline_panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    offline_panel.add_child(box)
    var title := Label.new()
    title.text = tr("OFFLINE_TITLE")
    title.add_theme_font_size_override("font_size", 28)
    title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)
    _offline_body = Label.new()
    _offline_body.add_theme_font_size_override("font_size", 20)
    _offline_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _offline_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(_offline_body)
    var claim := Button.new()
    claim.name = "ClaimButton"
    claim.text = tr("OFFLINE_CLAIM")
    claim.custom_minimum_size = Vector2(0, 60)
    UiTheme.style_button(claim, "primary", 24)
    claim.pressed.connect(offline_action.bind("claim"))
    box.add_child(claim)


## 置中的大面板(地圖 / 玩法說明 / 新版內容共用的外框):標題 + 內容 + 關閉鈕
func _centered_panel(name: String, width: float, title_key: String) -> Dictionary:
    var panel := PanelContainer.new()
    panel.name = name
    panel.custom_minimum_size = Vector2(width, 0)
    panel.anchor_left = 0.5
    panel.anchor_right = 0.5
    panel.anchor_top = 0.5
    panel.anchor_bottom = 0.5
    panel.offset_left = -width / 2.0
    panel.offset_right = width / 2.0
    panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
    panel.grow_vertical = Control.GROW_DIRECTION_BOTH
    panel.visible = false
    panel.add_theme_stylebox_override("panel", UiTheme.panel_style())   # 不透明深色底:面板疊在 3D 的標籤上才看得清
    add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    panel.add_child(box)
    var title := Label.new()
    title.text = tr(title_key)
    title.add_theme_font_size_override("font_size", 26)
    title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)
    box.add_child(UiTheme.divider())
    return {"panel": panel, "box": box, "title": title}


func _close_button(id: String) -> Button:
    var b := Button.new()
    b.name = "CloseButton"
    b.text = tr("MENU_CLOSE")
    b.custom_minimum_size = Vector2(0, UiTheme.BUTTON_H)
    UiTheme.style_button(b, "secondary", 18)
    b.pressed.connect(panel_action.bind(id))
    return b


## 地圖頁:畫布(_draw 畫世界)+ 回村鈕(拼齊三片才有)
func _build_map_panel() -> void:
    var parts := _centered_panel("MapPanel", 420, "MAP_TITLE")
    map_panel = parts["panel"]
    _map_title = parts["title"]
    var box: VBoxContainer = parts["box"]
    _map_canvas = Control.new()
    _map_canvas.name = "MapCanvas"
    _map_canvas.custom_minimum_size = Vector2(396, 200)
    _map_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _map_canvas.draw.connect(_draw_map)
    box.add_child(_map_canvas)
    _map_hint = Label.new()
    _map_hint.add_theme_font_size_override("font_size", 16)
    _map_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _map_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(_map_hint)
    _map_home_btn = Button.new()
    _map_home_btn.name = "MapHome"
    _map_home_btn.text = tr("MAP_HOME")
    _map_home_btn.custom_minimum_size = Vector2(0, 52)
    UiTheme.style_button(_map_home_btn, "primary", 20)
    _map_home_btn.pressed.connect(panel_action.bind("map_home"))
    box.add_child(_map_home_btn)
    box.add_child(_close_button("map_close"))


## 顯示地圖(資料從關卡的 map_source 拿);碎片 0 片只顯示說明
func show_map() -> void:
    _map_cache = map_source.call() if map_source.is_valid() else {}
    var pieces := int(_map_cache.get("pieces", 0))
    var total := int(_map_cache.get("total", 3))
    _map_title.text = tr("MAP_TITLE") % [pieces, total]
    _map_hint.text = tr("MAP_LOCKED") if pieces <= 0 else ""
    _map_hint.visible = pieces <= 0
    _map_home_btn.visible = pieces >= total
    menu_panel.visible = false
    map_panel.visible = true
    _map_canvas.queue_redraw()


func map_open() -> bool:
    return map_panel.visible


func map_home_visible() -> bool:
    return _map_home_btn.visible


## 畫世界:1 片 = 村莊(含擴建區、水區、武器店),2 片 = 加上雪原的地標(碼頭 / 商人)與探險範圍,3 片 = 加上未知區域「???」
func _draw_map() -> void:
    var c := _map_canvas
    var size := c.size
    c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.14, 0.2))
    var pieces := int(_map_cache.get("pieces", 0))
    if pieces <= 0 or not _map_cache.has("world"):
        return
    var world: Rect2 = _map_cache["world"]
    var margin := 8.0
    var k := minf((size.x - margin * 2.0) / world.size.x, (size.y - margin * 2.0) / world.size.y)
    var origin := Vector2(margin, margin) + (size - Vector2(margin * 2.0, margin * 2.0) - world.size * k) / 2.0
    var to_px := func(p: Vector2) -> Vector2: return origin + (p - world.position) * k
    var rect_px := func(r: Rect2) -> Rect2: return Rect2(to_px.call(r.position), r.size * k)
    if pieces >= 2:
        c.draw_rect(rect_px.call(world), Color(0.93, 0.95, 0.98))   # 雪原
    for r in _map_cache.get("rects", []):
        c.draw_rect(rect_px.call(r["rect"]), r["color"])
        if str(r.get("label", "")) != "":
            c.draw_string(c.get_theme_default_font(), to_px.call((r["rect"] as Rect2).position) + Vector2(2, 12), tr(str(r["label"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.1, 0.1, 0.12))
    if pieces >= 2:
        for pt in _map_cache.get("points", []):
            var px: Vector2 = to_px.call(pt["pos"])
            c.draw_circle(px, 4.0, pt["color"])
            c.draw_string(c.get_theme_default_font(), px + Vector2(6, 4), tr(str(pt.get("label", ""))), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.9, 0.95))
    if pieces >= 3:
        for u in _map_cache.get("unknown", []):
            var ur: Rect2 = u
            var clipped := Rect2(to_px.call(ur.position), ur.size * k).intersection(Rect2(Vector2.ZERO, size))
            if clipped.size.x > 0.0 and clipped.size.y > 0.0:
                c.draw_rect(clipped, Color(0.35, 0.35, 0.4, 0.8))
                c.draw_string(c.get_theme_default_font(), clipped.position + Vector2(4, clipped.size.y / 2.0), tr("MAP_UNKNOWN"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.9, 0.95))
    var pp: Vector2 = to_px.call(_map_cache.get("player", Vector2.ZERO))
    c.draw_circle(pp, 5.0, Color(0.35, 0.55, 0.95))
    c.draw_circle(pp, 5.0, Color(1, 1, 1), false, 1.5)
    c.draw_string(c.get_theme_default_font(), pp + Vector2(7, 4), tr("MAP_YOU"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1))


## 玩法說明:分頁(基本操作 / 生產鏈 / 幫手 / 熊與武器 / 擴建 / 王與其他)
func _build_help_panel() -> void:
    var parts := _centered_panel("HelpPanel", 420, "HELP_TITLE")
    help_panel = parts["panel"]
    var box: VBoxContainer = parts["box"]
    _help_tabs = TabContainer.new()
    _help_tabs.name = "HelpTabs"
    _help_tabs.custom_minimum_size = Vector2(396, 0)
    box.add_child(_help_tabs)
    for key in ["basics", "chain", "helpers", "bears", "expand", "king"]:
        var l := Label.new()
        l.name = tr("HELP_TAB_%s" % key)
        l.text = tr("HELP_%s" % key)
        l.add_theme_font_size_override("font_size", 15)
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        l.custom_minimum_size = Vector2(380, 0)
        _help_tabs.add_child(l)
    box.add_child(_close_button("help_close"))


func show_help() -> void:
    menu_panel.visible = false
    help_panel.visible = true


func help_open() -> bool:
    return help_panel.visible


func help_tab_count() -> int:
    return _help_tabs.get_tab_count()


## 新版內容:data/changelog.json 最新一版的條目
func _build_changelog_panel() -> void:
    var parts := _centered_panel("ChangelogPanel", 420, "CHANGELOG_TITLE")
    changelog_panel = parts["panel"]
    _changelog_title = parts["title"]
    var box: VBoxContainer = parts["box"]
    _changelog_body = Label.new()
    _changelog_body.add_theme_font_size_override("font_size", 16)
    _changelog_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _changelog_body.custom_minimum_size = Vector2(380, 0)
    box.add_child(_changelog_body)
    box.add_child(_close_button("changelog_close"))


func show_changelog() -> void:
    var cl := GameData.changelog()
    if cl.is_empty():
        return
    var v: Dictionary = cl[0]
    _changelog_title.text = tr("CHANGELOG_TITLE") % str(v.get("version", ""))
    var lines: Array[String] = []
    for n in v.get("notes", []):
        lines.append("• " + str(n))
    _changelog_body.text = "\n".join(lines)
    menu_panel.visible = false
    changelog_panel.visible = true


func changelog_open() -> bool:
    return changelog_panel.visible


func changelog_text() -> String:
    return _changelog_body.text


## 故事章節短文:解鎖時彈(不暫停),關了可以在日誌頁重看
func _build_story_panel() -> void:
    var parts := _centered_panel("StoryPanel", 420, "STORY_TITLE")
    story_panel = parts["panel"]
    _story_title = parts["title"]
    var box: VBoxContainer = parts["box"]
    _story_body = Label.new()
    _story_body.add_theme_font_size_override("font_size", 16)
    _story_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _story_body.custom_minimum_size = Vector2(380, 0)
    box.add_child(_story_body)
    box.add_child(_close_button("story_close"))


func show_chapter(title: String, body: String) -> void:
    _story_title.text = title
    _story_body.text = body
    menu_panel.visible = false
    story_panel.visible = true


func story_open() -> bool:
    return story_panel.visible


func story_text() -> String:
    return _story_title.text + "\n" + _story_body.text


## 日誌頁:章節(可重看)+ 線索;沒解鎖的顯示 ???
func _build_journal_panel() -> void:
    var parts := _centered_panel("JournalPanel", 420, "JOURNAL_TITLE")
    journal_panel = parts["panel"]
    var box: VBoxContainer = parts["box"]
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(396, 520)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    box.add_child(scroll)
    _journal_box = VBoxContainer.new()
    _journal_box.add_theme_constant_override("separation", 6)
    _journal_box.custom_minimum_size = Vector2(380, 0)
    scroll.add_child(_journal_box)
    box.add_child(_close_button("journal_close"))


func show_journal(chapters: Array, entries: Array) -> void:
    for c in _journal_box.get_children():
        c.queue_free()
    _journal_section(tr("JOURNAL_CHAPTERS"), chapters)
    _journal_section(tr("JOURNAL_ENTRIES"), entries)
    menu_panel.visible = false
    journal_panel.visible = true


func _journal_section(header: String, items: Array) -> void:
    var h := _make_label(18, Color(1.0, 0.88, 0.45))
    h.text = header
    _journal_box.add_child(h)
    for it in items:
        var t := _make_label(15, Color(0.95, 0.97, 1.0) if bool(it.get("unlocked", false)) else Color(0.55, 0.55, 0.6))
        t.text = "• " + str(it.get("title", ""))
        _journal_box.add_child(t)
        if bool(it.get("unlocked", false)) and str(it.get("text", "")) != "":
            var b := _make_label(14, Color(0.85, 0.87, 0.92))
            b.text = str(it.get("text", ""))
            b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            b.custom_minimum_size = Vector2(370, 0)
            _journal_box.add_child(b)


func journal_open() -> bool:
    return journal_panel.visible


## 守衛塔升級面板:射速 / 傷害各一顆按鈕(按了發 action "tower_up:rate" / "tower_up:damage",關卡扣錢並重新餵資料)
func _build_tower_panel() -> void:
    var parts := _centered_panel("TowerPanel", 380, "TOWER_UP_TITLE")
    tower_panel = parts["panel"]
    var box: VBoxContainer = parts["box"]
    _tower_body = Label.new()
    _tower_body.add_theme_font_size_override("font_size", 16)
    _tower_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _tower_body.custom_minimum_size = Vector2(340, 0)
    box.add_child(_tower_body)
    _tower_rate_btn = Button.new()
    _tower_rate_btn.name = "RateButton"
    _tower_rate_btn.custom_minimum_size = Vector2(0, 60)
    UiTheme.style_button(_tower_rate_btn, "primary", 18)
    _tower_rate_btn.pressed.connect(panel_action.bind("tower_up:rate"))
    box.add_child(_tower_rate_btn)
    _tower_dmg_btn = Button.new()
    _tower_dmg_btn.name = "DamageButton"
    _tower_dmg_btn.custom_minimum_size = Vector2(0, 60)
    UiTheme.style_button(_tower_dmg_btn, "primary", 18)
    _tower_dmg_btn.pressed.connect(panel_action.bind("tower_up:damage"))
    box.add_child(_tower_dmg_btn)
    box.add_child(_close_button("tower_close"))


## d:{id, rate, damage, max, cost, wallet, interval, dmg}
func show_tower_upgrade(d: Dictionary) -> void:
    _tower_body.text = tr("TOWER_UP_DESC") % [str(d.get("id", "")).trim_prefix("tower_"), float(d.get("interval", 0.8)), float(d.get("dmg", 10.0)), int(d.get("wallet", 0))]
    var mx := int(d.get("max", 10))
    var cost := int(d.get("cost", 500))
    var r := int(d.get("rate", 0))
    var g := int(d.get("damage", 0))
    _tower_rate_btn.text = tr("TOWER_UP_RATE") % [r, mx, cost] if r < mx else tr("TOWER_UP_RATE_MAX") % mx
    _tower_dmg_btn.text = tr("TOWER_UP_DAMAGE") % [g, mx, cost] if g < mx else tr("TOWER_UP_DAMAGE_MAX") % mx
    _tower_rate_btn.disabled = r >= mx
    _tower_dmg_btn.disabled = g >= mx
    menu_panel.visible = false
    tower_panel.visible = true


func tower_open() -> bool:
    return tower_panel.visible


## 走到守衛塔旁:顯示「升級」鈕(關卡每幀餵)
func set_upgrade_button(on: bool) -> void:
    if _upgrade_btn.visible != on:
        _upgrade_btn.visible = on


func upgrade_button_visible() -> bool:
    return _upgrade_btn.visible


func tower_text() -> String:
    return _tower_body.text + "\n" + _tower_rate_btn.text + "\n" + _tower_dmg_btn.text


func journal_text() -> String:
    var parts: Array[String] = []
    for c in _journal_box.get_children():
        if c is Label:
            parts.append((c as Label).text)
    return "\n".join(parts)


## 大面板上的按鈕(與測試)都走這裡
func panel_action(id: String) -> void:
    match id:
        "map_close":
            map_panel.visible = false
        "help_close":
            help_panel.visible = false
        "changelog_close":
            changelog_panel.visible = false
        "story_close":
            story_panel.visible = false
        "tower_close":
            tower_panel.visible = false
        "tower_up:rate", "tower_up:damage", "tower_upgrade_open":
            action.emit(id)
        "journal_close":
            journal_panel.visible = false
        "legacy_close":
            legacy_panel.visible = false
            _confirm_rebirth = false
        "stats_close":
            stats_panel.visible = false
        "legacy_rebirth":
            if not _confirm_rebirth:
                _confirm_rebirth = true
                _refresh_rebirth_button()
            else:
                _confirm_rebirth = false
                legacy_panel.visible = false
                action.emit("legacy_rebirth")
        "map_home":
            if map_panel.visible and _map_home_btn.visible:
                map_panel.visible = false
                action.emit("map_home")
        _:
            if id.begins_with("legacy_buy:"):
                action.emit(id)


## --- 傳承 / 過冬面板 ---

func _build_legacy_panel() -> void:
    var parts := _centered_panel("LegacyPanel", 420, "LEGACY_TITLE")
    legacy_panel = parts["panel"]
    var box: VBoxContainer = parts["box"]
    _legacy_body = Label.new()
    _legacy_body.add_theme_font_size_override("font_size", 16)
    _legacy_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _legacy_body.custom_minimum_size = Vector2(380, 0)
    box.add_child(_legacy_body)
    _legacy_box = VBoxContainer.new()
    _legacy_box.add_theme_constant_override("separation", 8)   # 觸控目標之間至少 8px
    box.add_child(_legacy_box)
    _legacy_rebirth_btn = Button.new()
    _legacy_rebirth_btn.name = "RebirthButton"
    _legacy_rebirth_btn.custom_minimum_size = Vector2(0, 56)
    UiTheme.style_button(_legacy_rebirth_btn, "primary", 18)
    _legacy_rebirth_btn.pressed.connect(panel_action.bind("legacy_rebirth"))
    box.add_child(_legacy_rebirth_btn)
    box.add_child(_close_button("legacy_close"))


## 火種數值的顯示:起始資金 $、熊延後秒、背包件、離線小時,其他百分比
func legacy_fmt(id: String, v: float) -> String:
    match id:
        "start_cash":
            return "+$%d" % int(round(v))
        "bear_delay":
            return tr("LEGACY_SEC") % int(round(v))
        "capacity":
            return tr("LEGACY_ITEMS") % int(round(v))
        "offline_max":
            return tr("LEGACY_HOURS") % (v / 3600.0)
        _:
            return "+%d%%" % int(round(v * 100.0))


## d 見 Harbor.legacy_data:{generation, points, score, gain, low, perks}
func show_legacy(d: Dictionary) -> void:
    _legacy_cache = d.duplicate(true)
    var sc: Dictionary = d.get("score", {})
    var low := bool(d.get("low", false))
    var text: String = tr("LEGACY_BODY") % [int(d.get("generation", 1)), int(d.get("points", 0)), int(sc.get("income", 0)), int(sc.get("build", 0)),
            int(sc.get("battle", 0)), int(sc.get("story", 0)), int(sc.get("total", 0)), int(d.get("gain", 0))]
    if low:
        text += "\n" + tr("LEGACY_LOW")
    _legacy_body.text = text
    _legacy_body.add_theme_color_override("font_color", Color(1.0, 0.6, 0.55) if low else Color(0.95, 0.97, 1.0))
    var perks: Array = d.get("perks", [])
    while _legacy_buttons.size() < perks.size():
        var b := _legacy_row_button(_legacy_buttons.size())
        _legacy_box.add_child(b)
        _legacy_buttons.append(b)
    for i in _legacy_buttons.size():
        var b := _legacy_buttons[i]
        b.visible = i < perks.size()
        if i >= perks.size():
            continue
        var p: Dictionary = perks[i]
        var id := str(p.get("id", ""))
        var lv := int(p.get("level", 0))
        var mx := int(p.get("max", 0))
        var cost := int(p.get("cost", -1))
        var per := float(p.get("per", 0.0))
        var pname := tr("LEGACY_PERK_%s" % id)
        var now_s := legacy_fmt(id, per * float(lv))
        var row_text: String = (tr("LEGACY_PERK_ROW") % [pname, lv, mx, now_s, legacy_fmt(id, per), cost]) if cost >= 0 else (tr("LEGACY_PERK_MAX") % [pname, lv, mx, now_s])
        b.set_meta("row_text", row_text)
        (b.get_node("Row/Col/Name") as Label).text = tr("LEGACY_ROW_NAME") % [pname, lv, mx]
        (b.get_node("Row/Col/Sub") as Label).text = tr("LEGACY_ROW_SUB") % [now_s, legacy_fmt(id, per)]
        (b.get_node("Row/Cost") as Label).text = (tr("LEGACY_ROW_COST") % cost) if cost >= 0 else tr("LEGACY_ROW_MAXED")
        b.disabled = cost < 0 or not bool(p.get("affordable", false))
    _confirm_rebirth = false
    _refresh_rebirth_button()
    menu_panel.visible = false
    legacy_panel.visible = true


## 火種清單的一列:左邊名稱 + Lv、下面目前 / 每級加成,右邊點數價;整列是按鈕,完整文字存 meta row_text 給 legacy_text
func _legacy_row_button(idx: int) -> Button:
    var b := Button.new()
    b.name = "Perk%d" % idx
    b.custom_minimum_size = Vector2(0, 54)
    UiTheme.style_button(b, "row", 15)
    UiTheme.press_fx(b)
    b.pressed.connect(func() -> void: legacy_action(idx))
    var row := HBoxContainer.new()
    row.name = "Row"
    row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    row.offset_left = 12
    row.offset_right = -12
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(row)
    var col := VBoxContainer.new()
    col.name = "Col"
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    col.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(col)
    var nm := _plain(16, UiTheme.TEXT)
    nm.name = "Name"
    col.add_child(nm)
    var sub := _plain(14, UiTheme.TEXT_DIM)
    sub.name = "Sub"
    col.add_child(sub)
    var cost := _plain(16, UiTheme.PRIMARY.lightened(0.25))
    cost.name = "Cost"
    cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(cost)
    return b


func _refresh_rebirth_button() -> void:
    _legacy_rebirth_btn.text = tr("LEGACY_REBIRTH_CONFIRM") if _confirm_rebirth else tr("LEGACY_REBIRTH") % int(_legacy_cache.get("gain", 0))
    UiTheme.style_button(_legacy_rebirth_btn, "danger" if _confirm_rebirth else "primary", 18)   # 第二下是危險動作,換紅色


## 按第 i 列火種:發 action "legacy_buy:<id>"(關卡扣點數後再 show_legacy 刷新)
func legacy_action(i: int) -> void:
    var perks: Array = _legacy_cache.get("perks", [])
    if i < 0 or i >= perks.size():
        return
    panel_action("legacy_buy:%s" % str((perks[i] as Dictionary).get("id", "")))


func legacy_open() -> bool:
    return legacy_panel != null and legacy_panel.visible


func legacy_perk_count() -> int:
    var n := 0
    for b in _legacy_buttons:
        if b.visible:
            n += 1
    return n


func confirming_rebirth() -> bool:
    return _confirm_rebirth


func legacy_text() -> String:
    var parts: Array[String] = [_legacy_body.text]
    for b in _legacy_buttons:
        if b.visible:
            parts.append(str(b.get_meta("row_text", b.text)))
    parts.append(_legacy_rebirth_btn.text)
    return "\n".join(parts)


## 碼頭訂單那一行("" = 隱藏)
func set_order(text: String) -> void:
    _order.text = text
    _order.visible = text != ""
    _order_card.visible = text != ""


func order_text() -> String:
    return _order.text if _order.visible else ""


## 三選一面板(熊王寶箱):標題 + 說明 + N 個按鈕,按了發 action "choice:<i>"
func _build_choice_panel() -> void:
    choice_panel = PanelContainer.new()
    choice_panel.name = "ChoicePanel"
    choice_panel.custom_minimum_size = Vector2(380, 0)
    choice_panel.anchor_left = 0.5
    choice_panel.anchor_right = 0.5
    choice_panel.anchor_top = 0.35
    choice_panel.anchor_bottom = 0.35
    choice_panel.offset_left = -190
    choice_panel.offset_right = 190
    choice_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
    choice_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
    choice_panel.visible = false
    choice_panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
    add_child(choice_panel)
    _choice_box = VBoxContainer.new()
    _choice_box.add_theme_constant_override("separation", 12)
    choice_panel.add_child(_choice_box)
    _choice_title = Label.new()
    _choice_title.add_theme_font_size_override("font_size", 28)
    _choice_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
    _choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _choice_box.add_child(_choice_title)
    _choice_body = Label.new()
    _choice_body.add_theme_font_size_override("font_size", 18)
    _choice_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _choice_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _choice_box.add_child(_choice_body)


## cards:每張 {title, desc, color};畫成「色塊 + 標題 + 說明」的卡片,整張卡就是按鈕
func show_choice(title: String, body: String, cards: Array) -> void:
    for b in _choice_buttons:
        b.queue_free()
    _choice_buttons.clear()
    _choice_title.text = title
    _choice_body.text = body
    for i in cards.size():
        var c: Dictionary = cards[i] if typeof(cards[i]) == TYPE_DICTIONARY else {"title": str(cards[i])}
        var b := Button.new()
        b.name = "Choice%d" % i
        b.custom_minimum_size = Vector2(0, 68)
        UiTheme.style_button(b, "row", 16)
        UiTheme.press_fx(b)
        b.pressed.connect(choice_action.bind(i))
        var row := HBoxContainer.new()
        row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        row.offset_left = 10
        row.offset_right = -10
        row.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_theme_constant_override("separation", 12)
        b.add_child(row)
        var swatch := ColorRect.new()
        swatch.color = c.get("color", Color(0.7, 0.7, 0.7))
        swatch.custom_minimum_size = Vector2(26, 26)
        swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_child(swatch)
        var col := VBoxContainer.new()
        col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        col.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_child(col)
        var t := Label.new()
        t.text = str(c.get("title", ""))
        t.add_theme_font_size_override("font_size", 22)
        t.add_theme_color_override("font_color", c.get("color", Color(1, 1, 1)).lightened(0.3))
        t.mouse_filter = Control.MOUSE_FILTER_IGNORE
        col.add_child(t)
        var d := Label.new()
        d.text = str(c.get("desc", ""))
        d.add_theme_font_size_override("font_size", 14)
        d.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
        d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        d.mouse_filter = Control.MOUSE_FILTER_IGNORE
        col.add_child(d)
        _choice_box.add_child(b)
        _choice_buttons.append(b)
    menu_panel.visible = false
    _offline_dim.visible = true
    choice_panel.visible = true


func choice_open() -> bool:
    return choice_panel.visible


func choice_count() -> int:
    return _choice_buttons.size()


## 第 i 張卡的標題(給測試)
func choice_title(i: int) -> String:
    if i < 0 or i >= _choice_buttons.size():
        return ""
    return (_choice_buttons[i].get_child(0).get_child(1).get_child(0) as Label).text


## 按了第 i 個選項(與測試)
func choice_action(i: int) -> void:
    if not choice_panel.visible:
        return
    choice_panel.visible = false
    _offline_dim.visible = offline_panel.visible
    action.emit("choice:%d" % i)


## 北極熊王來襲倒數等警告文字("" = 隱藏)
func set_warning(text: String) -> void:
    _warning.text = text
    _warning.visible = text != ""


func warning_text() -> String:
    return _warning.text if _warning.visible else ""


## 秒數 -> 「3 小時 12 分」/「5 分鐘」
static func duration_text(sec: float) -> String:
    var d := OfflineLogic.split_duration(sec)
    if int(d["h"]) > 0:
        return tr_static("OFFLINE_TIME_HM") % [int(d["h"]), int(d["m"])]
    return tr_static("OFFLINE_TIME_M") % int(d["m"])


static func tr_static(key: String) -> String:
    return TranslationServer.translate(key)


## 顯示離線收益面板(關卡呼叫;counted_sec 是真正算進收益的秒數,離線超過上限時文字會說只算多久)
func show_offline(cash: int, offline_sec: int, counted_sec: int) -> void:
    _offline_cash = cash
    if counted_sec < offline_sec:
        _offline_body.text = tr("OFFLINE_BODY_FULL") % [duration_text(offline_sec), duration_text(counted_sec), cash]
    else:
        _offline_body.text = tr("OFFLINE_BODY") % [duration_text(offline_sec), cash]
    menu_panel.visible = false
    _offline_dim.visible = true
    offline_panel.visible = true


func offline_open() -> bool:
    return offline_panel.visible


func offline_cash() -> int:
    return _offline_cash


## 領取鈕(與測試)都走這裡:關面板、交給關卡進錢包
func offline_action(id: String) -> void:
    if id != "claim" or not offline_panel.visible:
        return
    offline_panel.visible = false
    _offline_dim.visible = false
    action.emit("offline_claim")


## 詳細統計三頁(選單面板的分頁):經濟 / 幫手與熊 / 王與券
func stats_pages() -> Array[String]:
    var t := "%d:%02d" % [int(GameState.play_time) / 60, int(GameState.play_time) % 60]
    return [
        tr("HUD_STATS_ECON") % [GameState.cash_earned, int(round(income_rate * 60.0)), GameState.offline_earned, GameState.fish_caught,
                GameState.items_sold, GameState.items_trashed, t],
        tr("HUD_STATS_HELPERS") % [GameState.hired_count("fisher"), GameState.hired_count("porter"), GameState.hired_count("cashier"), GameState.hired_count("repairman"),
                GameState.hired_count("guard"),
                GameState.upgrade_level("worker_speed"), GameState.upgrade_level("pile_cap"), GameState.upgrade_level("porter_cap"),
                GameState.weapon_level, GameState.shop_level, GameState.helpers_lost, GameState.pelts],
        tr("HUD_STATS_KING") % [GameState.king_level, GameState.king_kills, GameState.king_streak, GameState.teeth, GameState.king_capacity_bonus]
                + "\n" + tr("HUD_COUPONS") % [GameState.coupon("insurance"), GameState.coupon("calm"), GameState.coupon("upgrade")]
                + "\n" + tr("HUD_STATS_MORE") % [GameState.orders_done, GameState.orders_cash, GameState.rarefish, GameState.map_pieces, GameState.MAP_PIECES]
                + "\n" + tr("HUD_LEGACY_LINE") % [GameState.generation(), GameState.legacy_points(), GameState.legacy_total_levels()],
    ]


## 三頁合起來(給測試 / 除錯)
func stats_text() -> String:
    return "\n".join(stats_pages())


func _refresh_stats() -> void:
    var pages := stats_pages()
    for i in _stat_pages.size():
        if i < pages.size():
            _stat_pages[i].text = pages[i]


func stats_tab_count() -> int:
    return _tabs.get_tab_count() if _tabs != null else 0


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
        "fx":
            Settings.set_fx(not Settings.fx_on)
        "hints":
            action.emit("hints")
        "map":
            show_map()
        "help":
            show_help()
        "changelog":
            show_changelog()
        "journal":
            menu_panel.visible = false
            action.emit("journal")
        "legacy":
            menu_panel.visible = false
            action.emit("legacy_open")
        "stats":
            show_stats()
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


## 通知:上一則顯示不到 NOTICE_HOLD 秒就排隊,等它顯示夠久再換;排隊中同一類(前 8 個字相同,例如撿毛皮的累計)只留最新的
const NOTICE_SEC := 3.5   # toast 3 ~ 5 秒自動消失(UX 準則 toast-notifications)
const NOTICE_HOLD := 0.9


func show_notice(text: String) -> void:
    if _notice_timer > NOTICE_SEC - NOTICE_HOLD:
        if not _notice_queue.is_empty() and _same_kind(_notice_queue[_notice_queue.size() - 1], text):
            _notice_queue[_notice_queue.size() - 1] = text
        elif _same_kind(_notice.text, text):
            _notice.text = text   # 同一類直接更新數字(撿第 2、3 張毛皮)
        else:
            _notice_queue.append(text)
        return
    _show_notice_now(text)


func _show_notice_now(text: String) -> void:
    _notice.text = text
    _toast.modulate.a = 1.0
    _notice_timer = NOTICE_SEC


static func _same_kind(a: String, b: String) -> bool:
    return a != "" and b != "" and a.substr(0, 8) == b.substr(0, 8)


func notice_text() -> String:
    return _notice.text


func queued_notices() -> int:
    return _notice_queue.size()


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
    var chip: Label
    if not _chip_pool.is_empty():
        chip = _chip_pool.pop_back()
        chip.visible = true
    else:
        chip = _make_label(20, Color(0.55, 0.95, 0.45))
        chip.text = "$"
        add_child(chip)
    chip.position = start
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
        chip.visible = false
        _chip_pool.append(chip)
    _wallet.pivot_offset = _wallet.size / 2.0
    _wallet.scale = Vector2(1.25, 1.25)
    var tw := _wallet.create_tween()
    tw.tween_property(_wallet, "scale", Vector2.ONE, 0.15)


func fps_visible() -> bool:
    return _fps.visible


func _process(delta: float) -> void:
    if _notice_timer > 0.0:
        _notice_timer -= delta
        _toast.modulate.a = clampf(_notice_timer / 0.6, 0.0, 1.0)
    if _hint_timer > 0.0:   # 底部操作提示開局 30 秒後淡出
        _hint_timer -= delta
        _hint.modulate.a = clampf(_hint_timer / 1.5, 0.0, 1.0)
    if _upgrade_btn.visible:   # 守衛塔「升級」鈕脈動,提醒旁邊有事可做
        _pulse_t += delta
        var ps := 1.0 + 0.04 * sin(_pulse_t * 5.0)
        _upgrade_btn.pivot_offset = _upgrade_btn.size / 2.0
        _upgrade_btn.scale = Vector2(ps, ps)
    if not _notice_queue.is_empty() and _notice_timer <= NOTICE_SEC - NOTICE_HOLD:
        _show_notice_now(_notice_queue.pop_front())
    if _fps.visible:
        _fps_timer -= delta
        if _fps_timer <= 0.0:
            _fps_timer = 0.25
            _fps.text = "FPS %d" % Engine.get_frames_per_second()
    if GameState.wallet != _wallet_shown:   # 文字只在數字變了才重排(每幀重排 Label 在手機上很貴)
        _wallet_shown = GameState.wallet
        _wallet.text = tr("HUD_WALLET") % UiTheme.fmt_int(GameState.wallet)
    if player == null or not is_instance_valid(player):
        return
    var key := "%s/%d/%d/%d/%d/%d/%d" % [player.stack.item_id, player.stack.count, player.stack.capacity, GameState.pelts, GameState.teeth, GameState.rarefish, GameState.weapon_level]
    if key != _info_key:
        _info_key = key
        var carry := tr("HUD_EMPTY")
        if not player.stack.is_empty():
            carry = tr("HUD_CARRY") % [GameData.item_name(player.stack.item_id), player.stack.count, player.stack.capacity]
        else:
            carry = "%s(%d)" % [carry, player.stack.capacity]
        _info.text = carry
        (_res_chips["pelt"] as Label).text = tr("HUD_CHIP_pelt") % GameState.pelts
        (_res_chips["tooth"] as Label).text = tr("HUD_CHIP_tooth") % GameState.teeth
        (_res_chips["rarefish"] as Label).text = tr("HUD_CHIP_rarefish") % GameState.rarefish
        (_res_chips["weapon"] as Label).text = tr("HUD_CHIP_weapon") % GameState.weapon_level
    if stats_panel.visible:
        _stats_timer -= delta
        if _stats_timer <= 0.0:
            _stats_timer = 0.5
            _refresh_stats()
