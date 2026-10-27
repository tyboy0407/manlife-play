class_name BearSpawner
extends Node3D
## 北極熊的出沒(掛在關卡下):村裡有幫手才倒數;第一群在 firstDelaySec 後來,之後整群都走掉才重新倒數
## interval(遊戲時間) 之間的隨機秒數(3 分鐘後越來越密)。一次來幾隻看 packChances(BearLogic.pack_size),各從入口點排開進來、
## 各盯不同的幫手。北極熊王:遊戲時間到 king.atSec 出現(與一般熊各自獨立),打死後 king.respawnSec 再來。
## 存檔記冷卻秒數(熊在場時存成短冷卻,讀回來很快再來)與王的下次時間。enabled 可關(測試用);
## spawn(prefer) 強制來一隻並指定先盯誰、spawn_pack(n) 強制來 n 隻、spawn_king() 強制王出現。

const RETURN_SOON_SEC := 8.0   # 存檔時熊在場:讀回來後幾秒再來

var level: Harbor = null
var logic: BearLogic
var enabled := true
var cooldown := -1.0   # < 0 = 還沒開始倒數(村裡沒幫手)
var bears: Array[Bear] = []   # 在場的熊(含王)
var king: Bear = null
var king_next_sec := -1.0      # 王下次出現的遊戲時間(-1 = 用 king.atSec)
var visits := 0        # 來過幾群
var spawned_total := 0
var kings_total := 0


func _ready() -> void:
    logic = BearLogic.from_config(GameData.section("bear"), GameData.section("weapon"))
    enabled = bool(GameData.section("bear").get("enabled", true))


func _prune() -> void:
    var alive: Array[Bear] = []
    for b in bears:
        if b != null and is_instance_valid(b):
            alive.append(b)
    bears = alive


func has_bear() -> bool:
    _prune()
    return not bears.is_empty()


func has_king() -> bool:
    return king != null and is_instance_valid(king)


## 一般熊(不含王)還在不在
func has_pack() -> bool:
    _prune()
    for b in bears:
        if not b.is_king:
            return true
    return false


func bear_count() -> int:
    _prune()
    return bears.size()


func first_bear() -> Bear:
    _prune()
    return bears[0] if not bears.is_empty() else null


## 離 pos 最近的熊(提示箭頭用)
func nearest_bear(pos: Vector3) -> Bear:
    _prune()
    var best: Bear = null
    var best_d := INF
    for b in bears:
        var d := b.planar_distance_to(pos)
        if d < best_d:
            best_d = d
            best = b
    return best


## 其他熊(排除 except)已經盯上的幫手 id -> true
func targeted_ids(except: Bear) -> Dictionary:
    var out := {}
    for b in bears:
        if b != except and b != null and is_instance_valid(b) and b.target != null and is_instance_valid(b.target):
            out[b.target.get_instance_id()] = true
    return out


func _physics_process(delta: float) -> void:
    if not enabled or level == null:
        return
    if king_next_sec < 0.0:
        king_next_sec = logic.king_at_sec()
    if not has_king() and GameState.play_time >= king_next_sec:
        spawn_king()
    if has_pack() or level.helpers.is_empty():
        return
    if cooldown < 0.0:
        cooldown = logic.first_delay()
    cooldown -= delta
    if cooldown <= 0.0:
        spawn_pack(logic.pack_size(randf()))


## 來一隻;prefer 給了就先盯那個幫手(已經有熊在場時是加入這一群)
func spawn(prefer: Helper = null) -> Bear:
    if level == null:
        return null
    var b := _spawn_one(prefer, 0, 1)
    _announce(1)
    return b


## 來 n 隻(同一個入口排開)
func spawn_pack(n: int) -> Array[Bear]:
    var out: Array[Bear] = []
    if level == null:
        return out
    n = maxi(n, 1)
    var entry := _pick_entry()
    for i in n:
        out.append(_spawn_one(null, i, n, entry))
    _announce(n)
    return out


func _pick_entry() -> Vector3:
    var es := logic.entries(level.is_expanded())
    return es[randi() % es.size()] if not es.is_empty() else Vector3(-16, 0, -8)


func _spawn_one(prefer: Helper, index: int, total: int, entry: Vector3 = Vector3(INF, 0, 0)) -> Bear:
    if entry.x == INF:
        entry = _pick_entry()
    var b := Bear.new()
    b.name = "Bear_%d" % (spawned_total + 1)
    b.level = level
    b.logic = logic
    b.entry = entry + Vector3(0, 0, (float(index) - float(total - 1) / 2.0) * 2.2)
    b.position = b.entry
    b.target = prefer
    b.left.connect(_on_left.bind(b))
    add_child(b)
    bears.append(b)
    spawned_total += 1
    cooldown = 0.0
    EventBus.bear_appeared.emit(b)
    return b


func _announce(n: int) -> void:
    visits += 1
    EventBus.notice.emit(tr("NOTICE_BEAR_APPEARED") if n <= 1 else tr("NOTICE_BEAR_PACK") % n)


## 北極熊王:從入口進來,吃魚和所有幫手
func spawn_king() -> Bear:
    if level == null or has_king():
        return king
    var b := Bear.new()
    b.name = "BearKing"
    b.is_king = true
    b.level = level
    b.logic = logic
    b.entry = _pick_entry()
    b.position = b.entry
    b.left.connect(_on_left.bind(b))
    add_child(b)
    bears.append(b)
    king = b
    kings_total += 1
    king_next_sec = INF   # 在場時不再生;打死後 _on_left 排下一次
    EventBus.bear_appeared.emit(b)
    EventBus.notice.emit(tr("NOTICE_BEAR_KING"))
    return b


func _on_left(reason: String, b: Bear) -> void:
    bears.erase(b)
    EventBus.bear_left.emit(reason)
    if b == king:
        king = null
        king_next_sec = GameState.play_time + logic.king_respawn_sec()
        EventBus.notice.emit(tr("NOTICE_BEAR_KING_DEAD"))
        return
    if has_pack():
        return
    cooldown = logic.next_cooldown(GameState.weapon_level, randf(), GameState.play_time)
    EventBus.notice.emit(tr("NOTICE_BEAR_FLED" if reason == "fled" else "NOTICE_BEAR_LEFT"))


## --- 存檔 ---

func snapshot() -> Dictionary:
    var king_at := king_next_sec
    if has_king():
        king_at = GameState.play_time + RETURN_SOON_SEC
    return {"cooldown": RETURN_SOON_SEC if has_pack() else cooldown, "kingNextSec": king_at}


func restore(d: Dictionary) -> void:
    cooldown = float(d.get("cooldown", -1.0))
    king_next_sec = float(d.get("kingNextSec", -1.0))
