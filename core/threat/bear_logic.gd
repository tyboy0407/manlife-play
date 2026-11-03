class_name BearLogic
extends RefCounted
## 北極熊規則(純資料,可 headless 測試):多久來一次(冷卻,遊戲時間越久越密)、盯上誰(最近的幫手)、咬多久吃掉、
## 血量(遊戲時間越久越厚)、玩家武器各級的攻擊力與距離、北極熊王的參數。
## 數值在 game.json:bear {firstDelaySec, intervalSec [min, max], intervalMin [min, max], rampStartSec, rampSec, hpBase, hpPerMin,
## speed, fleeSpeed, biteSec, biteRadius, panicRadius, entries [[x, z]...], entriesExpanded, packChances [[隻數, 機率]...],
## king {atSec, respawnSec, hpMult, biteSec, fishBiteSec, buildingBiteSec, scale, growHelper, growFish, maxScale, healFish, healHelper}}
## 王吃魚 / 吃幫手只變大不回血(healFish / healHelper 0),咬建築(工作站 / 守衛塔)buildingBiteSec 秒就拆掉。
## 與 weapon {attackIntervalSec, levels: [{damage, range, model {file, length}}...]}(第 i 項 = 武器 Lv i+1;Lv0 = 沒武器,打不了)。

var cfg := {}
var weapon_cfg := {}
var levels: Array = []


static func from_config(bear_cfg: Dictionary, weapon_cfg: Dictionary) -> BearLogic:
    var b := BearLogic.new()
    b.cfg = bear_cfg.duplicate(true)
    b.weapon_cfg = weapon_cfg.duplicate(true)
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


## 遊戲時間到幾秒之前完全不來(第一群的最早時間)
func first_at_sec() -> float:
    return maxf(float(cfg.get("firstAtSec", 0.0)), 0.0)


## 一群熊總共最多吃幾個幫手就撤退(0 = 不限)
func pack_max_eats() -> int:
    return maxi(int(cfg.get("packMaxEats", 0)), 0)


## 玩家帶武器時,熊在這個距離內就先不抓魚 / 不拿貨(專心打熊)
func busy_radius() -> float:
    return maxf(float(cfg.get("busyRadius", 0.0)), 0.0)


## 掉幾個:一般熊 dropCount [最少, 最多] 用 roll 抽;王 king.dropCount 固定
func drop_count(king: bool, roll: float) -> int:
    if king:
        return maxi(int(_king().get("dropCount", 1)), 0)
    var dc = cfg.get("dropCount", 1)
    if typeof(dc) == TYPE_ARRAY and dc.size() >= 2:
        var lo := int(dc[0])
        var hi := int(dc[1])
        return clampi(lo + int(clampf(roll, 0.0, 0.999) * float(hi - lo + 1)), lo, hi)
    return maxi(int(dc), 0)


static func _range(v, fallback: Vector2) -> Vector2:
    if typeof(v) == TYPE_ARRAY and v.size() >= 2:
        return Vector2(maxf(float(v[0]), 0.0), maxf(float(v[1]), float(v[0])))
    return fallback


## 之後每隔多久來一群(最短、最長):遊戲時間 elapsed 秒;rampStartSec 之前用 intervalSec,之後在 rampSec 內線性縮到 intervalMin
func interval(elapsed: float = 0.0) -> Vector2:
    var base := _range(cfg.get("intervalSec", null), Vector2(60.0, 90.0))
    var fast := _range(cfg.get("intervalMin", null), base)
    var t := ramp(elapsed)
    return Vector2(lerpf(base.x, fast.x, t), lerpf(base.y, fast.y, t))


## 難度曲線 0 ~ 1:rampStartSec 之前 0,之後 rampSec 秒內升到 1
func ramp(elapsed: float) -> float:
    var start := maxf(float(cfg.get("rampStartSec", 180.0)), 0.0)
    var dur := maxf(float(cfg.get("rampSec", 300.0)), 0.001)
    return clampf((elapsed - start) / dur, 0.0, 1.0)


## 熊走掉後下次要等多久:在 interval(elapsed) 之間取 roll(0 ~ 1)的位置
func next_cooldown(weapon_level: int, roll: float, elapsed: float = 0.0) -> float:
    var r := interval(elapsed)
    return lerpf(r.x, r.y, clampf(roll, 0.0, 1.0)) * cooldown_mult(weapon_level)


## 一隻熊的血量:hpBase + hpPerMin × 遊戲分鐘
func hp(elapsed: float) -> float:
    return maxf(float(cfg.get("hpBase", 30.0)) + float(cfg.get("hpPerMin", 10.0)) * elapsed / 60.0, 1.0)


## --- 北極熊王(cfg.king)---

func _king() -> Dictionary:
    var v = cfg.get("king", {})
    return v if typeof(v) == TYPE_DICTIONARY else {}


## 遊戲時間到幾秒出現
func king_at_sec() -> float:
    return maxf(float(_king().get("atSec", 300.0)), 0.0)


