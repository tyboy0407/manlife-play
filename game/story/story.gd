class_name Story
extends Node3D
## 故事(掛在關卡下):每 0.5 秒把進度餵 StoryLogic,解鎖章節(HUD 彈短文)與日誌(通知),記在 GameState.story(存檔);
## NPC 泡泡:玩家站到武器店老闆 / 船長 / 旅行商人 / 修理工旁 1 秒,頭上冒一句當前階段的台詞(輪流),走開或 3.5 秒後收起;
## 雪原地標(Harbor.LANDMARKS)走到 2.5 格內算到過(岩石 / 枯樹 / 雪堆各一條日誌);
## 顧客台詞由 Counter / Customer 來問(customer_line);結局(神龕付清)後 ended() 讓顧客不再道謝、面向北方。
## 讀檔時第一次 refresh 不彈面板(舊進度的章節 / 日誌直接補進去,日誌頁看得到)。

const NEAR := 2.2
const TALK_DELAY := 1.0
const BUBBLE_SEC := 3.5
const LANDMARK_RADIUS := 2.5
const REFRESH_SEC := 0.5

var level: Harbor = null
var logic: StoryLogic = null
var silent_first := false      # 讀檔後第一次 refresh 不彈面板 / 通知

var _timer := 0.0
var _first := true
var _npc := {}                 # id -> {"near": 秒, "shown": 秒, "idx": int, "bubble": Label3D}
var _cust_idx := {}            # 櫃台種類 -> 輪到第幾句


func _ready() -> void:
    add_to_group("story")
    if logic == null:
        logic = StoryLogic.from_data(GameData.story())
    EventBus.bear_appeared.connect(func(_b: Node3D) -> void: GameState.set_story_flag("bear_seen"))
    EventBus.bear_defeated.connect(func(_b: Node3D, _by: Node3D) -> void: GameState.set_story_flag("bear_beaten"))
    EventBus.rare_fish_caught.connect(func(_t: int) -> void: GameState.set_story_flag("rare_caught"))
    EventBus.building_repaired.connect(func(_b: Node3D, _by: Node3D) -> void: GameState.set_story_flag("repaired_once"))
    for id in ["shopkeeper", "captain", "merchant", "repairman"]:
        _npc[id] = {"near": 0.0, "shown": 0.0, "idx": 0, "bubble": null}


## 進度字典(StoryLogic 吃的)
func state() -> Dictionary:
    return {
        "tutorial_done": GameState.tutorial_step >= GuideLogic.tutorial_steps(),
        "bear_seen": GameState.story_flag("bear_seen"), "bear_beaten": GameState.story_flag("bear_beaten"),
        "helpers_lost": GameState.helpers_lost, "weapon_level": GameState.weapon_level, "king_kills": GameState.king_kills,
        "orders_done": GameState.orders_done, "map_pieces": GameState.map_pieces,
        "expansion": level.expansion_level() if level != null else 0,
        "rare_caught": GameState.story_flag("rare_caught"), "landmarks": GameState.story_landmarks(),
        "repairman_talked": GameState.story_flag("repairman_talked"), "repaired_once": GameState.story_flag("repaired_once"),
        "shrine": GameState.is_unlocked("shrine"),
    }


func ended() -> bool:
    return GameState.is_unlocked("shrine")


func _physics_process(delta: float) -> void:
    if level == null or level.player == null or not is_instance_valid(level.player):
        return
    _timer -= delta
    if _timer <= 0.0:
        _timer = REFRESH_SEC
        _check_landmarks()
        refresh()
    _tick_npcs(delta)


## 解鎖新章節 / 日誌
func refresh() -> void:
    var quiet := _first and silent_first
    _first = false
    var st := state()
    for id in logic.unlocked_chapters(st):
        if GameState.story_add("chapters", id):
            var c := logic.chapter(id)
            EventBus.chapter_started.emit(id)
            if not quiet and level.hud != null:
                level.hud.show_chapter(tr(str(c.get("title", ""))), tr(str(c.get("text", ""))))
    for id in logic.unlocked_journal(st):
        if GameState.story_add("journal", id):
            var j := logic.journal_entry(id)
            EventBus.journal_unlocked.emit(id)
            if not quiet:
                EventBus.notice.emit(tr("NOTICE_JOURNAL") % tr(str(j.get("title", ""))))


func _check_landmarks() -> void:
    var p: Vector3 = level.player.global_position
    for lm in Harbor.LANDMARKS:
        var kind := str(lm[0])
        if GameState.story_landmarks().has(kind):
            continue
        var pos: Vector3 = lm[1]
        if Vector2(pos.x - p.x, pos.z - p.z).length() <= LANDMARK_RADIUS:
            GameState.story_add("landmarks", kind)


