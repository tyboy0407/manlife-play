class_name UiTheme
extends RefCounted
## HUD / 面板共用的樣式(2026-11-09 UI 整理):顏色 token、按鈕三種身分(primary 暖橘主動作 / secondary 灰框次要 / danger 紅底危險)、
## 方格開關(toggle)、清單列(row)、資源小籤(chip)、面板與 toast 的 StyleBox、按下回饋(縮一下 + tap 音效)。
## 全部是 static,Hud 建控制項時呼叫;測試可以讀 StyleBox 顏色確認身分。

const GOLD := Color(1.0, 0.88, 0.45)
const TEXT := Color(0.95, 0.97, 1.0)
const TEXT_DIM := Color(0.78, 0.82, 0.9)
const PANEL_BG := Color(0.08, 0.09, 0.12, 0.97)
const PANEL_BORDER := Color(0.35, 0.38, 0.45)
const PRIMARY := Color(0.93, 0.52, 0.18)
const PRIMARY_TEXT := Color(0.15, 0.08, 0.03)
const SECONDARY := Color(0.2, 0.22, 0.28)
const SECONDARY_BORDER := Color(0.42, 0.46, 0.55)
const DANGER := Color(0.62, 0.18, 0.16)
const TOGGLE_ON := Color(0.2, 0.42, 0.3)
const TOGGLE_OFF := Color(0.22, 0.23, 0.28)
const HUD_BG := Color(0.05, 0.06, 0.09, 0.6)
const TOAST_BG := Color(0.06, 0.07, 0.1, 0.88)
const BUTTON_H := 48.0
const PRESS_SCALE := 0.96


static func _flat(bg: Color, border: Color = Color.TRANSPARENT, radius: int = 10, border_w: int = 0) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = bg
    sb.border_color = border
    sb.set_border_width_all(border_w)
    sb.set_corner_radius_all(radius)
    sb.set_content_margin_all(10)
    return sb


## 置中大面板的外框
static func panel_style() -> StyleBoxFlat:
    var sb := _flat(PANEL_BG, PANEL_BORDER, 12, 1)
    sb.set_content_margin_all(14)
    return sb


## 左上角 HUD 區塊:半透明深底,3D 標籤壓到後面也讀得清
static func hud_style() -> StyleBoxFlat:
    var sb := _flat(HUD_BG, Color.TRANSPARENT, 12, 0)
    sb.set_content_margin_all(10)
    return sb


## 通知 toast:深底圓角
static func toast_style() -> StyleBoxFlat:
    var sb := _flat(TOAST_BG, Color(0.5, 0.55, 0.65, 0.5), 12, 1)
    sb.content_margin_left = 16
    sb.content_margin_right = 16
    sb.content_margin_top = 8
    sb.content_margin_bottom = 8
    return sb


## 訂單小卡:左邊一條藍色邊
static func card_style(accent: Color) -> StyleBoxFlat:
    var sb := _flat(Color(0.05, 0.06, 0.09, 0.55), accent, 8, 0)
    sb.border_width_left = 4
    sb.content_margin_left = 10
    sb.content_margin_right = 8
    sb.content_margin_top = 4
    sb.content_margin_bottom = 4
    return sb


## 按鈕身分:primary(暖橘,主要動作)/ secondary(灰框,次要)/ danger(紅,重新開始 / 確認過冬)/ toggle_on / toggle_off(方格開關)/ row(清單列,左對齊)
static func style_button(b: Button, kind: String, font_size: int = 18) -> void:
    var bg := SECONDARY
    var border := SECONDARY_BORDER
    var text := TEXT
    var border_w := 1
    match kind:
        "primary":
            bg = PRIMARY
            border = PRIMARY.lightened(0.25)
            text = PRIMARY_TEXT
        "danger":
            bg = DANGER
            border = DANGER.lightened(0.3)
        "toggle_on":
            bg = TOGGLE_ON
            border = Color(0.4, 0.75, 0.55)
        "toggle_off":
            bg = TOGGLE_OFF
            border = SECONDARY_BORDER
            text = TEXT_DIM
        "row":
            bg = Color(0.13, 0.14, 0.18)
            border = Color(0.3, 0.33, 0.4)
    var normal := _flat(bg, border, 10, border_w)
    var hover := _flat(bg.lightened(0.08), border.lightened(0.1), 10, border_w)
    var pressed := _flat(bg.darkened(0.18), border, 10, border_w)
    var disabled := _flat(Color(bg.r, bg.g, bg.b, 0.35), Color(border.r, border.g, border.b, 0.3), 10, border_w)
    for sb in [normal, hover, pressed, disabled]:
        sb.content_margin_left = 12
        sb.content_margin_right = 12
        sb.content_margin_top = 6
        sb.content_margin_bottom = 6
    b.add_theme_stylebox_override("normal", normal)
    b.add_theme_stylebox_override("hover", hover)
    b.add_theme_stylebox_override("pressed", pressed)
    b.add_theme_stylebox_override("disabled", disabled)
    b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    b.add_theme_color_override("font_color", text)
    b.add_theme_color_override("font_hover_color", text)
    b.add_theme_color_override("font_pressed_color", text)
    b.add_theme_color_override("font_disabled_color", Color(text.r, text.g, text.b, 0.45))
    b.add_theme_font_size_override("font_size", font_size)
    b.set_meta("ui_kind", kind)
    if kind == "row":
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT


static func button_kind(b: Button) -> String:
    return str(b.get_meta("ui_kind", ""))


## 資源小籤:深底、左邊一條代表色、小字
static func chip(text: String, accent: Color, font_size: int = 13) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", TEXT)
    var sb := _flat(Color(0.0, 0.0, 0.0, 0.42), accent, 8, 0)
    sb.border_width_left = 4
    sb.content_margin_left = 8
    sb.content_margin_right = 8
    sb.content_margin_top = 2
    sb.content_margin_bottom = 2
    l.add_theme_stylebox_override("normal", sb)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l


## 標題下的分隔線
static func divider() -> ColorRect:
    var r := ColorRect.new()
    r.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.45)
    r.custom_minimum_size = Vector2(0, 2)
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return r


## 按下回饋:縮到 96% 再彈回 + tap 音效(只接一次)
static func press_fx(b: Button) -> void:
    if b.has_meta("press_fx"):
        return
    b.set_meta("press_fx", true)
    b.button_down.connect(func() -> void:
        b.pivot_offset = b.size / 2.0
        b.scale = Vector2(PRESS_SCALE, PRESS_SCALE)
        var sfx := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Sfx")   # 用路徑拿 Autoload:--check-only / 工具腳本沒有 Autoload 也能編譯
        if sfx != null:
            sfx.play("tap"))
    b.button_up.connect(func() -> void:
        b.pivot_offset = b.size / 2.0
        var tw := b.create_tween()
        tw.tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


## 把子樹裡所有按鈕都接上按下回饋
static func attach_press_fx(root: Node) -> void:
    if root is Button:
        press_fx(root as Button)
    for c in root.get_children():
        attach_press_fx(c)
