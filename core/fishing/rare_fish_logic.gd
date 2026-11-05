class_name RareFishLogic
extends RefCounted
## 稀有魚(金魚)規則(純資料,數值在 game.json rareFish):每個水區每 intervalSec[0 ~ 1] 秒偶爾生一條金色魚(游得快、會發光),
## lifetimeSec 秒沒抓到就游走;只有玩家抓得到(漁夫不抓):走到 catchRadius 內自動開始抓,要站滿 catchSec 秒(進度環),
## 走開進度歸零。抓到進 GameState 的稀有魚資源(不佔背包),拿去跟旅行商人換地圖碎片、或交訂單。

const ITEM := "rarefish"   # GameState 的資源名(不佔背包)

var cfg := {}


static func from_config(d: Dictionary) -> RareFishLogic:
    var r := RareFishLogic.new()
    r.cfg = d if d != null else {}
    return r


## 下一條幾秒後出現(roll 0 ~ 1 在 intervalSec 區間內取)
func next_interval(roll: float) -> float:
    var iv = cfg.get("intervalSec", [60.0, 90.0])
    var lo := 60.0
    var hi := 90.0
    if typeof(iv) == TYPE_ARRAY and iv.size() >= 2:
        lo = maxf(float(iv[0]), 1.0)
        hi = maxf(float(iv[1]), lo)
    return lerpf(lo, hi, clampf(roll, 0.0, 1.0))


func lifetime() -> float:
    return maxf(float(cfg.get("lifetimeSec", 150.0)), 1.0)


func catch_radius() -> float:
    return maxf(float(cfg.get("catchRadius", 2.0)), 0.1)


func catch_sec() -> float:
    return maxf(float(cfg.get("catchSec", 2.0)), 0.05)


func speed_mult() -> float:
    return maxf(float(cfg.get("speedMult", 1.8)), 0.1)


## 抓魚進度:在範圍內累加、離開歸零;回傳新的進度(秒)
func tick_catch(progress: float, delta: float, in_range: bool) -> float:
    if not in_range:
        return 0.0
    return progress + delta


func is_caught(progress: float) -> bool:
    return progress >= catch_sec()
