class_name ItemStack
extends RefCounted
## 身上(或某個格子上)的一疊物品:同一時間只裝一種物品,有容量上限。
## 空疊可以放任何物品;放不同種類要先清空(跟參考遊戲一樣,魚與魚片不能混疊)。

signal changed

var capacity := 8
var item_id := ""   # "" = 空
var count := 0


func is_empty() -> bool:
    return count <= 0


func is_full() -> bool:
    return count >= capacity


func can_push(id: String) -> bool:
    if id == "" or count >= capacity:
        return false
    return item_id == "" or item_id == id or count == 0


## 還能放幾個 id(種類不同就 0)
func space_for(id: String) -> int:
    if not can_push(id):
        return 0
    return capacity - count


func push(id: String) -> bool:
    if not can_push(id):
        return false
    item_id = id
    count += 1
    changed.emit()
    return true


## 拿掉最上面一個,回傳物品 id(空疊回 "")
func pop() -> String:
    if count <= 0:
        return ""
    var id := item_id
    count -= 1
    if count == 0:
        item_id = ""
    changed.emit()
    return id


func clear() -> void:
    if count == 0 and item_id == "":
        return
    count = 0
    item_id = ""
    changed.emit()


func set_capacity(value: int) -> void:
    capacity = maxi(value, 1)
    if count > capacity:
        count = capacity
    changed.emit()
