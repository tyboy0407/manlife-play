class_name PurchaseLogic
extends RefCounted
## 價格牌規則:總價、剩餘、付清後的效果。付款可分期(站上去一張張扣,走開就暫停)。
## repeatable 的牌可以買 max_buys 次,每次價格乘 cost_mult;買滿就 exhausted(牌子消失)。

var id := ""
var name_key := ""
var cost := 10
var remaining := 10
var effect := {}
var repeatable := false
var max_buys := 1
var cost_mult := 1.5
var buys := 0


static func from_def(d: Dictionary) -> PurchaseLogic:
    var p := PurchaseLogic.new()
    p.id = str(d.get("id", ""))
    p.name_key = str(d.get("name", "SHOP_%s" % p.id))
    p.cost = maxi(int(d.get("cost", 10)), 1)
    p.repeatable = bool(d.get("repeatable", false))
    p.max_buys = maxi(int(d.get("maxBuys", 1)), 1) if p.repeatable else 1
    p.cost_mult = maxf(float(d.get("costMult", 1.5)), 1.0)
    p.remaining = p.cost
    var e = d.get("effect", {})
    if typeof(e) == TYPE_DICTIONARY:
        p.effect = e.duplicate(true)
    return p


## 這一次(第 buys + 1 次)的總價
func current_cost() -> int:
    return maxi(int(round(float(cost) * pow(cost_mult, float(buys)))), 1)


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


## 付清後結算:買次數 +1;還能再買就把價格重設成下一次的
func complete() -> void:
    buys += 1
    remaining = current_cost() if buys < max_buys else 0


func progress() -> float:
    if is_exhausted():
        return 1.0
    return 1.0 - float(remaining) / float(current_cost())


## 存檔還原
func restore(p_buys: int, p_remaining: int) -> void:
    buys = clampi(p_buys, 0, max_buys)
    remaining = 0 if is_exhausted() else clampi(p_remaining, 0, current_cost())
    if remaining == 0 and not is_exhausted():
        remaining = current_cost()
