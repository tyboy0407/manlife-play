class_name TouchJoystick
extends Control
## 浮動虛擬搖桿:手指按在畫面任何地方就以那一點為中心,拖多遠往哪推(最遠 RADIUS 像素),放開歸零。
## 只跟第一根手指;按在排除區(選單按鈕 / 面板)不算。方向寫進 MoveInput.touch_dir(螢幕方向,x 右 y 下)。
## 用 _unhandled_input 收 InputEventScreenTouch / ScreenDrag(桌機開 emulate_touch_from_mouse 後滑鼠拖也會變成觸控),
## 自己不吃滑鼠(mouse_filter IGNORE),只負責畫半透明底座與搖桿頭。

const RADIUS := 90.0
const KNOB := 34.0
const DEAD := 6.0

var active := false
var origin := Vector2.ZERO
var knob := Vector2.ZERO
var finger := -1
var dir := Vector2.ZERO
var exclusions: Array[Control] = []   # 這些控制項的範圍內按下不當搖桿


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    MoveInput.touch_dir = Vector2.ZERO


func _exit_tree() -> void:
    MoveInput.touch_dir = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
    if handle_event(event):
        get_viewport().set_input_as_handled()


func is_excluded(pos: Vector2) -> bool:
    for c in exclusions:
        if c != null and is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
            return true
    return false


## 處理一個觸控事件;回傳有沒有吃掉(測試直接呼叫)
func handle_event(event: InputEvent) -> bool:
    if event is InputEventScreenTouch:
        var t := event as InputEventScreenTouch
        if t.pressed:
            if active or is_excluded(t.position):
                return false
            active = true
            finger = t.index
            origin = t.position
            knob = t.position
            _set_dir(Vector2.ZERO)
            queue_redraw()
            return true
        if active and t.index == finger:
            release()
            return true
        return false
    if event is InputEventScreenDrag:
        var d := event as InputEventScreenDrag
        if not active or d.index != finger:
            return false
        var delta := d.position - origin
        if delta.length() > RADIUS:
            delta = delta.normalized() * RADIUS
        knob = origin + delta
        _set_dir(Vector2.ZERO if delta.length() < DEAD else delta / RADIUS)
        queue_redraw()
        return true
    return false


func release() -> void:
    active = false
    finger = -1
    _set_dir(Vector2.ZERO)
    queue_redraw()


func _set_dir(v: Vector2) -> void:
    dir = v
    MoveInput.touch_dir = v


func _draw() -> void:
    if not active:
        return
    draw_circle(origin, RADIUS, Color(1, 1, 1, 0.10))
    draw_arc(origin, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
    draw_circle(knob, KNOB, Color(1, 1, 1, 0.45))
    draw_arc(knob, KNOB, 0.0, TAU, 32, Color(1, 1, 1, 0.7), 2.0, true)
