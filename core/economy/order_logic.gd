class_name OrderLogic
extends RefCounted
## 訂單系統規則(純資料,數值在 game.json orders):村外碼頭停一艘貨船,每隔一段時間貼一張限時訂單
## (2 ~ 3 種櫃台賣的貨各 N 件,偶爾多要一條稀有魚),玩家或搬運工把貨送到碼頭的交貨格就扣;
## 送齊給現金 = 市價總和 × rewardMult,再隨機附一樣(毛皮 bonusPelts 張或一張券);逾時訂單消失、無懲罰,下一張照常來。
## 擴建越多:訂單越頻繁(intervalSec × intervalMult^擴建次數,最低 minIntervalSec)、每種要得越多(perKindBase + perKindPerExpansion × 擴建次數)。
## 同時最多一張。tick(delta) 回傳 "new"(需要呼叫端 generate)/ "expired" / ""。

const RARE_ITEM := "rarefish"

var cfg := {}
var order := {}            # 目前的訂單 {"lines": {item: {"need", "done", "price"}}, "time_left", "reward", "bonus": {"kind", "amount" / "coupon"}, "total"}
var next_in := 0.0         # 幾秒後貼下一張(沒訂單時倒數)
var completed_total := 0
var expired_total := 0
var delivered_total := 0
var rng := RandomNumberGenerator.new()


static func from_config(d: Dictionary) -> OrderLogic:
    var o := OrderLogic.new()
    o.cfg = d if d != null else {}
    o.next_in = o.first_delay()
    o.rng.randomize()
    return o


func first_delay() -> float:
    return maxf(float(cfg.get("firstDelaySec", 30.0)), 0.0)


## 兩張訂單之間的間隔(擴建越多越短)
func interval(expansion: int) -> float:
    var base := maxf(float(cfg.get("intervalSec", 150.0)), 1.0)
    var mult := clampf(float(cfg.get("intervalMult", 0.85)), 0.1, 1.0)
    return maxf(base * pow(mult, float(maxi(expansion, 0))), maxf(float(cfg.get("minIntervalSec", 60.0)), 1.0))


func time_limit() -> float:
    return maxf(float(cfg.get("timeLimitSec", 240.0)), 5.0)


## 每種貨要幾件
func per_kind(expansion: int) -> int:
    return maxi(int(cfg.get("perKindBase", 6)) + int(cfg.get("perKindPerExpansion", 3)) * maxi(expansion, 0), 1)


func kinds_range() -> Vector2i:
    var k = cfg.get("kinds", [2, 3])
    if typeof(k) == TYPE_ARRAY and k.size() >= 2:
        return Vector2i(maxi(int(k[0]), 1), maxi(int(k[1]), int(k[0])))
    return Vector2i(2, 3)


func reward_mult() -> float:
    return maxf(float(cfg.get("rewardMult", 2.0)), 0.0)


func rare_price() -> int:
    return maxi(int(cfg.get("rarePrice", 60)), 0)


func has_order() -> bool:
    return not order.is_empty()


## 可以要哪些貨:menu = {item: price}(有櫃台在賣的貨),exclude 清單(毛衣要毛皮做,不列入)
func pool(menu: Dictionary) -> Array:
    var ex = cfg.get("exclude", [])
    var out := []
    for item in menu:
        if typeof(ex) == TYPE_ARRAY and ex.has(item):
            continue
        out.append(str(item))
    out.sort()
    return out


