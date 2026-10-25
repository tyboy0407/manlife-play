class_name Player
extends Carrier
## 玩家:輸入來自 MoveInput(鍵盤 / 手把;測試可指定 input_provider 餵合成輸入;之後加觸控搖桿)。
## 背包容量 = 設定值 + GameState 的擴充。

var input_provider: Callable = Callable()


func _ready() -> void:
    color = Color(0.35, 0.55, 0.95)
    super()
    add_to_group("player")
    speed = float(GameData.config().get("playerSpeed", 6.0))
    accel = float(GameData.config().get("playerAccel", 40.0))
    _refresh_capacity()
    GameState.changed.connect(_refresh_capacity)


func _refresh_capacity() -> void:
    stack.set_capacity(int(GameData.config().get("carryCapacity", 8)) + GameState.capacity_bonus)


func _physics_process(delta: float) -> void:
    var mi: MoveInput = input_provider.call() if input_provider.is_valid() else MoveInput.from_actions()
    move_toward_dir(mi.world_dir(), delta)
