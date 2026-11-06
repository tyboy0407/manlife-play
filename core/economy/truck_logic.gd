class_name TruckLogic
extends RefCounted
## 雪地貨車規則(純資料,數值在 game.json truck):載 capacity 條魚、在魚池每 catchSec 撈一條、speed 格 / 秒、回到放置區每秒卸 unloadPerSec 條;
## 魚池空了 giveUpSec 秒(車上有魚)就先載回去。pick_pond:挑魚最多的池(都空就輪到下一個)。

var cfg := {}


static func from_config(c: Dictionary) -> TruckLogic:
    var t := TruckLogic.new()
    t.cfg = c if c != null else {}
    return t


func capacity() -> int:
    return maxi(int(cfg.get("capacity", 30)), 1)


func catch_sec() -> float:
    return maxf(float(cfg.get("catchSec", 0.7)), 0.05)


func speed() -> float:
    return maxf(float(cfg.get("speed", 7.0)), 0.1)


func unload_per_sec() -> float:
    return maxf(float(cfg.get("unloadPerSec", 8.0)), 0.1)


func give_up_sec() -> float:
    return maxf(float(cfg.get("giveUpSec", 12.0)), 0.1)


func is_full(fish: int) -> bool:
    return fish >= capacity()


## 該回程了嗎:滿了,或池子空了太久而車上有魚
func should_return(fish: int, empty_sec: float) -> bool:
    return is_full(fish) or (fish > 0 and empty_sec >= give_up_sec())


## 挑哪個魚池:魚最多的那個;都是 0 就輪到上一次的下一個;同分時不選上一次那個
static func pick_pond(counts: Array, last: int) -> int:
    if counts.is_empty():
        return -1
    var best := -1
    var best_n := -1
    for i in counts.size():
        var n := int(counts[i])
        if n > best_n or (n == best_n and best == last):
            best = i
            best_n = n
    if best_n <= 0:
        return (last + 1) % counts.size()
    return best
