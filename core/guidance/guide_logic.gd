class_name GuideLogic
extends RefCounted
## 引導規則(純資料,可 headless 測試):新存檔的教學步驟 + 之後「當下最該做的事」的提示。
## 世界狀態用字典餵進來:
## {"carry_item", "carry_count", "wallet", "money_on_pad", "fish_caught", "items_sold", "purchases", "hired": {role: n},
##  "counters": [{"id", "item", "stock", "cap", "has_server", "has_cashier"}],
##  "stations": [{"id", "input", "input_count", "input_cap", "input_per"(一批吃幾個), "output", "output_count", "blocked"(成品堆滿停工)}],
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
            var need := int(p.get("remaining", 0)) - int(state.get("wallet", 0))
            if p.is_empty() or need <= 0:
                return {"kind": "pad", "target": str(p.get("id", "")), "text": text, "arg": str(p.get("name", ""))}
            # 錢不夠:箭頭回到工作循環,文字說還差多少
            var w := _work_hint(state, false)
            w["text"] = "TUT_earn"
            w["args"] = [need, str(p.get("name", ""))]
            return w
    return {}


## 教學之後的提示:當下最該做的事。北極熊在村裡最優先(沒武器指武器店的牌、有武器指熊);
## 手上有貨先處理貨;空手依序:買得起的牌 > 櫃台有貨沒人收銀 > 錢格有錢 > 工作站有成品(沒搬運工才提醒)> 毛皮夠做毛衣就去服飾店 > 去抓魚(有工作站收魚)> 沒事
static func hint(state: Dictionary) -> Dictionary:
    if bool(state.get("bear", false)):
        if int(state.get("weapon_level", 0)) <= 0:
            var wp := _pad_by_id(state, WEAPON_PAD)
            if not wp.is_empty():
                var need := int(wp.get("remaining", 0)) - int(state.get("wallet", 0))
                if need <= 0:
                    return {"kind": "pad", "target": WEAPON_PAD, "text": "HINT_BEAR_WEAPON"}
                if int(state.get("money_on_pad", 0)) >= 1:
                    return {"kind": "money", "target": "", "text": "HINT_BEAR_MONEY"}
                # 錢不夠買武器:先照工作循環賺錢(不指牌子),文字說還差多少
                var w := _work_hint(state, false)
                w["text"] = "HINT_BEAR_EARN"
                w["args"] = [need]
                return w
        return {"kind": "bear", "target": "", "text": "HINT_BEAR_CHASE"}
    return _work_hint(state, true)


