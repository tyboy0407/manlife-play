class_name PorterPlanner
extends RefCounted
## 搬運工派工規則(純資料,可 headless 測試):哪裡最缺貨就先補哪裡。
## dests(目的地):[{"id": 唯一鍵, "kind": "counter" / "station", "item": 收什麼, "stock": 現有, "cap": 上限, "out": 工作站的成品 id}]
##   (可以多帶 "node" 等鍵,原樣回傳給呼叫端用)
## sources(來源 = 工作站輸出堆):[{"id": 唯一鍵, "item": 成品 id, "count": 數量}]
## 需求分數:櫃台 = 1 - stock / cap(越空越急);工作站原料 = STATION_FACTOR × 下游(吃它成品的目的地)最高需求 × 原料空位比例。
## 所以烤魚櫃台空了、烤魚攤又沒成品時,會先把魚片送去烤魚攤,而不是堆到還有貨的魚片櫃台。

const STATION_FACTOR := 0.9
const MAX_DEPTH := 4


static func space_of(dest: Dictionary) -> int:
    return maxi(int(dest.get("cap", 0)) - int(dest.get("stock", 0)), 0)


## dest 的需求分數(0 ~ 1)
static func need_of(dest: Dictionary, dests: Array, depth: int = 0) -> float:
    var cap := maxi(int(dest.get("cap", 0)), 1)
    var space_ratio := clampf(float(space_of(dest)) / float(cap), 0.0, 1.0)
    if str(dest.get("kind", "counter")) == "counter":
        return space_ratio
    if depth >= MAX_DEPTH:
        return 0.0
    var out := str(dest.get("out", ""))
    var downstream := 0.0
    for d in dests:
        if d.get("id") != dest.get("id") and str(d.get("item", "")) == out:
            downstream = maxf(downstream, need_of(d, dests, depth + 1))
    return STATION_FACTOR * downstream * space_ratio


## 派工:需求最高、且有來源可搬的目的地。回 {"from": source, "to": dest, "item", "amount"};沒事做回空字典。
## amount = min(背包容量, 目的地空位, 來源數量):只拿放得下的,到了才不會卸不掉。
static func plan(dests: Array, sources: Array, capacity: int) -> Dictionary:
    var best := {}
    var best_need := -1.0
    for dest in dests:
        if space_of(dest) <= 0:
            continue
        var need := need_of(dest, dests)
        if need <= best_need:
            continue
        var item := str(dest.get("item", ""))
        var src := best_source(sources, item, dest.get("id"))
        if src.is_empty():
            continue
        best_need = need
        best = {"from": src, "to": dest, "item": item,
                "amount": mini(mini(maxi(capacity, 1), space_of(dest)), int(src.get("count", 0)))}
    return best


## 有 item 成品最多的來源(排除 exclude_id)
static func best_source(sources: Array, item: String, exclude_id = null) -> Dictionary:
    var best := {}
    var best_count := 0
    for s in sources:
        if str(s.get("item", "")) != item or int(s.get("count", 0)) <= best_count:
            continue
        if exclude_id != null and s.get("id") == exclude_id:
            continue
        best = s
        best_count = int(s.get("count", 0))
    return best


## 手上已經有 item 時該送去哪:收 item 且還有空位的目的地裡需求最高的(需求 0 也行,總比抱著貨卡住好);沒有回空字典
static func best_dest(dests: Array, item: String, exclude_id = null) -> Dictionary:
    var best := {}
    var best_need := -1.0
    for d in dests:
        if str(d.get("item", "")) != item or space_of(d) <= 0:
            continue
        if exclude_id != null and d.get("id") == exclude_id:
            continue
        var need := need_of(d, dests)
        if need > best_need:
            best = d
            best_need = need
    return best
