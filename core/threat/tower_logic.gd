class_name TowerLogic
extends RefCounted
## 守衛塔規則(純資料,可 headless 測試):血量、每箭傷害、射程、射速、箭速、一般熊咬一口扣多少、咬一口幾秒、
## 熊離塔多近會改去拆塔(aggroRadius)。數值在 game.json tower {hp, damage, range, attackIntervalSec, arrowSpeed, biteDamage,
## biteSec, aggroRadius, height}:hp 800 / biteDamage 40 = 扛得住 20 口。北極熊王不看血量,咬滿 BearLogic.king_building_bite_sec 秒直接拆掉。
## 蓋 / 修的價格在 shop.json(tower_1 ~ tower_4,rebuyMult 1 = 修復同價)。
## 強力守衛塔(tier 1,熊王牙強化):tower.strong {hp 2000 = 扛 50 口, damage 25};hp(tier) / damage(tier) 吃 tier。
## 塔的升級(tower.upgrade):站在塔旁 dwellSec 秒開面板,射速 / 傷害各可升 maxEach 次、每次 cost;射速每級射擊間隔 × rateMult(0.92),
## 傷害每級 +damagePerLevel(0.2)倍的基礎傷害(attack_interval(rate_level) / damage(tier, damage_level))。

var cfg := {}


static func from_config(c: Dictionary) -> TowerLogic:
    var t := TowerLogic.new()
    t.cfg = c.duplicate(true)
    return t


func _strong() -> Dictionary:
    var v = cfg.get("strong", {})
    return v if typeof(v) == TYPE_DICTIONARY else {}


## tier 0 一般塔、1 強力塔(熊王牙強化)
func hp(tier: int = 0) -> float:
    if tier >= 1:
        return maxf(float(_strong().get("hp", 2000.0)), 1.0)
    return maxf(float(cfg.get("hp", 800.0)), 1.0)


## 每一箭的傷害(tier 強力塔的基礎值 × 傷害升級倍率)
func damage(tier: int = 0, damage_level: int = 0) -> float:
    var base := maxf(float(_strong().get("damage", 25.0)), 0.0) if tier >= 1 else maxf(float(cfg.get("damage", 10.0)), 0.0)
    return base * damage_mult(damage_level)


func _upgrade() -> Dictionary:
    var v = cfg.get("upgrade", {})
    return v if typeof(v) == TYPE_DICTIONARY else {}


## 每次升級的價格
func upgrade_cost() -> int:
    return maxi(int(_upgrade().get("cost", 500)), 0)


## 射速 / 傷害各最多升幾次
func max_upgrades() -> int:
    return maxi(int(_upgrade().get("maxEach", 10)), 0)


## 站在塔旁幾秒開升級面板、算「旁邊」的距離
func upgrade_dwell_sec() -> float:
    return maxf(float(_upgrade().get("dwellSec", 5.0)), 0.1)


func upgrade_radius() -> float:
    return maxf(float(_upgrade().get("radius", 2.4)), 0.3)


## 射速升級:射擊間隔倍率(每級 × rateMult)
func rate_mult(rate_level: int) -> float:
    return pow(clampf(float(_upgrade().get("rateMult", 0.92)), 0.1, 1.0), float(clampi(rate_level, 0, max_upgrades())))


## 傷害升級:倍率(1 + damagePerLevel × 級)
func damage_mult(damage_level: int) -> float:
    return 1.0 + maxf(float(_upgrade().get("damagePerLevel", 0.2)), 0.0) * float(clampi(damage_level, 0, max_upgrades()))


func max_tier() -> int:
    return 1


func attack_range() -> float:
    return maxf(float(cfg.get("range", 9.0)), 0.5)


func attack_interval(rate_level: int = 0) -> float:
    return maxf(float(cfg.get("attackIntervalSec", 0.8)) * rate_mult(rate_level), 0.05)


func arrow_speed() -> float:
    return maxf(float(cfg.get("arrowSpeed", 18.0)), 1.0)


## 一般熊咬一口扣多少血(王不看血量,直接咬 king_building_bite_sec 秒拆掉)
func bite_damage() -> float:
    return maxf(float(cfg.get("biteDamage", 40.0)), 0.0)


## 一般熊要咬幾口才拆得掉
func bites_to_break(tier: int = 0) -> int:
    if bite_damage() <= 0.0:
        return -1
    return int(ceil(hp(tier) / bite_damage()))


## 熊咬塔一口要幾秒
func bite_sec() -> float:
    return maxf(float(cfg.get("biteSec", 2.5)), 0.1)


## 熊離塔這麼近(或被塔射中時塔在這麼近)就改去拆塔
func aggro_radius() -> float:
    return maxf(float(cfg.get("aggroRadius", 7.0)), 0.5)


## 箭從多高射出(塔頂)
func height() -> float:
    return maxf(float(cfg.get("height", 3.0)), 0.5)


func in_range(dist: float) -> bool:
    return dist <= attack_range()


## 每秒傷害
func dps(tier: int = 0) -> float:
    return damage(tier) / attack_interval()


## 射死一隻 bear_hp 血的熊要幾箭
func shots_to_kill(bear_hp: float, tier: int = 0) -> int:
    if damage(tier) <= 0.0:
        return -1
    return int(ceil(maxf(bear_hp, 0.0) / damage(tier)))


## 射程內最近的活熊:bears = [{"id", "pos": Vector3, "alive": bool}],回 id;沒有回 -1
static func pick_target(from: Vector3, bears: Array, range: float) -> int:
    var best := -1
    var best_d := INF
    for b in bears:
        if typeof(b) != TYPE_DICTIONARY or not b.has("pos") or not bool(b.get("alive", true)):
            continue
        var pos: Vector3 = b["pos"]
        var d := Vector2(pos.x - from.x, pos.z - from.z).length()
        if d <= range and d < best_d:
            best_d = d
            best = int(b.get("id", -1))
    return best
