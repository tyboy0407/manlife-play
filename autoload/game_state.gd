extends Node
## 遊戲進行狀態(Autoload:GameState):錢包、購買 / 升級 / 僱用的結果與統計;to_dict / from_dict 給存檔用。
## 效果型別:capacity 擴充背包、hire 僱用幫手(角色計數)、unlock 解鎖目標(關卡聽 purchased 生東西)、upgrade 升級等級、
## weapon 武器等級(北極熊)。幫手被北極熊吃掉:lose_helper 角色計數 -1(牌子的購買次數不退,價格維持)。
## 錢包:錢格收進來、價格牌扣出去,不佔背包;改錢包不發 changed(HUD 每幀自己讀)。

signal changed

var wallet := 0                # 錢包(現金不佔背包)
var tutorial_step := 0         # 教學進度(= GuideLogic.tutorial_steps() 表示做完)
var hints_on := true           # 教學後的提示箭頭(H 鍵 / 選單開關)
var sound_on := true           # 音效(選單開關)
var capacity_bonus := 0        # 背包容量加成
var unlocked := {}             # 購買 id 或解鎖目標 -> true
var hired := {}                # 幫手角色 -> 人數
var upgrades := {}             # 升級鍵(worker_speed / pile_cap)-> 等級
var weapon_level := 0          # 武器等級(0 = 沒有;北極熊只怕有武器的玩家)
var helpers_lost := 0          # 被北極熊吃掉的幫手數
var pelts := 0                 # 北極熊毛皮(打跑熊掉的,武器店升級用)
var teeth := 0                 # 熊王牙(打死王掉的,強化守衛塔用)
var shop_level := 0            # 武器店等級(0 ~ 3,每級多賣一級武器)
var play_time := 0.0           # 遊戲時間(秒,關卡每幀累加;北極熊的難度曲線與王的出場看它)
var cash_earned := 0
var fish_caught := 0
var items_sold := 0
var items_trashed := 0


func _ready() -> void:
    EventBus.fish_caught.connect(func(_c: Node3D) -> void: fish_caught += 1)
    EventBus.sale_made.connect(func(_item: String, count: int, cash: int) -> void:
        items_sold += count
        cash_earned += cash)


func reset() -> void:
    wallet = 0
    tutorial_step = 0
    hints_on = true
    sound_on = true
    capacity_bonus = 0
    unlocked = {}
    hired = {}
    upgrades = {}
    weapon_level = 0
    helpers_lost = 0
    pelts = 0
    teeth = 0
    shop_level = 0
    play_time = 0.0
    cash_earned = 0
    fish_caught = 0
    items_sold = 0
    items_trashed = 0
    changed.emit()


func apply_purchase(id: String, effect: Dictionary) -> void:
    unlocked[id] = true
    match str(effect.get("type", "")):
        "capacity":
            capacity_bonus += int(effect.get("add", 0))
        "hire":
            var role := str(effect.get("role", "fisher"))
            hired[role] = int(hired.get(role, 0)) + 1
        "unlock":
            unlocked[str(effect.get("target", id))] = true
        "upgrade":
            var key := str(effect.get("key", ""))
            if key != "":
                upgrades[key] = upgrade_level(key) + 1
        "weapon":
            weapon_level += 1
        "shop_upgrade":
            shop_level += 1
    changed.emit()
    EventBus.purchased.emit(id, effect)


## 幫手被吃掉:該角色人數 -1(不會低於 0),統計 +1
func lose_helper(role: String) -> void:
    hired[role] = maxi(int(hired.get(role, 0)) - 1, 0)
    helpers_lost += 1
    changed.emit()


## --- 掉落物資源(毛皮 / 熊王牙,不佔背包)---

## 不佔背包的資源種類(工作站輸入格收這種原料時從這裡扣,而不是從背包)
func is_resource(kind: String) -> bool:
    return kind == "pelt" or kind == "tooth"


func resource(kind: String) -> int:
    match kind:
        "pelt":
            return pelts
        "tooth":
            return teeth
        "cash":
            return wallet
    return 0


## 資源 +n,回傳現有數量
func add_resource(kind: String, n: int) -> int:
    match kind:
        "pelt":
            pelts = maxi(pelts + n, 0)
        "tooth":
            teeth = maxi(teeth + n, 0)
        "cash":
            add_wallet(n)
    changed.emit()
    return resource(kind)


