class_name OfflineLogic
extends RefCounted
## 離線收益規則(純資料,數值在 game.json offline):在線時記最近 windowSec 秒賣出的錢算出「每秒收入速率」,
## 存檔記這個速率;回來時離線秒數 = 現在 - savedAt,收益 = 速率 × min(離線秒數, maxSec) × rateMult,不滿 minSec 不算。
## 速率:window 裡還沒觀察到的部分用讀檔帶進來的 seed_rate 補(剛讀檔就關掉也不會變 0);新遊戲 seed 0,前幾分鐘速率偏低是正常的。
## 時間一律用 GameState.play_time(遊戲秒數,暫停不走)。

var window_sec := 300.0
var min_sec := 60.0
var max_sec := 28800.0
var mult := 0.5
var seed_rate := 0.0     # 讀檔帶進來的速率(每秒)
var _samples: Array = []  # [t, cash]
var _start_t := 0.0
var _sum := 0


static func from_config(c: Dictionary) -> OfflineLogic:
    var l := OfflineLogic.new()
    var cfg := c if c != null else {}
    l.window_sec = maxf(float(cfg.get("windowSec", 300.0)), 1.0)
    l.min_sec = maxf(float(cfg.get("minSec", 60.0)), 0.0)
    l.max_sec = maxf(float(cfg.get("maxSec", 28800.0)), l.min_sec)
    l.mult = clampf(float(cfg.get("rateMult", 0.5)), 0.0, 10.0)
    return l


## 從 t 開始觀察;prev_rate 是存檔裡的速率(沒有就 0)
func begin(t: float, prev_rate := 0.0) -> void:
    _start_t = t
    seed_rate = maxf(prev_rate, 0.0)
    _samples.clear()
    _sum = 0


func record(t: float, cash: int) -> void:
    if cash <= 0:
        return
    _samples.append([t, cash])
    _sum += cash
    _prune(t)


func _prune(t: float) -> void:
    while not _samples.is_empty() and float(_samples[0][0]) < t - window_sec:
        _sum -= int(_samples[0][1])
        _samples.remove_at(0)


## 每秒收入速率:window 內的實際收入 + 還沒觀察到的部分用 seed_rate 補
func rate(t: float) -> float:
    _prune(t)
    var observed := clampf(t - _start_t, 0.0, window_sec)
    return (float(_sum) + seed_rate * (window_sec - observed)) / window_sec


func sample_count() -> int:
    return _samples.size()


static func offline_seconds(saved_at: int, now: int) -> int:
    if saved_at <= 0:
        return 0
    return maxi(now - saved_at, 0)


## 離線收益(整數元);不滿 min_sec 回 0,超過 max_sec 的部分不算
func earnings(rate_per_sec: float, offline_sec: float) -> int:
    if offline_sec < min_sec or rate_per_sec <= 0.0:
        return 0
    return int(floor(rate_per_sec * minf(offline_sec, max_sec) * mult))


## 算進收益的秒數(給面板顯示)
func counted_seconds(offline_sec: float) -> int:
    return int(minf(maxf(offline_sec, 0.0), max_sec))


## 秒數拆成 {h, m}(給翻譯文字用;不滿 1 分鐘算 1 分鐘)
static func split_duration(sec: float) -> Dictionary:
    var total_min := maxi(int(floor(sec / 60.0)), 1)
    return {"h": total_min / 60, "m": total_min % 60}
