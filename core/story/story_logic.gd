class_name StoryLogic
extends RefCounted
## 故事規則(純資料,可 headless 測試;資料在 data/story.json,文字鍵在 strings.csv):
## 吃進度字典 state,回「哪些章節 / 日誌該解鎖」「某個 NPC 現在該說哪幾句」「顧客現在該說哪組話」。
## state:{"tutorial_done", "bear_seen", "bear_beaten", "helpers_lost", "weapon_level", "king_kills", "orders_done", "map_pieces", "expansion",
##        "rare_caught", "landmarks": {rock / tree / pile: true}, "repairman_talked", "repaired_once", "shrine"}
## 條件名稱(data 的 when):always / tutorial_done / bear_seen(熊來過或買了武器)/ bear_met(被咬過或打跑過)/ bear_beaten / king_killed /
## order_done / orders_3 / rare_caught / map_1 / map_2 / map_3 / south_built(擴建四次)/ repaired_once / repairman_talked / landmark_<kind> / shrine。

var chapters: Array = []        # [{id, when, title, text}]
var journal: Array = []         # [{id, when, title, text}]
var lines := {}                 # npc -> [{when, keys}](由淺到深,取最後一個成立的)
var customer_lines := {}        # counter kind -> {early: [...], late: [...]};"ended": [...]
var customer_chance := 0.1
var shrine_cost := 3


static func from_data(d: Dictionary) -> StoryLogic:
    var s := StoryLogic.new()
    var src := d if d != null else {}
    for c in src.get("chapters", []):
        if typeof(c) == TYPE_DICTIONARY and c.has("id"):
            s.chapters.append(c)
    for j in src.get("journal", []):
        if typeof(j) == TYPE_DICTIONARY and j.has("id"):
            s.journal.append(j)
    var ln = src.get("lines", {})
    if typeof(ln) == TYPE_DICTIONARY:
        s.lines = ln
    var cl = src.get("customerLines", {})
    if typeof(cl) == TYPE_DICTIONARY:
        s.customer_lines = cl
    s.customer_chance = clampf(float(src.get("customerLineChance", 0.1)), 0.0, 1.0)
    var sh = src.get("shrine", {})
    if typeof(sh) == TYPE_DICTIONARY:
        s.shrine_cost = maxi(int(sh.get("cost", 3)), 1)
    return s


## 條件成立沒
static func check(cond: String, state: Dictionary) -> bool:
    match cond:
        "always":
            return true
        "tutorial_done":
            return bool(state.get("tutorial_done", false))
        "bear_seen":
            return bool(state.get("bear_seen", false)) or int(state.get("weapon_level", 0)) >= 1
        "bear_met":
            return bool(state.get("bear_beaten", false)) or int(state.get("helpers_lost", 0)) >= 1
        "bear_beaten":
            return bool(state.get("bear_beaten", false))
        "king_killed":
            return int(state.get("king_kills", 0)) >= 1
        "order_done":
            return int(state.get("orders_done", 0)) >= 1
        "orders_3":
            return int(state.get("orders_done", 0)) >= 3
        "rare_caught":
            return bool(state.get("rare_caught", false))
        "map_1":
            return int(state.get("map_pieces", 0)) >= 1
        "map_2":
            return int(state.get("map_pieces", 0)) >= 2
        "map_3":
            return int(state.get("map_pieces", 0)) >= 3
        "south_built":
            return int(state.get("expansion", 0)) >= 4
        "repaired_once":
            return bool(state.get("repaired_once", false))
        "repairman_talked":
            return bool(state.get("repairman_talked", false))
        "shrine":
            return bool(state.get("shrine", false))
    if cond.begins_with("landmark_"):
        var lm = state.get("landmarks", {})
        return typeof(lm) == TYPE_DICTIONARY and bool(lm.get(cond.trim_prefix("landmark_"), false))
    return false


## 現在該解鎖的章節 id(依資料順序)
func unlocked_chapters(state: Dictionary) -> Array[String]:
    var out: Array[String] = []
    for c in chapters:
        if check(str(c.get("when", "")), state):
            out.append(str(c["id"]))
    return out


## 現在該解鎖的日誌 id(依資料順序)
func unlocked_journal(state: Dictionary) -> Array[String]:
    var out: Array[String] = []
    for j in journal:
        if check(str(j.get("when", "")), state):
            out.append(str(j["id"]))
    return out


func chapter(id: String) -> Dictionary:
    for c in chapters:
        if str(c["id"]) == id:
            return c
    return {}


func journal_entry(id: String) -> Dictionary:
    for j in journal:
        if str(j["id"]) == id:
            return j
    return {}


## 這個 NPC 現在該說的那組台詞(資料由淺到深,取最後一個成立的);沒有回空
func npc_lines(npc: String, state: Dictionary) -> Array[String]:
    var out: Array[String] = []
    var entries = lines.get(npc, [])
    if typeof(entries) != TYPE_ARRAY:
        return out
    var best = null
    for e in entries:
        if typeof(e) == TYPE_DICTIONARY and check(str(e.get("when", "")), state):
            best = e
    if best == null:
        return out
    for k in best.get("keys", []):
        out.append(str(k))
    return out


## 故事到哪個階段:early(第四章前)/ late(第四章後)/ ended(神龕之後)
func stage(state: Dictionary) -> String:
    if check("shrine", state):
        return "ended"
    if check("south_built", state):
        return "late"
    return "early"


## 顧客買到東西時可能說的話:依櫃台種類(fillet_counter_2 -> fillet_counter)與階段;結局後全部櫃台同一組
func customer_lines_for(counter_id: String, state: Dictionary) -> Array[String]:
    var out: Array[String] = []
    var st := stage(state)
    var src = customer_lines.get("ended", []) if st == "ended" else customer_lines.get(counter_kind(counter_id), {})
    if st != "ended" and typeof(src) == TYPE_DICTIONARY:
        src = src.get(st, src.get("early", []))
    if typeof(src) == TYPE_ARRAY:
        for k in src:
            out.append(str(k))
    return out


func ended(state: Dictionary) -> bool:
    return check("shrine", state)


## fillet_counter_3 -> fillet_counter
static func counter_kind(counter_id: String) -> String:
    var parts := counter_id.split("_")
    if parts.size() >= 3 and parts[parts.size() - 1].is_valid_int():
        parts.remove_at(parts.size() - 1)
    return "_".join(parts)
