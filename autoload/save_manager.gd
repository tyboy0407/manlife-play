extends Node
## 存檔讀寫(Autoload:SaveManager):只負責檔案 IO 與版本;內容由 GameState.to_dict 與 Harbor.snapshot 組成。
## 預設 user://manlife_save.json,測試可改 save_path。

const DEFAULT_PATH := "user://manlife_save.json"
const VERSION := 2   # 2:現金改錢包(GameState.wallet),舊檔忽略

var save_path := DEFAULT_PATH
var last_error := ""


func has_save() -> bool:
    return FileAccess.file_exists(save_path)


func write(data: Dictionary) -> bool:
    var out := data.duplicate(true)
    out["version"] = VERSION
    out["savedAt"] = int(Time.get_unix_time_from_system())
    var file := FileAccess.open(save_path, FileAccess.WRITE)
    if file == null:
        last_error = "open failed: %s" % FileAccess.get_open_error()
        push_warning("存檔失敗:%s" % last_error)
        return false
    file.store_string(JSON.stringify(out, "\t"))
    file.close()
    last_error = ""
    return true


## 讀不到 / 格式錯 / 版本不對就回空字典
func read() -> Dictionary:
    if not has_save():
        return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
    if typeof(parsed) != TYPE_DICTIONARY:
        last_error = "bad json"
        push_warning("存檔格式不正確,忽略")
        return {}
    if int(parsed.get("version", 0)) != VERSION:
        last_error = "version mismatch"
        push_warning("存檔版本不符(%s),忽略" % str(parsed.get("version", "")))
        return {}
    return parsed


func delete() -> void:
    if has_save():
        DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