## 被打死後隔多久再來
func king_respawn_sec() -> float:
    return maxf(float(_king().get("respawnSec", 300.0)), 1.0)


func king_hp_mult() -> float:
    return maxf(float(_king().get("hpMult", 4.0)), 1.0)


func king_bite_sec() -> float:
    return maxf(float(_king().get("biteSec", 2.5)), 0.1)


func king_fish_bite_sec() -> float:
    return maxf(float(_king().get("fishBiteSec", 0.6)), 0.05)


func king_scale() -> float:
    return maxf(float(_king().get("scale", 1.6)), 0.5)


func king_grow_helper() -> float:
    return maxf(float(_king().get("growHelper", 1.15)), 1.0)


func king_grow_fish() -> float:
    return maxf(float(_king().get("growFish", 1.03)), 1.0)


func king_max_scale() -> float:
    return maxf(float(_king().get("maxScale", 2.4)), king_scale())


## 吃一條魚回多少血(血條上限的比例;預設 0 = 不回血)
func king_heal_fish() -> float:
    return clampf(float(_king().get("healFish", 0.0)), 0.0, 1.0)


## 吃一個幫手回多少血(血條上限的比例;預設 0 = 不回血)
func king_heal_helper() -> float:
    return clampf(float(_king().get("healHelper", 0.0)), 0.0, 1.0)


## 王咬建築(工作站 / 守衛塔)幾秒就拆掉
func king_building_bite_sec() -> float:
    return maxf(float(_king().get("buildingBiteSec", 10.0)), 0.1)


## 被打跑 / 打死時掉什麼(一般熊 bear.drop 毛皮 pelt;王 king.drop 熊王牙 tooth);空字串 = 不掉
func drop(king: bool = false) -> String:
    if king:
        return str(_king().get("drop", "tooth"))
    return str(cfg.get("drop", "pelt"))


## 武器店沒升級時賣幾級(weapon.shopBaseLevels,預設 3);每升一級多賣一級,最多到 weapon_max_level
func shop_base_levels() -> int:
    return clampi(int(weapon_cfg.get("shopBaseLevels", 3)), 0, maxi(weapon_max_level(), 0))


## 武器店 shop_level 級時武器牌可以買到第幾級
func weapon_levels_for_sale(shop_level: int) -> int:
    return clampi(shop_base_levels() + maxi(shop_level, 0), 0, weapon_max_level())


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


## 熊從哪幾個邊緣點進來(世界 XZ);expanded = 村莊擴建後用 entriesExpanded(沒設定就同 entries)
## 入口:擴建幾次就用 entriesExpanded<n>(沒有就退回上一級、再退回 entries)
func entries(expansion: int = 0) -> Array[Vector3]:
    var out: Array[Vector3] = []
    var v = null
    for e in range(expansion, 0, -1):
        v = cfg.get("entriesExpanded" if e == 1 else "entriesExpanded%d" % e, null)
        if typeof(v) == TYPE_ARRAY:
            break
    if typeof(v) != TYPE_ARRAY:
        v = cfg.get("entries", [])
    if typeof(v) == TYPE_ARRAY:
        for p in v:
            if typeof(p) == TYPE_ARRAY and p.size() >= 2:
                out.append(Vector3(float(p[0]), 0.0, float(p[1])))
    return out


## 一次來幾隻:packChances 依序累加機率,roll(0 ~ 1)落在哪段;沒設定或機率加總不到就 1 隻
func pack_size(roll: float) -> int:
    var v = cfg.get("packChances", [])
    if typeof(v) != TYPE_ARRAY:
        return 1
    var acc := 0.0
    for e in v:
        if typeof(e) != TYPE_ARRAY or e.size() < 2:
            continue
        acc += maxf(float(e[1]), 0.0)
        if roll < acc:
            return maxi(int(e[0]), 1)
    return 1


## --- 武器 ---

func weapon_max_level() -> int:
    return levels.size()


## 第 level 級的設定(Lv1 = levels[0]);Lv0 或超過就空字典
func weapon_level_cfg(level: int) -> Dictionary:
    if level <= 0 or levels.is_empty():
        return {}
    return levels[mini(level, levels.size()) - 1]


## level 級武器每一下的攻擊力;沒武器 0
func weapon_damage(level: int) -> float:
    return maxf(float(weapon_level_cfg(level).get("damage", 0.0)), 0.0)


## 離熊多近才打得到
func attack_range(level: int) -> float:
    return maxf(float(weapon_level_cfg(level).get("range", 1.8)), 0.1)


## 兩下之間隔幾秒
func attack_interval() -> float:
    return maxf(float(weapon_cfg.get("attackIntervalSec", 0.5)), 0.05)


func can_attack(level: int, dist: float) -> bool:
    return weapon_damage(level) > 0.0 and dist <= attack_range(level)


## 熊被打跑後下次冷卻的倍率(武器等級可設 cooldownMult,預設 1)
func cooldown_mult(level: int) -> float:
    return maxf(float(weapon_level_cfg(level).get("cooldownMult", 1.0)), 0.1)


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