## 貼一張新訂單:從 menu 挑 kinds 種,各 per_kind 件;roll_rare < rareChance 就多要一條稀有魚。menu 空的回空字典(不貼)
func generate(menu: Dictionary, expansion: int, roll_rare: float = 1.0) -> Dictionary:
    var items := pool(menu)
    if items.is_empty():
        return {}
    var kr := kinds_range()
    var n := mini(rng.randi_range(kr.x, kr.y), items.size())
    var picked: Array = []
    var remaining := items.duplicate()
    for i in n:
        var idx := rng.randi_range(0, remaining.size() - 1)
        picked.append(remaining[idx])
        remaining.remove_at(idx)
    picked.sort()
    var lines := {}
    var total := 0
    var per := per_kind(expansion)
    for item in picked:
        var price := int(menu.get(item, 0))
        lines[item] = {"need": per, "done": 0, "price": price}
        total += per * price
    if roll_rare < clampf(float(cfg.get("rareChance", 0.25)), 0.0, 1.0):
        lines[RARE_ITEM] = {"need": 1, "done": 0, "price": rare_price()}
        total += rare_price()
    var bonus := {}
    if rng.randf() < clampf(float(cfg.get("bonusPeltChance", 0.5)), 0.0, 1.0):
        bonus = {"kind": "pelt", "amount": maxi(int(cfg.get("bonusPelts", 3)), 1)}
    else:
        bonus = {"kind": "coupon", "coupon": KingLogic.COUPONS[rng.randi_range(0, KingLogic.COUPONS.size() - 1)]}
    order = {"lines": lines, "time_left": time_limit(), "total": total, "reward": int(round(float(total) * reward_mult())), "bonus": bonus}
    return order


## 訂單還要 item 幾件(沒訂單 / 不要這種回 0)
func need_of(item: String) -> int:
    if order.is_empty():
        return 0
    var l = order["lines"].get(item, null)
    if typeof(l) != TYPE_DICTIONARY:
        return 0
    return maxi(int(l["need"]) - int(l["done"]), 0)


## 訂單要的貨裡,還沒送齊的種類
func wanted_items() -> Array:
    var out := []
    if order.is_empty():
        return out
    for item in order["lines"]:
        if need_of(str(item)) > 0:
            out.append(str(item))
    return out


## 送 n 件 item 到碼頭:回傳收下幾件
func deliver(item: String, n: int) -> int:
    var accepted := mini(maxi(n, 0), need_of(item))
    if accepted > 0:
        order["lines"][item]["done"] = int(order["lines"][item]["done"]) + accepted
        delivered_total += accepted
    return accepted


func is_complete() -> bool:
    return not order.is_empty() and wanted_items().is_empty()


## 送齊了:結清,回傳 {reward, bonus};沒送齊回空字典
func complete() -> Dictionary:
    if not is_complete():
        return {}
    var out := {"reward": int(order["reward"]), "bonus": order["bonus"], "total": int(order["total"])}
    order = {}
    completed_total += 1
    return out


func progress() -> float:
    if order.is_empty():
        return 0.0
    var need := 0
    var done := 0
    for item in order["lines"]:
        need += int(order["lines"][item]["need"])
        done += int(order["lines"][item]["done"])
    return float(done) / float(maxi(need, 1))


## 每幀:有訂單就倒數時限(到了 "expired",訂單消失、重新倒數下一張);沒訂單就倒數 next_in(到了回 "new",呼叫端 generate)
func tick(delta: float, expansion: int) -> String:
    if not order.is_empty():
        order["time_left"] = float(order["time_left"]) - delta
        if float(order["time_left"]) <= 0.0:
            order = {}
            expired_total += 1
            next_in = interval(expansion)
            return "expired"
        return ""
    next_in -= delta
    if next_in <= 0.0:
        next_in = interval(expansion)   # 呼叫端 generate 失敗(沒櫃台)也要等下一輪
        return "new"
    return ""


func snapshot() -> Dictionary:
    return {"order": order.duplicate(true), "next_in": next_in, "completed": completed_total, "expired": expired_total, "delivered": delivered_total}


func restore(d: Dictionary) -> void:
    var o = d.get("order", {})
    order = {}
    if typeof(o) == TYPE_DICTIONARY and typeof(o.get("lines", null)) == TYPE_DICTIONARY and not o["lines"].is_empty():
        order = o.duplicate(true)
        order["time_left"] = maxf(float(order.get("time_left", 0.0)), 1.0)
    next_in = maxf(float(d.get("next_in", first_delay())), 0.0)
    completed_total = maxi(int(d.get("completed", 0)), 0)
    expired_total = maxi(int(d.get("expired", 0)), 0)
    delivered_total = maxi(int(d.get("delivered", 0)), 0)