## 扣 n 個(不夠就扣到 0),回傳實際扣掉幾個
func spend_resource(kind: String, n: int) -> int:
    var have := resource(kind)
    var used := clampi(n, 0, have)
    match kind:
        "pelt":
            pelts -= used
        "tooth":
            teeth -= used
        "cash":
            spend(used)
            return used
    changed.emit()
    return used


func is_unlocked(id: String) -> bool:
    return bool(unlocked.get(id, false))


func hired_count(role: String) -> int:
    return int(hired.get(role, 0))


func hired_total() -> int:
    var n := 0
    for role in hired:
        n += int(hired[role])
    return n


func upgrade_level(key: String) -> int:
    return int(upgrades.get(key, 0))


## 升級倍率 = 1 + 每級加成(game.json upgrades.<key>.perLevel)× 等級
func upgrade_mult(key: String) -> float:
    var spec = GameData.section("upgrades").get(key, {})
    var per := float(spec.get("perLevel", 0.5)) if typeof(spec) == TYPE_DICTIONARY else 0.5
    return 1.0 + per * float(upgrade_level(key))


func add_trashed(n: int) -> void:
    if n > 0:
        items_trashed += n


func add_wallet(n: int) -> void:
    if n > 0:
        wallet += n


## 從錢包扣 n(最多扣到 0),回傳實際扣掉的
func spend(n: int) -> int:
    var paid := clampi(n, 0, wallet)
    wallet -= paid
    return paid


## --- 存檔 ---

func to_dict() -> Dictionary:
    return {
        "wallet": wallet, "tutorial_step": tutorial_step, "hints_on": hints_on, "sound_on": sound_on,
        "capacity_bonus": capacity_bonus, "unlocked": unlocked.duplicate(), "hired": hired.duplicate(),
        "upgrades": upgrades.duplicate(), "weapon_level": weapon_level, "helpers_lost": helpers_lost, "play_time": play_time,
        "pelts": pelts, "teeth": teeth, "shop_level": shop_level,
        "cash_earned": cash_earned, "fish_caught": fish_caught, "items_sold": items_sold, "items_trashed": items_trashed,
    }


## 不發 purchased(關卡自己依 unlocked / hired 重建),只在最後發一次 changed
func from_dict(d: Dictionary) -> void:
    wallet = maxi(int(d.get("wallet", 0)), 0)
    capacity_bonus = int(d.get("capacity_bonus", 0))
    unlocked = {}
    var u = d.get("unlocked", {})
    if typeof(u) == TYPE_DICTIONARY:
        for k in u:
            unlocked[str(k)] = bool(u[k])
    hired = {}
    var h = d.get("hired", {})
    if typeof(h) == TYPE_DICTIONARY:
        for k in h:
            hired[str(k)] = maxi(int(h[k]), 0)
    upgrades = {}
    var g = d.get("upgrades", {})
    if typeof(g) == TYPE_DICTIONARY:
        for k in g:
            upgrades[str(k)] = maxi(int(g[k]), 0)
    # 舊存檔沒有教學欄位:已經買過東西就當教學做完
    tutorial_step = clampi(int(d.get("tutorial_step", GuideLogic.tutorial_steps() if not unlocked.is_empty() else 0)), 0, GuideLogic.tutorial_steps())
    hints_on = bool(d.get("hints_on", true))
    sound_on = bool(d.get("sound_on", true))
    cash_earned = int(d.get("cash_earned", 0))
    fish_caught = int(d.get("fish_caught", 0))
    items_sold = int(d.get("items_sold", 0))
    items_trashed = int(d.get("items_trashed", 0))
    weapon_level = maxi(int(d.get("weapon_level", 0)), 0)
    helpers_lost = maxi(int(d.get("helpers_lost", 0)), 0)
    play_time = maxf(float(d.get("play_time", 0.0)), 0.0)
    pelts = maxi(int(d.get("pelts", 0)), 0)
    teeth = maxi(int(d.get("teeth", 0)), 0)
    shop_level = maxi(int(d.get("shop_level", 0)), 0)
    changed.emit()
