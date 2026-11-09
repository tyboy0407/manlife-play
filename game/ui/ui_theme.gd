class_name UiTheme
extends RefCounted
## HUD / 面板共用的樣式(2026-11-09 UI 整理;同日照 ui-ux-pro-max 的設計系統輸出調整,見 notes/ui_design_decisions.md):
## 風格 Claymorphism(休閒遊戲:圓角 14 ~ 18、厚邊 3px、柔和陰影、按下 200ms ease-out),主動作用「獎勵金」#F59E0B、危險 #DC2626、文字對比 >= 4.5:1;
## 按鈕身分(primary / secondary / danger / toggle_on / toggle_off / row)、資源小籤(chip)、面板與 toast 的 StyleBox、按下回饋(縮一下 + tap 音效)、千分位 fmt_int。
## 全部是 static,Hud 建控制項時呼叫;測試可以讀 StyleBox 顏色確認身分。

const GOLD := Color(1.0, 0.88, 0.45)
const TEXT := Color(0.96, 0.97, 1.0)
const TEXT_DIM := Color(0.8, 0.85, 0.93)
const PANEL_BG := Color(0.08, 0.09, 0.13, 0.97)
const PANEL_BORDER := Color(0.4, 0.45, 0.56)
const PRIMARY := Color(0.96, 0.62, 0.04)        # #F59E0B 獎勵金(設計系統的 Accent / CTA)
const PRIMARY_TEXT := Color(0.06, 0.09, 0.16)   # #0F172A
const SECONDARY := Color(0.2, 0.24, 0.33)
const SECONDARY_BORDER := Color(0.5, 0.56, 0.7)
const DANGER := Color(0.86, 0.15, 0.15)         # #DC2626
const TOGGLE_ON := Color(0.16, 0.5, 0.34)
const TOGGLE_OFF := Color(0.22, 0.24, 0.3)
const HUD_BG := Color(0.05, 0.06, 0.09, 0.62)
const TOAST_BG := Color(0.06, 0.07, 0.1, 0.9)
const BUTTON_H := 48.0
const PRESS_SCALE := 0.97
const PRESS_SEC := 0.2                           # Claymorphism:soft press 200ms ease-out
const RADIUS_PANEL := 18
const RADIUS_BUTTON := 14
const BORDER_BUTTON := 3                         # 厚邊 3px


static func _flat(bg: Color, border: Color = Color.TRANSPARENT, radius: int = 10, border_w: int = 0) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = bg
    sb.border_color = border
    sb.set_border_width_all(border_w)
    sb.set_corner_radius_all(radius)
    sb.set_content_margin_all(10)
    return sb


## 置中大面板的外框(厚邊 + 柔和陰影,疊在雪地上才有層次)
static func panel_style() -> StyleBoxFlat:
    var sb := _flat(PANEL_BG, PANEL_BORDER, RADIUS_PANEL, 2)
    sb.set_content_margin_all(14)
    sb.shadow_size = 10
    sb.shadow_color = Color(0, 0, 0, 0.35)
    sb.shadow_offset = Vector2(0, 4)
    return sb


## 左上角 HUD 區塊:半透明深底,3D 標籤壓到後面也讀得清
static func hud_style() -> StyleBoxFlat:
    var sb := _flat(HUD_BG, Color.TRANSPARENT, RADIUS_BUTTON, 0)
    sb.set_content_margin_all(10)
    return sb


## 通知 toast:深底圓角
static func toast_style() -> StyleBoxFlat:
    var sb := _flat(TOAST_BG, Color(0.5, 0.56, 0.7, 0.6), RADIUS_BUTTON, 2)
    sb.shadow_size = 8
    sb.shadow_color = Color(0, 0, 0, 0.3)
    sb.shadow_offset = Vector2(0, 3)
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
    var border_w := BORDER_BUTTON
    var shadow := 0
    match kind:
        "primary":
            bg = PRIMARY
            border = PRIMARY.lightened(0.3)
            text = PRIMARY_TEXT
            shadow = 5
        "danger":
            bg = DANGER
            border = DANGER.lightened(0.3)
            shadow = 5
        "toggle_on":
            bg = TOGGLE_ON
            border = Color(0.45, 0.85, 0.6)
        "toggle_off":
            bg = TOGGLE_OFF
            border = SECONDARY_BORDER
            text = TEXT_DIM
        "row":
            bg = Color(0.14, 0.16, 0.21)
            border = Color(0.32, 0.36, 0.46)
            border_w = 2
    var normal := _flat(bg, border, RADIUS_BUTTON, border_w)
    var hover := _flat(bg.lightened(0.08), border.lightened(0.1), RADIUS_BUTTON, border_w)
    var pressed := _flat(bg.darkened(0.18), border, RADIUS_BUTTON, border_w)
    var disabled := _flat(Color(bg.r, bg.g, bg.b, 0.35), Color(border.r, border.g, border.b, 0.3), RADIUS_BUTTON, border_w)
    for sb in [normal, hover, pressed, disabled]:
        sb.content_margin_left = 12
        sb.content_margin_right = 12
        sb.content_margin_top = 6
        sb.content_margin_bottom = 6
    if shadow > 0:   # 主動作鈕浮起來(Claymorphism 的柔和陰影);按下時陰影收掉 = 被壓下去
        for sb in [normal, hover]:
            sb.shadow_size = shadow
            sb.shadow_color = Color(0, 0, 0, 0.3)
            sb.shadow_offset = Vector2(0, 3)
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
    var sb := _flat(Color(0.0, 0.0, 0.0, 0.45), accent, 10, 0)
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
        tw.tween_property(b, "scale", Vector2.ONE, PRESS_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT))


## 千分位(UX 準則 number-formatting:大數字要分隔;錢包到六位數就很難讀)
static func fmt_int(n: int) -> String:
    var neg := n < 0
    var s := str(absi(n))
    var out := ""
    var count := 0
    for i in range(s.length() - 1, -1, -1):
        out = s[i] + out
        count += 1
        if count % 3 == 0 and i > 0:
            out = "," + out
    return ("-" if neg else "") + out


## 把子樹裡所有按鈕都接上按下回饋
static func attach_press_fx(root: Node) -> void:
    if root is Button:
        press_fx(root as Button)
    for c in root.get_children():
        attach_press_fx(c)
