class_name TrapLogic
extends RefCounted
## 捕熊夾 / 誘餌規則(純資料,數值在 game.json trap):
## 捕熊夾:一次性,熊走進 radius 內就夾到:扣 damage(王扣 kingDamage)並定住 stunSec 秒,夾子用掉(牌子重新出現可再買)。
## 誘餌魚堆:放好後 bait.radius 內的熊(王也是)會改去吃它,咬滿 bait.eatSec 秒吃光(消失,牌子重新出現)。

var cfg := {}
var ice := false   # 冰封夾(熊王祭壇解鎖):傷害 / 定住秒數用 cfg.ice


static func from_config(c: Dictionary) -> TrapLogic:
    var t := TrapLogic.new()
    t.cfg = c if c != null else {}
    return t


func _src() -> Dictionary:
    if ice:
        var i = cfg.get("ice", {})
        if typeof(i) == TYPE_DICTIONARY and not i.is_empty():
            return i
    return cfg


func damage(king: bool) -> float:
    var c := _src()
    if king:
        return maxf(float(c.get("kingDamage", cfg.get("kingDamage", 150.0))), 0.0)
    return maxf(float(c.get("damage", cfg.get("damage", 60.0))), 0.0)


func stun_sec() -> float:
    return maxf(float(_src().get("stunSec", cfg.get("stunSec", 3.0))), 0.0)


## 夾子的觸發半徑(熊走進來就夾)
func radius() -> float:
    return maxf(float(cfg.get("radius", 2.5)), 0.1)


func _bait() -> Dictionary:
    var b = cfg.get("bait", {})
    return b if typeof(b) == TYPE_DICTIONARY else {}


## 誘餌吸引熊的距離
func bait_radius() -> float:
    return maxf(float(_bait().get("radius", 8.0)), 0.1)


## 熊吃光誘餌要咬幾秒
func bait_eat_sec() -> float:
    return maxf(float(_bait().get("eatSec", 10.0)), 0.1)


## 誘餌堆裡擺幾條魚(外觀)
func bait_fish_count() -> int:
    return maxi(int(_bait().get("fishCount", 6)), 1)


## 夾子夾不夾得到:熊的位置到夾子的平面距離 <= radius
static func in_reach(trap_pos: Vector3, bear_pos: Vector3, r: float) -> bool:
    return Vector2(bear_pos.x - trap_pos.x, bear_pos.z - trap_pos.z).length() <= r


## 最近的、放好的誘餌(baits:[{id, pos, set}]),要在 r 內;沒有回 -1
static func pick_bait(from: Vector3, baits: Array, r: float) -> int:
    var best := -1
    var best_d := INF
    for b in baits:
        if typeof(b) != TYPE_DICTIONARY or not bool(b.get("set", false)) or not b.has("pos"):
            continue
        var pos: Vector3 = b["pos"]
        var d := Vector2(pos.x - from.x, pos.z - from.z).length()
        if d <= r and d < best_d:
            best_d = d
            best = int(b.get("id", -1))
    return best
