class_name CounterLogic
extends RefCounted
## 櫃台規則:上架庫存(有上限)、每件售價;顧客要 want 件,賣得出幾件就收幾件的錢。

var item_id := "fillet"
var stock := 0
var stock_cap := 30
var price := 2


func space() -> int:
    return stock_cap - stock


func add_stock(n: int = 1) -> int:
    var accepted := mini(maxi(n, 0), space())
    stock += accepted
    return accepted


## 回傳 {"sold": 件數, "cash": 收入}
func serve(want: int) -> Dictionary:
    var sold := mini(maxi(want, 0), stock)
    stock -= sold
    return {"sold": sold, "cash": sold * price}


## 顧客要幾件:weights[i] 是「要 i + 1 件」的權重(customers.wantWeights),roll 0 ~ 1;沒權重就 1 件
static func roll_want(weights: Array, roll: float) -> int:
    var total := 0.0
    for w in weights:
        total += maxf(float(w), 0.0)
    if total <= 0.0:
        return 1
    var acc := 0.0
    for i in weights.size():
        acc += maxf(float(weights[i]), 0.0) / total
        if roll < acc:
            return i + 1
    return weights.size()


## 擴建後顧客要得更多:權重往多件偏 shift 件(前面補 shift 個 0 = 1 ~ shift 件不會出現),最多要 max_items 件;
## 全被切掉就只留最後一格(都要 max_items 件)
static func shift_weights(weights: Array, shift: int, max_items: int = 9) -> Array:
    var out: Array = []
    for i in maxi(shift, 0):
        out.append(0)
    for w in weights:
        out.append(w)
    if max_items >= 1 and out.size() > max_items:
        var kept: Array = out.slice(0, max_items)
        var total := 0.0
        for w in kept:
            total += maxf(float(w), 0.0)
        if total <= 0.0:
            kept[max_items - 1] = 1
        out = kept
    return out
