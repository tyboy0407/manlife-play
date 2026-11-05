extends Node
## 裝置偏好(Autoload:Settings):畫質與 FPS 顯示,存在 user://settings.json,跟遊戲存檔分開(重新開始不會清掉)。
## quality:"smooth"(觸控裝置預設:關即時陰影改腳下圓影、3D 用 0.75 倍解析度算)/ "fine"(桌機預設:即時陰影、全解析度)。
## 改了就 changed,關卡(Harbor._apply_quality)與 HUD 自己去套。

signal changed

const DEFAULT_PATH := "user://settings.json"
const SMOOTH := "smooth"
const FINE := "fine"
const SCALE_SMOOTH := 0.75

var path := DEFAULT_PATH
var quality := FINE
var show_fps := false
var seen_version := ""   # 看過哪一版的「新版內容」(data/changelog.json 的 version);更新後第一次開才彈面板


func _ready() -> void:
    load_settings()


## 手機 / 平板 / 觸控螢幕
func is_touch_device() -> bool:
    return DisplayServer.is_touchscreen_available() or OS.has_feature("web_ios") or OS.has_feature("web_android") or OS.has_feature("mobile")


func is_smooth() -> bool:
    return quality == SMOOTH


## 3D 畫面的解析度倍率(UI 不受影響)
func scaling_3d() -> float:
    return SCALE_SMOOTH if is_smooth() else 1.0


## 沒有設定檔就依裝置給預設:觸控裝置流暢、桌機精細
func load_settings() -> void:
    quality = SMOOTH if is_touch_device() else FINE
    show_fps = false
    seen_version = ""
    if not FileAccess.file_exists(path):
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var q := str(parsed.get("quality", quality))
    if q == SMOOTH or q == FINE:
        quality = q
    show_fps = bool(parsed.get("show_fps", false))
    seen_version = str(parsed.get("seen_version", ""))


func save_settings() -> bool:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify({"quality": quality, "show_fps": show_fps, "seen_version": seen_version}, "\t"))
    file.close()
    return true


func set_quality(q: String) -> void:
    if q != SMOOTH and q != FINE:
        return
    quality = q
    save_settings()
    changed.emit()


func toggle_quality() -> void:
    set_quality(FINE if is_smooth() else SMOOTH)


func set_show_fps(on: bool) -> void:
    show_fps = on
    save_settings()
    changed.emit()


## 記住看過這一版的新版內容
func mark_version_seen(v: String) -> void:
    if v == seen_version:
        return
    seen_version = v
    save_settings()


func delete_file() -> void:
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
