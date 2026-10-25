class_name Helper
extends Carrier
## 僱用的幫手。目前只有漁夫(role fisher):到淺水區漫游讓 FishArea 幫它抓魚,背包滿了走到切魚台輸入格卸貨,再回水裡。
## 不取成品、不收錢。

var role := "fisher"
var fish_area: FishArea = null
var station: Station = null
var state := "to_water"
var target := Vector3.ZERO
var deposited_total := 0

var _wander_timer := 0.0
var _last_count := 0


func _ready() -> void:
    color = Color(0.5, 0.38, 0.6)
    super()
    add_to_group("helper")
    takes_output = false
    collects_cash = false
    speed = float(GameData.config().get("helperSpeed", 4.5))
    stack.set_capacity(int(GameData.config().get("helperCapacity", 6)))
    stack.changed.connect(_track_deposit)
    _last_count = stack.count


func _track_deposit() -> void:
    if state == "depositing" and stack.count < _last_count:
        deposited_total += _last_count - stack.count
    _last_count = stack.count


func _physics_process(delta: float) -> void:
    match state:
        "to_water":
            if fish_area == null:
                move_toward_dir(Vector3.ZERO, delta)
                return
            target = fish_area.random_point()
            _wander_timer = randf_range(1.5, 3.0)
            state = "fishing"
        "fishing":
            if stack.is_full() or (fish_area == null):
                if station != null:
                    target = station.input_pad.global_position
                    state = "to_station"
                return
            _wander_timer -= delta
            if _wander_timer <= 0.0 or planar_distance_to(target) < 0.5:
                target = fish_area.random_point()
                _wander_timer = randf_range(1.5, 3.0)
            go_to(target, delta, 0.3)
        "to_station":
            if go_to(target, delta, 0.3):
                state = "depositing"
        "depositing":
            move_toward_dir(Vector3.ZERO, delta)
            if stack.is_empty():
                state = "to_water"
        _:
            state = "to_water"
