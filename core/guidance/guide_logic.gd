class_name GuideLogic
extends RefCounted
## 引導規則(純資料,可 headless 測試):新存檔的教學步驟 + 之後「當下最該做的事」的提示。
## 世界狀態用字典餵進來:
## {"carry_item", "carry_count", "wallet", "money_on_pad", "fish_caught", "items_sold", "purchases", "hired": {role: n},
##  "counters": [{"id", "item", "stock", "cap", "has_server", "has_cashier"}],
##  "stations": [{"id", "input", "input_count", "input_cap", "output", "output_count"}],
##  "pads": [{"id", "name", "remaining", "visible"}], "bear": 北極熊在不在, "weapon_level": 武器等級}
## 回傳的提示:{"kind": water / station_input / station_output / counter_deposit / service / money / pad / trash / bear / none,
##  "target": 目標 id(工作站 spot_id / 櫃台 def_id / 價格牌 id), "text": 翻譯鍵, "arg": 翻譯鍵 %s 要帶的翻譯鍵(可省)}

const TUTORIAL := [
    {"text": "TUT_fish"}, {"text": "TUT_to_station"}, {"text": "TUT_take"}, {"text": "TUT_to_counter"},
    {"text": "TUT_serve"}, {"text": "TUT_collect"}, {"text": "TUT_buy"},
]
const TUTORIAL_FISH := 4
const WEAPON_PAD := "weapon"   # 村外武器店的牌(shop.json id)


static func tutorial_steps() -> int:
    return TUTORIAL.size()


## 教學第 step 步(0 起)在這個狀態下算完成了沒;後面步驟的條件也算數(玩家跳著做、舊存檔都能推進)
static func tutorial_step_done(step: int, state: Dictionary) -> bool:
    var sold := int(state.get("items_sold", 0)) >= 1
    var bought := int(state.get("purchases", 0)) >= 1
    match step:
        0:
            return int(state.get("fish_caught", 0)) >= TUTORIAL_FISH or _any_station_busy(state) or _carrying(state, "fillet") \
                    or _any_counter_stocked(state) or sold or bought
        1:
            return _any_station_busy(state) or _carrying(state, "fillet") or _any_counter_stocked(state) or sold or bought
        2:
            return _carrying(state, "fillet") or _any_counter_stocked(state) or sold or bought
        3:
            return _any_counter_stocked(state) or sold or bought
        4:
            return sold or bought
        5:
            return int(state.get("wallet", 0)) >= 1 or bought
        6:
            return bought
    return true


## 教學第 step 步要指哪裡
static func tutorial_hint(step: int, state: Dictionary) -> Dictionary:
    if step < 0 or step >= TUTORIAL.size():
        return {}
    var text := str(TUTORIAL[step]["text"])
    match step:
        0:
            return {"kind": "water", "target": "", "text": text}
        1:
            return {"kind": "station_input", "target": str(_station_with_input(state, "fish").get("id", "")), "text": text}
        2:
            return {"kind": "station_output", "target": str(_station_with_most_output(state).get("id", "")), "text": text}
        3:
            return {"kind": "counter_deposit", "target": str(_counter_selling(state, "fillet").get("id", "")), "text": text}
        4:
            return {"kind": "service", "target": str(_counter_selling(state, "fillet").get("id", "")), "text": text}
        5:
            return {"kind": "money", "target": "", "text": text}
        6:
            var p := _cheapest_pad(state, -1)
            return {"kind": "pad", "target": str(p.get("id", "")), "text": text, "arg": str(p.get("name", ""))}
    return {}


