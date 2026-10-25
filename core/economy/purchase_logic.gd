class_name PurchaseLogic
extends RefCounted
## 價格牌規則:總價、剩餘、付清後的效果。付款可分期(站上去一張張扣,走開就暫停)。

var id := ""
var name_key := ""
var cost := 10
var remaining := 10
var effect := {}


static func from_def(d: Dictionary) -> PurchaseLogic:
    var p := PurchaseLogic.new()
    p.id = str(d.get("id", ""))
    p.name_key = str(d.get("name", "SHOP_%s" % p.id))
    p.cost = maxi(int(d.get("cost", 10)), 1)
    p.remaining = p.cost
    var e = d.get("effect", {})
    if typeof(e) == TYPE_DICTIONARY:
        p.effect = e.duplicate(true)
    return p


## 付 amount 元,回傳實際收下的(付清後多的不收)
func pay(amount: int) -> int:
    var accepted := mini(maxi(amount, 0), remaining)
    remaining -= accepted
    return accepted


func is_paid() -> bool:
    return remaining <= 0


func progress() -> float:
    return 1.0 - float(remaining) / float(cost)
