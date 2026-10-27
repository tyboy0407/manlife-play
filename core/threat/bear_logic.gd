class_name BearLogic
extends RefCounted
## 北極熊規則(純資料,可 headless 測試):多久來一次(冷卻)、盯上誰(最近的幫手)、咬多久吃掉、
## 玩家的武器等級能在多遠把牠嚇跑、嚇跑後下次要隔多久(武器等級的 cooldownMult)。
## 數值在 game.json:bear {firstDelaySec, intervalSec [min, max], speed, fleeSpeed, biteSec, biteRadius, panicRadius, entries [[x, z]...]}
## 與 weapon {levels: [{scareRadius, cooldownMult, model {file, length}}...]}(第 i 項 = 武器 Lv i+1;Lv0 = 沒武器,嚇不走)。

var cfg := {}
var levels: Array = []


static func from_config(bear_cfg: Dictionary, weapon_cfg: Dictionary) -> BearLogic:
    var b := BearLogic.new()
    b.cfg = bear_cfg.duplicate(true)
    var lv = weapon_cfg.get("levels", [])
    if typeof(lv) == TYPE_ARRAY:
        for e in lv:
            if typeof(e) == TYPE_DICTIONARY:
                b.levels.append(e)
    return b


## --- 時間 ---

## 僱了第一個幫手後,第一隻熊多久來
func first_delay() -> float:
    return maxf(float(cfg.get("firstDelaySec", 45.0)), 0.0)


## 之後每隔多久來一隻(最短、最長)
func interval() -> Vector2:
    var v = cfg.get("intervalSec", [60.0, 90.0])
    if typeof(v) == TYPE_ARRAY and v.size() >= 2:
        return Vector2(maxf(float(v[0]), 0.0), maxf(float(v[1]), float(v[0])))
    return Vector2(60.0, 90.0)


## 熊走掉後下次要等多久:在 interval 之間取 roll(0 ~ 1)的位置,再乘武器等級的 cooldownMult
func next_cooldown(weapon_level: int, roll: float) -> float:
    var r := interval()
    return lerpf(r.x, r.y, clampf(roll, 0.0, 1.0)) * cooldown_mult(weapon_level)


func bite_sec() -> float:
    return maxf(float(cfg.get("biteSec", 4.0)), 0.1)


func bite_radius() -> float:
    return maxf(float(cfg.get("biteRadius", 1.4)), 0.1)


## 熊靠到這麼近,幫手就嚇呆不動
func panic_radius() -> float:
    return maxf(float(cfg.get("panicRadius", 2.6)), bite_radius())


func speed() -> float:
    return maxf(float(cfg.get("speed", 4.0)), 0.1)


func flee_speed() -> float:
    return maxf(float(cfg.get("fleeSpeed", 7.5)), speed())


## 熊從哪幾個邊緣點進來(世界 XZ)
func entries() -> Array[Vector3]:
    var out: Array[Vector3] = []
    var v = cfg.get("entries", [])
    if typeof(v) == TYPE_ARRAY:
        for p in v:
            if typeof(p) == TYPE_ARRAY and p.size() >= 2:
                out.append(Vector3(float(p[0]), 0.0, float(p[1])))
    return out


## --- 武器 ---

func weapon_max_level() -> int:
    return levels.size()


## 第 level 級的設定(Lv1 = levels[0]);Lv0 或超過就空字典
func weapon_level_cfg(level: int) -> Dictionary:
    if level <= 0 or levels.is_empty():
        return {}
    return levels[mini(level, levels.size()) - 1]


## 玩家帶著 level 級武器,離熊多近牠就逃;沒武器回 0(永遠嚇不走)
func scare_radius(level: int) -> float:
    return maxf(float(weapon_level_cfg(level).get("scareRadius", 0.0)), 0.0)


## 熊被 level 級武器趕跑後,下次冷卻的倍率(沒武器 1)
func cooldown_mult(level: int) -> float:
    return maxf(float(weapon_level_cfg(level).get("cooldownMult", 1.0)), 0.1)


func can_scare(level: int, dist: float) -> bool:
    return level > 0 and dist <= scare_radius(level)


## 第 level 級武器掛在玩家身上的模型 {file, length};沒有就空字典
func weapon_model(level: int) -> Dictionary:
    var m = weapon_level_cfg(level).get("model", {})
    return m if typeof(m) == TYPE_DICTIONARY else {}


## --- 盯誰 ---

## 離 from 最近的獵物:prey = [{"id", "pos": Vector3}],回 id;沒有獵物回 -1
static func pick_target(from: Vector3, prey: Array) -> int:
    var best := -1
    var best_d := INF
    for p in prey:
        if typeof(p) != TYPE_DICTIONARY or not p.has("pos"):
            continue
        var pos: Vector3 = p["pos"]
        var d := Vector2(pos.x - from.x, pos.z - from.z).length()
        if d < best_d:
            best_d = d
            best = int(p.get("id", -1))
    return best