## 教學之後的提示:當下最該做的事。北極熊在村裡最優先(沒武器指武器店的牌、有武器指熊);
## 手上有貨先處理貨;空手依序:買得起的牌 > 櫃台有貨沒人收銀 > 錢格有錢 > 工作站有成品(沒搬運工才提醒)> 去抓魚(有工作站收魚)> 沒事
static func hint(state: Dictionary) -> Dictionary:
    if bool(state.get("bear", false)):
        if int(state.get("weapon_level", 0)) <= 0:
            var wp := _pad_by_id(state, WEAPON_PAD)
            if not wp.is_empty():
                return {"kind": "pad", "target": WEAPON_PAD, "text": "HINT_BEAR_WEAPON"}
        return {"kind": "bear", "target": "", "text": "HINT_BEAR_CHASE"}
    var item := str(state.get("carry_item", ""))
    var count := int(state.get("carry_count", 0))
    if count > 0 and item != "":
        var ct := _counter_with_space(state, item)
        if not ct.is_empty():
            return {"kind": "counter_deposit", "target": str(ct["id"]), "text": "HINT_to_counter"}
        var st := _station_accepting(state, item)
        if not st.is_empty():
            return {"kind": "station_input", "target": str(st["id"]), "text": "HINT_to_station" if item == "fish" else "HINT_to_next_station"}
        var any_ct := _counter_selling(state, item)
        if not any_ct.is_empty():
            return {"kind": "counter_deposit", "target": str(any_ct["id"]), "text": "HINT_counter_full"}
        var any_st := _station_with_input(state, item)
        if not any_st.is_empty():
            return {"kind": "station_input", "target": str(any_st["id"]), "text": "HINT_station_full"}
        return {"kind": "trash", "target": "", "text": "HINT_trash"}
    var pad := _cheapest_pad(state, int(state.get("wallet", 0)))
    if not pad.is_empty():
        return {"kind": "pad", "target": str(pad["id"]), "text": "HINT_buy", "arg": str(pad.get("name", ""))}
    for c in state.get("counters", []):
        if int(c.get("stock", 0)) > 0 and not bool(c.get("has_server", false)) and not bool(c.get("has_cashier", false)):
            return {"kind": "service", "target": str(c["id"]), "text": "HINT_serve"}
    if int(state.get("money_on_pad", 0)) >= 1:
        return {"kind": "money", "target": "", "text": "HINT_money"}
    var hired = state.get("hired", {})
    var porters := int(hired.get("porter", 0)) if typeof(hired) == TYPE_DICTIONARY else 0
    if porters == 0:
        var out := _station_with_most_output(state)
        if not out.is_empty() and int(out.get("output_count", 0)) > 0:
            return {"kind": "station_output", "target": str(out["id"]), "text": "HINT_take"}
    if not _station_accepting(state, "fish").is_empty():
        return {"kind": "water", "target": "", "text": "HINT_fish"}
    return {"kind": "none", "target": "", "text": ""}


## --- 查詢 ---

static func _carrying(state: Dictionary, item: String) -> bool:
    return str(state.get("carry_item", "")) == item and int(state.get("carry_count", 0)) > 0


static func _any_station_busy(state: Dictionary) -> bool:
    for s in state.get("stations", []):
        if int(s.get("input_count", 0)) > 0 or int(s.get("output_count", 0)) > 0:
            return true
    return false


static func _any_counter_stocked(state: Dictionary) -> bool:
    for c in state.get("counters", []):
        if int(c.get("stock", 0)) > 0:
            return true
    return false


## 第一座收 item 當原料的工作站(不管滿不滿)
static func _station_with_input(state: Dictionary, item: String) -> Dictionary:
    for s in state.get("stations", []):
        if str(s.get("input", "")) == item:
            return s
    return {}


## 收 item 且原料堆還有空位、空位最多的工作站
static func _station_accepting(state: Dictionary, item: String) -> Dictionary:
    var best := {}
    var best_space := 0
    for s in state.get("stations", []):
        if str(s.get("input", "")) != item:
            continue
        var space := int(s.get("input_cap", 0)) - int(s.get("input_count", 0))
        if space > best_space:
            best = s
            best_space = space
    return best


## 成品最多的工作站(都是 0 就第一座)
static func _station_with_most_output(state: Dictionary) -> Dictionary:
    var best := {}
    var best_count := -1
    for s in state.get("stations", []):
        if int(s.get("output_count", 0)) > best_count:
            best = s
            best_count = int(s.get("output_count", 0))
    return best


## 第一個賣 item 的櫃台(不管滿不滿)
static func _counter_selling(state: Dictionary, item: String) -> Dictionary:
    for c in state.get("counters", []):
        if str(c.get("item", "")) == item:
            return c
    return {}


## 賣 item 且還有空位、庫存比例最低的櫃台
static func _counter_with_space(state: Dictionary, item: String) -> Dictionary:
    var best := {}
    var best_ratio := 2.0
    for c in state.get("counters", []):
        var cap := maxi(int(c.get("cap", 0)), 1)
        var stock := int(c.get("stock", 0))
        if str(c.get("item", "")) != item or stock >= cap:
            continue
        var ratio := float(stock) / float(cap)
        if ratio < best_ratio:
            best = c
            best_ratio = ratio
    return best


## 還看得見的指定牌子;沒有(買滿了)回空
static func _pad_by_id(state: Dictionary, id: String) -> Dictionary:
    for p in state.get("pads", []):
        if str(p.get("id", "")) == id and bool(p.get("visible", true)):
            return p
    return {}


## 看得見、剩餘價格最低的牌;budget >= 0 時只算付得起的
static func _cheapest_pad(state: Dictionary, budget: int) -> Dictionary:
    var best := {}
    var best_cost := 1 << 30
    for p in state.get("pads", []):
        if not bool(p.get("visible", true)):
            continue
        var cost := int(p.get("remaining", 0))
        if budget >= 0 and cost > budget:
            continue
        if cost < best_cost:
            best = p
            best_cost = cost
    return best
