class_name TowerLogic
extends RefCounted
## 守衛塔規則(純資料,可 headless 測試):血量、每箭傷害、射程、射速、箭速、一般熊咬一口扣多少、咬一口幾秒、
## 熊離塔多近會改去拆塔(aggroRadius)。數值在 game.json tower {hp, damage, range, attackIntervalSec, arrowSpeed, biteDamage,
## biteSec, aggroRadius, height}:hp 800 / biteDamage 40 = 扛得住 20 口。北極熊王不看血量,咬滿 BearLogic.king_building_bite_sec 秒直接拆掉。
## 蓋 / 修的價格在 shop.json(tower_1 ~ tower_4,rebuyMult 1 = 修復同價)。

var cfg := {}


static func from_config(c: Dictionary) -> TowerLogic:
    var t := TowerLogic.new()
    t.cfg = c.duplicate(true)
    return t


func hp() -> float:
    return maxf(float(cfg.get("hp", 800.0)), 1.0)


## 每一箭的傷害
func damage() -> float:
    return maxf(float(cfg.get("damage", 10.0)), 0.0)


func attack_range() -> float:
    return maxf(float(cfg.get("range", 9.0)), 0.5)


func attack_interval() -> float:
    return maxf(float(cfg.get("attackIntervalSec", 0.8)), 0.05)


func arrow_speed() -> float:
    return maxf(float(cfg.get("arrowSpeed", 18.0)), 1.0)


## 一般熊咬一口扣多少血(王不看血量,直接咬 king_building_bite_sec 秒拆掉)
func bite_damage() -> float:
    return maxf(float(cfg.get("biteDamage", 40.0)), 0.0)


## 一般熊要咬幾口才拆得掉
func bites_to_break() -> int:
    if bite_damage() <= 0.0:
        return -1
    return int(ceil(hp() / bite_damage()))


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
func dps() -> float:
    return damage() / attack_interval()


## 射死一隻 bear_hp 血的熊要幾箭
func shots_to_kill(bear_hp: float) -> int:
    if damage() <= 0.0:
        return -1
    return int(ceil(maxf(bear_hp, 0.0) / damage()))


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
