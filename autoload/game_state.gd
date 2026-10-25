extends Node
## 遊戲進行狀態(Autoload:GameState):購買 / 升級 / 僱用的結果與統計。里程碑 1 不存檔,之後再加。

signal changed

var capacity_bonus := 0        # 背包容量加成(擴充背包)
var unlocked := {}             # 購買 id 或解鎖目標 -> true
var hired := {}                # 幫手角色 -> 人數
var cash_earned := 0           # 累計賣出所得
var fish_caught := 0
var items_sold := 0


func _ready() -> void:
    EventBus.fish_caught.connect(func(_c: Node3D) -> void: fish_caught += 1)
    EventBus.sale_made.connect(func(_item: String, count: int, cash: int) -> void:
        items_sold += count
        cash_earned += cash)


func reset() -> void:
    capacity_bonus = 0
    unlocked = {}
    hired = {}
    cash_earned = 0
    fish_caught = 0
    items_sold = 0
    changed.emit()


## 價格牌付清後套用效果:capacity 擴充背包、hire 僱用幫手、unlock 解鎖目標(關卡聽 purchased 生東西)
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
    changed.emit()
    EventBus.purchased.emit(id, effect)


func is_unlocked(id: String) -> bool:
    return bool(unlocked.get(id, false))


func hired_count(role: String) -> int:
    return int(hired.get(role, 0))
