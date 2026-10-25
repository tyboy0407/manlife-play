class_name Helper
extends Carrier
## 僱用的幫手,依 role 走不同狀態機:
## fisher 漁夫:到淺水區漫游讓 FishArea 幫它抓魚,滿了找「收魚的工作站」卸貨,沒地方放就換一台或等;
## porter 搬運工:找「有成品的工作站」,把成品搬到需要它的櫃台或工作站(偏向最空的目的地);
## cashier 收銀員:走到被指派櫃台的收銀格站著(櫃台要有人站著才賣得出去)。
## 數值在 game.json helpers.<role>;不收錢、不用垃圾桶。

const ROLE_COLORS := {"fisher": Color(0.5, 0.38, 0.6), "porter": Color(0.85, 0.55, 0.25), "cashier": Color(0.3, 0.6, 0.5)}

var role := "fisher"
var level: Harbor = null
var fish_area: FishArea = null
var assigned_counter: Counter = null
var state := "idle"
var target := Vector3.ZERO
var deposited_total := 0    # 漁夫卸進工作站的魚
var delivered_total := 0    # 搬運工送達的件數
var job := {}               # porter:{"from": Station, "to": Node3D, "item": String}

var _dest: Node3D = null
var _wander_timer := 0.0
var _idle_timer := 0.0
var _wait_timer := 0.0
var _last_count := 0


func _ready() -> void:
    color = ROLE_COLORS.get(role, Color(0.5, 0.5, 0.5))
    super()
    add_to_group("helper")
    add_to_group("helper_%s" % role)
    var cfg := GameData.helper(role)
    speed = float(cfg.get("speed", 4.5))
    stack.set_capacity(int(cfg.get("capacity", 6)))
    can_fish = role == "fisher"
    takes_output = role == "porter"
    collects_cash = false
    can_serve = role == "cashier"
    can_use_trash = false
    stack.changed.connect(_track_transfer)
    _last_count = stack.count
    # 頭上的角色標記
    add_child(VisualFactory.box(Vector3(0.5, 0.18, 0.5), color.darkened(0.35), Vector3(0, 1.72, 0)))


## 堆疊變少 = 卸貨(格子在走近時就開始搬,所以「走向目的地」狀態也算)
func _track_transfer() -> void:
    if stack.count < _last_count:
        var n := _last_count - stack.count
        if role == "fisher" and (state == "to_station" or state == "depositing"):
            deposited_total += n
        elif role == "porter" and (state == "to_dropoff" or state == "dropping"):
            delivered_total += n
    _last_count = stack.count


func _physics_process(delta: float) -> void:
    match role:
        "fisher":
            _fisher(delta)
        "porter":
            _porter(delta)
        "cashier":
            _cashier(delta)
        _:
            move_toward_dir(Vector3.ZERO, delta)


## --- 漁夫 ---

func _fisher(delta: float) -> void:
    match state:
        "fishing":
            if stack.is_full():
                var st := _station_for_fish()
                if st != null:
                    _dest = st
                    target = st.input_pad.global_position
                    state = "to_station"
                else:
                    move_toward_dir(Vector3.ZERO, delta)
                return
            _wander_timer -= delta
            if _wander_timer <= 0.0 or planar_distance_to(target) < 0.5:
                target = fish_area.random_point()
                _wander_timer = randf_range(1.5, 3.0)
            go_to(target, delta, 0.3)
        "to_station":
            if _dest == null or not is_instance_valid(_dest):
                state = "idle"
                return
            if go_to(target, delta, 0.3):
                state = "depositing"
                _wait_timer = 2.0
        "depositing":
            move_toward_dir(Vector3.ZERO, delta)
            if stack.is_empty():
                state = "idle"
                return
            _wait_timer -= delta
            if _wait_timer <= 0.0:
                var alt := level.find_station_accepting("fish") if level != null else null
                if alt != null and alt != _dest:
                    _dest = alt
                    target = alt.input_pad.global_position
                    state = "to_station"
                else:
                    _wait_timer = 1.0
        _:
            if fish_area == null:
                move_toward_dir(Vector3.ZERO, delta)
                return
            target = fish_area.random_point()
            _wander_timer = randf_range(1.5, 3.0)
            state = "fishing"


func _station_for_fish() -> Station:
    if level == null:
        return null
    var st := level.find_station_accepting("fish")
    if st == null:
        st = level.find_station_with_input("fish")
    return st


## --- 搬運工 ---

func _porter(delta: float) -> void:
    match state:
        "to_pickup":
            if not _job_valid():
                state = "idle"
                return
            if go_to(target, delta, 0.3):
                state = "picking"
                _wait_timer = 2.5
        "picking":
            move_toward_dir(Vector3.ZERO, delta)
            _wait_timer -= delta
            var from: Station = job.get("from", null)
            var source_empty := from == null or not is_instance_valid(from) or from.logic.output_count <= 0
            if stack.is_full() or (source_empty and not stack.is_empty()) or (_wait_timer <= 0.0 and not stack.is_empty()):
                _dest = job.get("to", null)
                if _dest == null or not is_instance_valid(_dest):
                    _dest = level.find_dest_for(stack.item_id, null) if level != null else null
                if _dest == null:
                    state = "idle"
                    return
                target = _dest_pad_pos(_dest)
                state = "to_dropoff"
            elif _wait_timer <= 0.0 and stack.is_empty():
                state = "idle"
        "to_dropoff":
            if _dest == null or not is_instance_valid(_dest):
                state = "idle"
                return
            if go_to(target, delta, 0.3):
                state = "dropping"
                _wait_timer = 3.0
        "dropping":
            move_toward_dir(Vector3.ZERO, delta)
            if stack.is_empty():
                job = {}
                state = "idle"
                return
            _wait_timer -= delta
            if _wait_timer <= 0.0:
                var alt := level.find_dest_for(stack.item_id, _dest) if level != null else null
                if alt != null:
                    _dest = alt
                    target = _dest_pad_pos(alt)
                    state = "to_dropoff"
                else:
                    _wait_timer = 1.5
        _:
            move_toward_dir(Vector3.ZERO, delta)
            _idle_timer -= delta
            if _idle_timer > 0.0:
                return
            _idle_timer = 0.5
            if level == null:
                return
            if not stack.is_empty():
                var d := level.find_dest_for(stack.item_id, null)
                if d != null:
                    _dest = d
                    target = _dest_pad_pos(d)
                    state = "to_dropoff"
                return
            job = level.find_porter_job()
            if not job.is_empty():
                target = (job["from"] as Station).output_pad.global_position
                state = "to_pickup"


func _job_valid() -> bool:
    if job.is_empty():
        return false
    var from = job.get("from", null)
    var to = job.get("to", null)
    return from != null and is_instance_valid(from) and to != null and is_instance_valid(to)


func _dest_pad_pos(dest: Node3D) -> Vector3:
    if dest is Counter:
        return (dest as Counter).deposit_pad.global_position
    if dest is Station:
        return (dest as Station).input_pad.global_position
    return dest.global_position


## --- 收銀員 ---

func _cashier(delta: float) -> void:
    if assigned_counter == null or not is_instance_valid(assigned_counter):
        move_toward_dir(Vector3.ZERO, delta)
        state = "idle"
        return
    match state:
        "serving":
            move_toward_dir(Vector3.ZERO, delta)
            if planar_distance_to(target) > 0.6:
                state = "to_counter"
        "to_counter":
            if go_to(target, delta, 0.25):
                state = "serving"
        _:
            target = assigned_counter.service_pad.global_position
            state = "to_counter"
