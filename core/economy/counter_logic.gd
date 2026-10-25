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
