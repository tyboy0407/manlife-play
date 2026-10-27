extends Node
## 音效(Autoload:Sfx):聽 EventBus 事件,播放 assets/sfx/<name>.wav 的占位音效(tools/gen_sfx.py 產生,同名覆蓋即可換正式音效)。
## 固定幾個 AudioStreamPlayer 輪流播(可重疊);每種音效有最短間隔避免連發;海浪 / 風環境音循環低音量。
## 純表現層:headless 測試時照常呼叫(Dummy 音訊驅動),用 played 計數驗證。

const SFX_DIR := "res://assets/sfx/"
const NAMES := ["catch", "drop", "pick", "sale", "coin", "pay", "unlock", "hire", "trash", "goal", "roar", "chomp", "ambient_waves"]
const MIN_GAP := {"coin": 0.05, "pay": 0.05, "drop": 0.04, "pick": 0.04, "catch": 0.06, "sale": 0.1, "roar": 0.5, "chomp": 0.3}
const VOLUMES := {"coin": -6.0, "pay": -8.0, "drop": -4.0, "pick": -6.0, "catch": -3.0, "trash": -4.0, "roar": -2.0, "chomp": -2.0,
    "ambient_waves": -16.0}
const POOL := 10

var enabled := true
var played_total := 0
var played := {}   # name -> 播放次數

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _ambient: AudioStreamPlayer
var _last := {}


func _ready() -> void:
    for n in NAMES:
        var path: String = SFX_DIR + str(n) + ".wav"
        if ResourceLoader.exists(path):
            var s = load(path)
            if s is AudioStream:
                _streams[n] = s
    for i in POOL:
        var p := AudioStreamPlayer.new()
        add_child(p)
        _players.append(p)
    _ambient = AudioStreamPlayer.new()
    add_child(_ambient)
    _start_ambient()
    EventBus.items_moved.connect(_on_items_moved)
    EventBus.purchased.connect(func(_id: String, effect: Dictionary) -> void:
        play("hire" if str(effect.get("type", "")) == "hire" else "unlock"))
    EventBus.tutorial_step_done.connect(func(_step: int) -> void: play("goal"))
    EventBus.bear_appeared.connect(func(_b: Node3D) -> void: play("roar"))
    EventBus.bear_scared.connect(func(_b: Node3D, _by: Node3D) -> void: play("roar", 0.2))
    EventBus.helper_eaten.connect(func(_role: String, _h: Node3D) -> void: play("chomp"))


func has(name: String) -> bool:
    return _streams.has(name)


## 環境音:匯入預設不循環,執行期複製一份把 loop 打開
func _start_ambient() -> void:
    var s = _streams.get("ambient_waves", null)
    if s == null:
        return
    if s is AudioStreamWAV:
        var w: AudioStreamWAV = (s as AudioStreamWAV).duplicate()
        var bytes_per_frame := (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if w.stereo else 1)
        w.loop_mode = AudioStreamWAV.LOOP_FORWARD
        w.loop_begin = 0
        w.loop_end = int(w.data.size() / bytes_per_frame)
        _ambient.stream = w
    else:
        _ambient.stream = s
    _ambient.volume_db = float(VOLUMES.get("ambient_waves", -16.0))
    _ambient.play()


func _on_items_moved(kind: String, _item: String, _from: Vector3, _to: Vector3, _count: int) -> void:
    match kind:
        "catch":
            play("catch")
        "to_station", "to_counter", "return":
            play("drop")
        "from_station":
            play("pick")
        "trash":
            play("trash")
        "cash":
            play("coin")
        "pay":
            play("pay")
        "sold":
            play("sale")


## 播一個音效(帶一點隨機音高);太密集或沒這個音檔就不播,回傳有沒有播
func play(name: String, pitch_jitter := 0.08) -> bool:
    if not enabled or not _streams.has(name):
        return false
    var now := Time.get_ticks_msec() / 1000.0
    if now - float(_last.get(name, -10.0)) < float(MIN_GAP.get(name, 0.03)):
        return false
    _last[name] = now
    var p := _free_player()
    p.stream = _streams[name]
    p.volume_db = float(VOLUMES.get(name, 0.0))
    p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
    p.play()
    played_total += 1
    played[name] = int(played.get(name, 0)) + 1
    return true


## 音效總開關(選單):關掉就全停(含環境音),打開重放環境音
func set_enabled(on: bool) -> void:
    if on == enabled:
        return
    enabled = on
    if on:
        _start_ambient()
    else:
        stop_all()


## 全部停掉(測試離開前呼叫:還在播的 AudioStreamPlayback 會被 Godot 當成洩漏報出來)
func stop_all() -> void:
    for p in _players:
        p.stop()
        p.stream = null
    if _ambient != null:
        _ambient.stop()
        _ambient.stream = null


func _free_player() -> AudioStreamPlayer:
    for p in _players:
        if not p.playing:
            return p
    return _players[played_total % _players.size()]
