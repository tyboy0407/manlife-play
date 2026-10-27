class_name BearSpawner
extends Node3D
## 北極熊的出沒(掛在關卡下):村裡有幫手才倒數;第一隻在 firstDelaySec 後來,之後熊走掉就重新倒數
## intervalSec 之間的隨機秒數 × 武器等級的 cooldownMult。同時只會有一隻。存檔只記冷卻秒數(熊在場時存成短冷卻,讀回來很快再來)。
## enabled 可關(測試用);spawn(prefer) 可強制出現並指定先盯誰。

const RETURN_SOON_SEC := 8.0   # 存檔時熊在場:讀回來後幾秒再來

var level: Harbor = null
var logic: BearLogic
var enabled := true
var cooldown := -1.0   # < 0 = 還沒開始倒數(村裡沒幫手)
var bear: Bear = null
var visits := 0


func _ready() -> void:
    logic = BearLogic.from_config(GameData.section("bear"), GameData.section("weapon"))
    enabled = bool(GameData.section("bear").get("enabled", true))


func has_bear() -> bool:
    return bear != null and is_instance_valid(bear)


func _physics_process(delta: float) -> void:
    if has_bear():
        return
    bear = null
    if not enabled or level == null or level.helpers.is_empty():
        return
    if cooldown < 0.0:
        cooldown = logic.first_delay()
    cooldown -= delta
    if cooldown <= 0.0:
        spawn()


## 讓一隻熊從隨機的邊緣點進來;prefer 給了就先盯那個幫手
func spawn(prefer: Helper = null) -> Bear:
    if has_bear() or level == null:
        return bear
    var b := Bear.new()
    b.name = "Bear"
    b.level = level
    b.logic = logic
    var es := logic.entries()
    b.entry = es[randi() % es.size()] if not es.is_empty() else Vector3(-16, 0, -8)
    b.position = b.entry
    b.target = prefer
    b.left.connect(_on_left)
    add_child(b)
    bear = b
    visits += 1
    cooldown = 0.0
    EventBus.bear_appeared.emit(b)
    EventBus.notice.emit(tr("NOTICE_BEAR_APPEARED"))
    return b


func _on_left(reason: String) -> void:
    bear = null
    cooldown = logic.next_cooldown(GameState.weapon_level, randf())
    EventBus.bear_left.emit(reason)
    EventBus.notice.emit(tr("NOTICE_BEAR_FLED" if reason == "fled" else "NOTICE_BEAR_LEFT"))


## --- 存檔 ---

func snapshot() -> Dictionary:
    return {"cooldown": RETURN_SOON_SEC if has_bear() else cooldown}


func restore(d: Dictionary) -> void:
    cooldown = float(d.get("cooldown", -1.0))
