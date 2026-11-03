class_name ConveyorLogic
extends RefCounted
## 傳送帶規則(純資料,數值在 game.json conveyor):從工作站輸出堆每 1 / itemsPerSec 秒拿一件放上帶子,
## 件件以 speed 前進、彼此至少隔 spacing,到末端(length)時櫃台放得下就上架,放不下就在末端排隊(帶子停住、不再拿貨)。
## items 是每件在帶上的位置(0 起點 ~ length 末端),items[0] 是最前面那件。tick() 回 {"taken": 本幀拿了幾件, "delivered": 本幀上架幾件}。

var length := 5.0
var speed := 3.0
var rate := 1.0        # 每秒拿幾件
var spacing := 0.8
var items: Array[float] = []
var moved_total := 0   # 累計上架幾件

var _timer := 0.0


static func from_config(c: Dictionary, belt_length: float) -> ConveyorLogic:
    var l := ConveyorLogic.new()
    var cfg := c if c != null else {}
    l.length = maxf(belt_length, 0.5)
    l.speed = maxf(float(cfg.get("speed", 3.0)), 0.1)
    l.rate = maxf(float(cfg.get("itemsPerSec", 1.0)), 0.01)
    l.spacing = maxf(float(cfg.get("spacing", 0.8)), 0.1)
    return l


## 帶子上最多放幾件
func capacity() -> int:
    return maxi(int(floor(length / spacing)) + 1, 1)


## 起點空著(最後一件已經走開 spacing)才能再放一件
func can_take() -> bool:
    if items.size() >= capacity():
        return false
    return items.is_empty() or items[items.size() - 1] >= spacing


func count() -> int:
    return items.size()


func is_empty() -> bool:
    return items.is_empty()


func tick(delta: float, source_count: int, dest_space: int) -> Dictionary:
    var taken := 0
    var delivered := 0
    # 前進:前面那件擋住就停在它後面 spacing 處
    var limit := length
    for i in items.size():
        items[i] = minf(items[i] + speed * delta, limit)
        limit = maxf(items[i] - spacing, 0.0)
    # 到末端:櫃台放得下就上架
    while not items.is_empty() and items[0] >= length - 0.001 and dest_space > 0:
        items.remove_at(0)
        dest_space -= 1
        delivered += 1
    # 從來源拿
    var interval := 1.0 / rate
    _timer = minf(_timer + delta, interval)
    while _timer >= interval and source_count > 0 and can_take():
        _timer -= interval
        items.append(0.0)
        source_count -= 1
        taken += 1
    moved_total += delivered
    return {"taken": taken, "delivered": delivered}


## 存檔:帶上每件的位置
func snapshot() -> Array:
    var out := []
    for p in items:
        out.append(float(p))
    return out


func restore(positions: Array) -> void:
    items.clear()
    for p in positions:
        items.append(clampf(float(p), 0.0, length))
    items.sort()
    items.reverse()
    while items.size() > capacity():
        items.pop_back()
