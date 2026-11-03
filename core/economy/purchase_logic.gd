class_name PurchaseLogic
extends RefCounted
## 價格牌規則:總價、剩餘、付清後的效果。付款可分期(站上去一張張扣,走開就暫停)。
## repeatable 的牌可以買 max_buys 次,每次價格乘 cost_mult;買滿就 exhausted(牌子消失)。
## 僱用牌:幫手被北極熊吃掉 lose() 退一個名額(buys -1、lost +1),買回那一次的價格是該級價格 × rebuy_mult(1.5),
## 買回後回到正常的階梯價;已付的部分付款保留。擴建村莊 expand() 多開放 expandBuys 個名額(買滿消失的牌重新開放)。
## 守衛塔牌(effect tower):一次性,塔被拆 lose() -> 以 rebuyMult(1)的價格修復。
## currency:cash(錢包,預設)/ pelt(毛皮)/ tooth(熊王牙);costs [...] 可逐次指定價格(武器店升級 5 / 10 / 20),有就不用 cost × costMult。
## raise_max(n):武器店升級後武器牌多開放名額(買滿消失的牌重新出現,價格接著漲)。

var id := ""
var name_key := ""
var cost := 10
var remaining := 10
var effect := {}
var repeatable := false
var max_buys := 1
var cost_mult := 1.5
var buys := 0
var lost := 0           # 被吃掉、可以買回的名額
var rebuy_mult := 1.5   # 買回的價格倍率
var expand_buys := 0    # 擴建村莊後多開放的名額(shop.json expandBuys)
var expansions := 0        # 擴建了幾次(每次村莊擴建多開 expand_buys 個名額,最多 max_expansions 次)
var max_expansions := 3
var currency := "cash"   # 用什麼付:cash / pelt / tooth
var costs: Array = []    # 逐次價格(有就蓋過 cost × cost_mult)
var base_max_buys := 1   # shop.json 的 maxBuys(raise_max 前)


static func from_def(d: Dictionary) -> PurchaseLogic:
    var p := PurchaseLogic.new()
    p.id = str(d.get("id", ""))
    p.name_key = str(d.get("name", "SHOP_%s" % p.id))
    p.cost = maxi(int(d.get("cost", 10)), 1)
    p.repeatable = bool(d.get("repeatable", false))
    p.max_buys = maxi(int(d.get("maxBuys", 1)), 1) if p.repeatable else 1
    p.cost_mult = maxf(float(d.get("costMult", 1.5)), 1.0)
    p.rebuy_mult = maxf(float(d.get("rebuyMult", 1.5)), 0.0)   # 修復牌可以比原價便宜(守衛塔 0.5)
    p.expand_buys = maxi(int(d.get("expandBuys", 0)), 0)
    p.base_max_buys = p.max_buys
    p.currency = str(d.get("currency", "cash"))
    var cl = d.get("costs", [])
    if typeof(cl) == TYPE_ARRAY:
        for c in cl:
            p.costs.append(maxi(int(c), 1))
    if not p.costs.is_empty():
        p.cost = p.costs[0]
    p.remaining = p.current_cost()
    var e = d.get("effect", {})
    if typeof(e) == TYPE_DICTIONARY:
        p.effect = e.duplicate(true)
    return p


## 這一次(第 buys + 1 次)的總價;正在買回被吃掉的名額時再乘 rebuy_mult
func current_cost() -> int:
    var c := float(cost) * pow(cost_mult, float(buys))
    if not costs.is_empty():
        c = float(costs[mini(maxi(buys, 0), costs.size() - 1)])
    if lost > 0:
        c *= rebuy_mult
    return maxi(int(round(c)), 1)


func is_rebuy() -> bool:
    return lost > 0


## 幫手被吃掉:退一個名額,改成買回價(已付的部分保留);沒買過就沒得退,回 false
func lose() -> bool:
    if buys <= 0:
        return false
    var paid := maxi(current_cost() - remaining, 0) if not is_exhausted() else 0
    buys -= 1
    lost += 1
    remaining = maxi(current_cost() - paid, 1)
    return true


## 擴建村莊:多開放 expand_buys 個名額(每次擴建加一次,最多 max_expansions 次);買滿消失的牌重新開放,價格是下一級。沒名額可加回 false
func expand() -> bool:
    if expansions >= max_expansions or expand_buys <= 0:
        return false
    var was_exhausted := is_exhausted()
    expansions += 1
    max_buys += expand_buys
    if was_exhausted:
        remaining = current_cost()
    return true


## 名額上限提高到 n(武器店升級後武器牌多賣一級);買滿消失的牌重新開放。沒變回 false
func raise_max(n: int) -> bool:
    if n <= max_buys:
        return false
    var was_exhausted := is_exhausted()
    max_buys = n
    if was_exhausted:
        remaining = current_cost()
    return true


func is_cash() -> bool:
    return currency == "cash"


## 付 amount 元,回傳實際收下的(付清後多的不收)
func pay(amount: int) -> int:
    if is_exhausted():
        return 0
    var accepted := mini(maxi(amount, 0), remaining)
    remaining -= accepted
    return accepted


func is_paid() -> bool:
    return remaining <= 0 and not is_exhausted()


func is_exhausted() -> bool:
    return buys >= max_buys


## 付清後結算:買次數 +1(買回就把退掉的名額補回來);還能再買就把價格重設成下一次的
func complete() -> void:
    buys += 1
    if lost > 0:
        lost -= 1
    remaining = current_cost() if buys < max_buys else 0


func progress() -> float:
    if is_exhausted():
        return 1.0
    return 1.0 - float(remaining) / float(current_cost())


## 存檔還原
func restore(p_buys: int, p_remaining: int, p_lost: int = 0) -> void:
    buys = clampi(p_buys, 0, max_buys)
    lost = clampi(p_lost, 0, max_buys - buys)
    remaining = 0 if is_exhausted() else clampi(p_remaining, 0, current_cost())
    if remaining == 0 and not is_exhausted():
        remaining = current_cost()
