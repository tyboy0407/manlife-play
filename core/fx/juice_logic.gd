class_name JuiceLogic
extends RefCounted
## 打擊感(juice)的純規則(照 game-feel skill 的做法):事件分三級(small / medium / large),每級決定相機 trauma 加量、hit-stop 秒數、
## 彈跳倍率;trauma 隨時間線性衰減,震幅 = trauma²(小事幾乎不晃、大事才晃),震動用疊加正弦取樣(不每幀亂數,才不會像雜訊);
## 離玩家越遠的事件加的 trauma 越少(falloff)。數值可由 game.json juice 蓋過。

const TIERS := {
    "small": {"trauma": 0.15, "hitstop": 0.0, "pop": 1.12},
    "medium": {"trauma": 0.4, "hitstop": 0.05, "pop": 1.2},
    "large": {"trauma": 0.8, "hitstop": 0.12, "pop": 1.3},
}
const EVENT_TIER := {
    "fish_caught": "small", "loot_collected": "small", "cash_collected": "small", "purchased": "small", "tower_built": "small", "sale_made": "small",
    "bear_hit": "medium", "bear_defeated": "medium", "trap_triggered": "medium", "tower_destroyed": "medium", "station_destroyed": "medium",
    "helper_eaten": "medium", "order_completed": "medium", "bear_appeared": "medium",
    "king_defeated": "large", "chest_opened": "large", "king_appeared": "large",
}

var decay := 1.3                      # 每秒掉多少 trauma
var max_offset := Vector2(0.45, 0.3)  # 相機最大位移(世界單位;相機離地 13 ~ 17 單位,0.45 在螢幕上約 2%)
var max_roll := 0.03                  # 最大滾轉(弧度)
var falloff_near := 6.0               # 玩家這個距離內的事件全額
var falloff_far := 18.0               # 超過這個距離不晃
var tiers := TIERS.duplicate(true)


static func from_config(cfg: Dictionary) -> JuiceLogic:
    var j := JuiceLogic.new()
    j.decay = maxf(float(cfg.get("decay", j.decay)), 0.05)
    var mo = cfg.get("maxOffset", null)
    if typeof(mo) == TYPE_ARRAY and mo.size() >= 2:
        j.max_offset = Vector2(float(mo[0]), float(mo[1]))
    j.max_roll = float(cfg.get("maxRoll", j.max_roll))
    j.falloff_near = float(cfg.get("falloffNear", j.falloff_near))
    j.falloff_far = maxf(float(cfg.get("falloffFar", j.falloff_far)), j.falloff_near + 0.1)
    var t = cfg.get("tiers", {})
    if typeof(t) == TYPE_DICTIONARY:
        for k in t:
            if j.tiers.has(k) and typeof(t[k]) == TYPE_DICTIONARY:
                for f in t[k]:
                    j.tiers[k][f] = float(t[k][f])
    return j


static func tier_of(event: String) -> String:
    return str(EVENT_TIER.get(event, ""))


func tier_value(event: String, field: String) -> float:
    var t := tier_of(event)
    if t == "":
        return 0.0
    return float(tiers[t].get(field, 0.0))


## 距離衰減:near 內 1、far 外 0,中間線性
func falloff(distance: float) -> float:
    if distance <= falloff_near:
        return 1.0
    if distance >= falloff_far:
        return 0.0
    return 1.0 - (distance - falloff_near) / (falloff_far - falloff_near)


## 這個事件在這個距離要加多少 trauma
func trauma_for(event: String, distance: float = 0.0) -> float:
    return tier_value(event, "trauma") * falloff(distance)


## hit-stop 秒數(只有 medium / large 有;0 = 不停)
func hitstop_for(event: String) -> float:
    return tier_value(event, "hitstop")


## 彈跳(squash)倍率
func pop_for(event: String) -> float:
    var v := tier_value(event, "pop")
    return v if v > 0.0 else 1.0


static func add_trauma(trauma: float, amount: float) -> float:
    return clampf(trauma + amount, 0.0, 1.0)   # 連續事件是累加,不是重設


func decay_trauma(trauma: float, delta: float) -> float:
    return maxf(trauma - decay * delta, 0.0)


## 震幅:trauma 的平方,小震幾乎看不到、大震才明顯
static func shake_amount(trauma: float) -> float:
    return trauma * trauma


## 疊加兩個不可公度頻率的正弦當平滑雜訊(-1 ~ 1)
static func smooth_noise(t: float, seed: float) -> float:
    return 0.6 * sin(t * 11.0 + seed) + 0.4 * sin(t * 23.0 + seed * 2.0)


## 這一刻的相機位移 (x, y) 與滾轉 z;t 是累計時間
func shake_offset(trauma: float, t: float) -> Vector3:
    var s := shake_amount(trauma)
    if s <= 0.0:
        return Vector3.ZERO
    return Vector3(max_offset.x * s * smooth_noise(t, 0.0), max_offset.y * s * smooth_noise(t, 1.7), max_roll * s * smooth_noise(t, 3.1))