## 工作循環的提示(沒有熊的時候的全部規則);allow_pads = false 時不提買牌子(教學 / 熊來了錢不夠時用)
static func _work_hint(state: Dictionary, allow_pads: bool) -> Dictionary:
    var item := str(state.get("carry_item", ""))
    var count := int(state.get("carry_count", 0))
    if count > 0 and item != "":
        var ct := _counter_with_space(state, item)
        if not ct.is_empty():
            # 櫃台放不下整疊、又沒人收銀:先站收銀格賣到放得下再上架。不然每賣一件提示就在上架格 / 收銀格之間翻一次,
            # 玩家在兩格之間來回跑(試玩機器人的「卡住」其實是這個)
            var free := maxi(int(ct.get("cap", 0)) - int(ct.get("stock", 0)), 0)
            if free < count and int(ct.get("stock", 0)) > 0 and not bool(ct.get("has_server", false)) and not bool(ct.get("has_cashier", false)):
                return {"kind": "service", "target": str(ct["id"]), "text": "HINT_counter_full_serve"}
            return {"kind": "counter_deposit", "target": str(ct["id"]), "text": "HINT_to_counter"}
        var st := _station_accepting(state, item)
        if not st.is_empty():
            return {"kind": "station_input", "target": str(st["id"]), "text": "HINT_to_station" if item == "fish" else "HINT_to_next_station"}
        var any_ct := _counter_selling(state, item)
        if not any_ct.is_empty():
            # 櫃台滿了:沒人收銀就自己去收銀格賣,有人收銀才是等顧客
            if not bool(any_ct.get("has_server", false)) and not bool(any_ct.get("has_cashier", false)):
                return {"kind": "service", "target": str(any_ct["id"]), "text": "HINT_counter_full_serve"}
            return {"kind": "counter_deposit", "target": str(any_ct["id"]), "text": "HINT_counter_full"}
        var any_st := _station_with_input(state, item)
        if not any_st.is_empty():
            # 工作站塞住(成品堆滿、停工):背著原料站在輸入格永遠放不進去,先丟掉再去拿成品
            if bool(any_st.get("blocked", false)):
                return {"kind": "trash", "target": "", "text": "HINT_station_jammed"}
            return {"kind": "station_input", "target": str(any_st["id"]), "text": "HINT_station_full"}
        return {"kind": "trash", "target": "", "text": "HINT_trash"}
    # 錢格的錢加上錢包就買得起牌子了、錢包自己還不夠:先去收錢。放在塞住 / 買牌之前,因為工作站塞住時玩家一直滿手來回搬成品,
    # 錢格堆到幾百塊也沒人叫他去收(試玩紀錄:錢包 $0、錢格 $464),熊來了就買不起武器
    var on_pad := int(state.get("money_on_pad", 0))
    var wallet := int(state.get("wallet", 0))
    if allow_pads and on_pad >= 1 and _cheapest_pad(state, wallet).is_empty() and not _cheapest_pad(state, wallet + on_pad).is_empty():
        return {"kind": "money", "target": "", "text": "HINT_money"}
    # 幫手被吃過、而且現在的武器打不過熊(BearLogic.outmatched):先存錢升級武器,不提重僱便宜的幫手送死
    # (試玩紀錄:一直重僱 $18 的漁夫,永遠存不到 $60 的武器 Lv2,20 分鐘幫手全被吃光)
    if allow_pads and bool(state.get("outmatched", false)) and int(state.get("helpers_lost", 0)) > 0:
        var wp := _pad_by_id(state, WEAPON_PAD)
        if not wp.is_empty():
            var need := int(wp.get("remaining", 0)) - wallet
            if need <= 0:
                return {"kind": "pad", "target": WEAPON_PAD, "text": "HINT_buy", "arg": str(wp.get("name", ""))}
            if on_pad >= 1:
                return {"kind": "money", "target": "", "text": "HINT_money"}
            var w := _work_hint(state, false)
            w["text"] = "HINT_SAVE_WEAPON"
            w["args"] = [need]
            return w
    var jam := _station_jammed(state)
    if not jam.is_empty():
        return {"kind": "station_output", "target": str(jam["id"]), "text": "HINT_take_jammed"}
    var pad := _cheapest_pad(state, wallet) if allow_pads else {}
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
    # 毛皮夠做一件毛衣、服飾店還放得下:提醒拿去服飾店(毛皮不佔背包,玩家容易忘了它能賣錢)
    var tailor := _station_accepting(state, "pelt")
    if not tailor.is_empty() and typeof(state.get("resources", null)) == TYPE_DICTIONARY \
            and int(state["resources"].get("pelt", 0)) >= int(tailor.get("input_per", 5)):
        return {"kind": "station_input", "target": str(tailor["id"]), "text": "HINT_pelts"}
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


## 成品堆滿而停工(blocked)且堆裡有成品的工作站(空手時最該先去拿)
static func _station_jammed(state: Dictionary) -> Dictionary:
    for s in state.get("stations", []):
        if bool(s.get("blocked", false)) and int(s.get("output_count", 0)) > 0:
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
## 最便宜且買得起的牌(budget = 錢包;-1 = 不管錢,只看現金牌)。收毛皮 / 熊王牙的牌:資源夠就當最優先(cost 0),不夠就跳過
static func _cheapest_pad(state: Dictionary, budget: int) -> Dictionary:
    var best := {}
    var best_cost := 1 << 30
    var res = state.get("resources", {})
    for p in state.get("pads", []):
        if not bool(p.get("visible", true)):
            continue
        var cost := int(p.get("remaining", 0))
        var currency := str(p.get("currency", "cash"))
        if currency != "cash":
            if budget < 0 or typeof(res) != TYPE_DICTIONARY or int(res.get(currency, 0)) < cost:
                continue
            cost = 0
        elif budget >= 0 and cost > budget:
            continue
        if cost < best_cost:
            best = p
            best_cost = cost
    return best
