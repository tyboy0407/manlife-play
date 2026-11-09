class_name LegacyLogic
extends RefCounted
## 傳承 / 過冬重生的純規則(數值在 game.json legacy):
## 本輪綜合評分 = 收入分(累積收入 / cashPerPoint)+ 建設分(擴建 / 塔 / 工作站 / 櫃台 / 傳送帶)+ 戰績分(打跑熊 / 打死王每級遞增 / perfect)
## + 故事分(本輪解鎖的章節 / 結局);傳承點數 = floor(sqrt(總分) / pointsDiv),開根號讓後期點數不會爆。
## 火種(perks):固定幾項、每項幾級、逐級點數價(costs),加成 = perLevel × 等級;過冬後留下,新一代開局就吃到。

var cfg := {}
var perks: Array = []          # [{id, perLevel, costs[]}](依 game.json 順序)
var _perk_by_id := {}


static func from_config(c: Dictionary) -> LegacyLogic:
    var l := LegacyLogic.new()
    l.cfg = c.duplicate(true)
    var ps = c.get("perks", [])
    if typeof(ps) == TYPE_ARRAY:
        for p in ps:
            if typeof(p) == TYPE_DICTIONARY and p.has("id"):
                l.perks.append(p)
                l._perk_by_id[str(p["id"])] = p
    return l


func _w(key: String, default: float) -> float:
    var s = cfg.get("score", {})
    return float(s.get(key, default)) if typeof(s) == TYPE_DICTIONARY else default


## 打死王的分:第 i 次(從 0 起)給 kingBase × (min(i, kingMaxLevel) + 1),王越高級越值錢
func king_score(kills: int) -> int:
    var base := _w("kingBase", 200.0)
    var cap := int(_w("kingMaxLevel", 5.0))
    var total := 0.0
    for i in maxi(kills, 0):
        total += base * float(mini(i, cap) + 1)
    return int(round(total))


## 本輪評分明細;s:{cash_earned, expansions, towers, stations, counters, belts, bears_fled, king_kills, king_perfects, chapters, ending}
func score(s: Dictionary) -> Dictionary:
    var per_cash := maxf(float(cfg.get("cashPerPoint", 100.0)), 1.0)
    var income := int(floor(float(maxi(int(s.get("cash_earned", 0)), 0)) / per_cash))
    # 起始就有的切魚台 / 櫃台 / 第一章不算分(freeStations / freeCounters / freeChapters),不然剛過冬就能再換點數
    var stations := maxi(int(s.get("stations", 0)) - int(_w("freeStations", 1.0)), 0)
    var counters := maxi(int(s.get("counters", 0)) - int(_w("freeCounters", 1.0)), 0)
    var chapters := maxi(int(s.get("chapters", 0)) - int(_w("freeChapters", 1.0)), 0)
    var build := int(round(_w("expansion", 300.0) * float(s.get("expansions", 0)) + _w("tower", 50.0) * float(s.get("towers", 0))
            + _w("station", 30.0) * float(stations) + _w("counter", 30.0) * float(counters)
            + _w("belt", 20.0) * float(s.get("belts", 0))))
    var battle := int(round(_w("bear", 5.0) * float(s.get("bears_fled", 0)) + _w("perfect", 100.0) * float(s.get("king_perfects", 0)))) \
            + king_score(int(s.get("king_kills", 0)))
    var story := int(round(_w("chapter", 100.0) * float(chapters) + (_w("ending", 1000.0) if bool(s.get("ending", false)) else 0.0)))
    var total := maxi(income, 0) + maxi(build, 0) + maxi(battle, 0) + maxi(story, 0)
    return {"income": maxi(income, 0), "build": maxi(build, 0), "battle": maxi(battle, 0), "story": maxi(story, 0), "total": total}


## 總分換傳承點數:floor(sqrt(總分) / pointsDiv)
func points_for(total: int) -> int:
    var div := maxf(float(cfg.get("pointsDiv", 10.0)), 0.01)
    return int(floor(sqrt(float(maxi(total, 0))) / div))


## 低於這個點數過冬會標紅提醒不划算
func low_points() -> int:
    return int(cfg.get("lowPoints", 3))


func perk(id: String) -> Dictionary:
    var p = _perk_by_id.get(id, {})
    return p if typeof(p) == TYPE_DICTIONARY else {}


func perk_ids() -> Array[String]:
    var out: Array[String] = []
    for p in perks:
        out.append(str(p["id"]))
    return out


func max_level(id: String) -> int:
    var cs = perk(id).get("costs", [])
    return cs.size() if typeof(cs) == TYPE_ARRAY else 0


## 從 level 升到 level + 1 要幾點;滿級(或沒這項)回 -1
func perk_cost(id: String, level: int) -> int:
    var cs = perk(id).get("costs", [])
    if typeof(cs) != TYPE_ARRAY or level < 0 or level >= cs.size():
        return -1
    return int(cs[level])


func per_level(id: String) -> float:
    return float(perk(id).get("perLevel", 0.0))


## 加成 = perLevel × 等級(start_cash 是元、bear_delay 是秒、capacity 是件、其他是比例)
func bonus(id: String, level: int) -> float:
    return per_level(id) * float(clampi(level, 0, max_level(id)))


func can_buy(points: int, id: String, level: int) -> bool:
    var c := perk_cost(id, level)
    return c >= 0 and points >= c


## 全部火種的總等級(統計用)
static func total_levels(levels: Dictionary) -> int:
    var n := 0
    for k in levels:
        n += maxi(int(levels[k]), 0)
    return n