## --- NPC 泡泡 ---

func _npc_node(id: String) -> Node3D:
    match id:
        "shopkeeper":
            return level.shopkeeper
        "captain":
            return level.captain
        "merchant":
            return level.merchant
        "repairman":
            for h in level.helpers:
                if h != null and is_instance_valid(h) and h.role == "repairman" and not h.eaten:
                    return h
    return null


func _tick_npcs(delta: float) -> void:
    var p: Vector3 = level.player.global_position
    for id in _npc:
        var n: Node3D = _npc_node(id)
        var rec: Dictionary = _npc[id]
        if n == null or not is_instance_valid(n):
            rec["near"] = 0.0
            continue
        var d := Vector2(n.global_position.x - p.x, n.global_position.z - p.z).length()
        if d <= NEAR:
            rec["near"] = float(rec["near"]) + delta
            if float(rec["near"]) >= TALK_DELAY and float(rec["shown"]) <= 0.0:
                _say(id, n)
        else:
            rec["near"] = 0.0
        if float(rec["shown"]) > 0.0:
            rec["shown"] = float(rec["shown"]) - delta
            if float(rec["shown"]) <= 0.0 or d > NEAR * 1.5:
                rec["shown"] = 0.0
                _hide(rec)


func _say(id: String, n: Node3D) -> void:
    var keys := logic.npc_lines(id, state())
    if keys.is_empty():
        return
    var rec: Dictionary = _npc[id]
    var idx := int(rec["idx"]) % keys.size()
    rec["idx"] = idx + 1
    var text := tr(keys[idx])
    var bubble: Label3D = rec["bubble"]
    if bubble == null or not is_instance_valid(bubble) or bubble.get_parent() != n:
        if bubble != null and is_instance_valid(bubble):
            bubble.queue_free()
        bubble = VisualFactory.label(text, Vector3(0, 2.35, 0), 38, Color(1.0, 0.95, 0.85))
        n.add_child(bubble)
        rec["bubble"] = bubble
    bubble.text = text
    bubble.visible = true
    rec["shown"] = BUBBLE_SEC
    EventBus.npc_spoke.emit(id, keys[idx])
    if id == "repairman" and StoryLogic.check("south_built", state()):
        GameState.set_story_flag("repairman_talked")   # 第四章的線索:跟修理工談過那張紙
        refresh()


func _hide(rec: Dictionary) -> void:
    var bubble: Label3D = rec["bubble"]
    if bubble != null and is_instance_valid(bubble):
        bubble.visible = false


## 某個 NPC 現在正顯示的台詞(測試用);沒有回空字串
func npc_bubble_text(id: String) -> String:
    var rec: Dictionary = _npc.get(id, {})
    var bubble = rec.get("bubble", null)
    if bubble != null and is_instance_valid(bubble) and bubble.visible:
        return bubble.text
    return ""


## --- 顧客 ---

## 顧客買到東西時要說的話("" = 照常道謝);結局後一定說(省略號 / 她在看),之前 customerLineChance 的機率說聚落的閒話
func customer_line(counter_id: String, roll: float = -1.0) -> String:
    var st := state()
    var keys := logic.customer_lines_for(counter_id, st)
    if keys.is_empty():
        return ""
    var r := randf() if roll < 0.0 else roll
    if not logic.ended(st) and r >= logic.customer_chance:
        return ""
    var kind := StoryLogic.counter_kind(counter_id) if not logic.ended(st) else "ended"
    var idx := int(_cust_idx.get(kind, 0)) % keys.size()
    _cust_idx[kind] = idx + 1
    return tr(keys[idx])


## --- 日誌頁 ---

## 章節清單 [{title, text, unlocked}](依順序,沒解鎖的只有 ???)
func chapter_entries() -> Array:
    var out := []
    for c in logic.chapters:
        var got := GameState.story_has("chapters", str(c["id"]))
        out.append({"title": tr(str(c.get("title", ""))) if got else tr("JOURNAL_LOCKED"), "text": tr(str(c.get("text", ""))) if got else "", "unlocked": got})
    return out


## 日誌清單 [{title, text, unlocked}]
func journal_entries() -> Array:
    var out := []
    for j in logic.journal:
        var got := GameState.story_has("journal", str(j["id"]))
        out.append({"title": tr(str(j.get("title", ""))) if got else tr("JOURNAL_LOCKED"), "text": tr(str(j.get("text", ""))) if got else "", "unlocked": got})
    return out


func unlocked_count() -> int:
    return GameState.story_list("journal").size()
