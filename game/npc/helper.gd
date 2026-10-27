class_name Helper
extends Carrier
## 僱用的幫手,依 role 走不同狀態機:
## fisher 漁夫:到淺水區漫游讓 FishArea 幫它抓魚,滿了找「收魚的工作站」卸貨,沒地方放就換一台或等;
## porter 搬運工:問 Harbor.find_porter_job(規則在 PorterPlanner:庫存比例最低的櫃台優先,烤魚櫃台缺貨會先補烤魚攤的原料),
##   只拿目的地放得下的量;卸不下去就換目的地,都沒有就放回來源工作站的輸出堆再走開(不抱著貨卡住);
## cashier 收銀員:走到被指派櫃台的收銀格站著(櫃台要有人站著才賣得出去)。
## 數值在 game.json helpers.<role>;不收錢、不用垃圾桶。
## 北極熊:靠近時 set_panic(true) 嚇呆不動(頭上驚嘆號、emote-no),被吃掉 be_eaten() 規則上立刻消失、外觀縮小後釋放。

const ROLE_COLORS := {"fisher": Color(0.5, 0.38, 0.6), "porter": Color(0.85, 0.55, 0.25), "cashier": Color(0.3, 0.6, 0.5)}

var role := "fisher"
var level: Harbor = null
var fish_area: FishArea = null
var assigned_counter: Counter = null
var state := "idle"
var target := Vector3.ZERO
var deposited_total := 0    # 漁夫卸進工作站的魚
var delivered_total := 0    # 搬運工送達的件數
var returned_total := 0     # 搬運工送不出去、放回來源的件數
var job := {}               # porter:{"from": Station, "to": Node3D, "item": String}
var panicked := false       # 被北極熊盯上:原地不動
var eaten := false          # 被吃掉了(等外觀縮完就釋放)

var _dest: Node3D = null
var _wander_timer := 0.0
var _idle_timer := 0.0
var _wait_timer := 0.0
var _last_count := 0
var _stall := 0.0         # porter:卸貨時堆疊多久沒變
var _stall_count := 0
var _mark: Label3D = null   # 頭上的驚嘆號


func _ready() -> void:
    color = ROLE_COLORS.get(role, Color(0.5, 0.5, 0.5))
    model_name = ModelLibrary.role_model(role)
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
    if model == null:
        # 占位膠囊時用頭上的色塊標記職業(有模型時每種職業是不同人物)
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
    if panicked:
        move_toward_dir(Vector3.ZERO, delta)
        return
    match role:
        "fisher":
            _fisher(delta)
        "porter":
            _porter(delta)
        "cashier":
            _cashier(delta)
        _:
            move_toward_dir(Vector3.ZERO, delta)


## --- 北極熊 ---

## 嚇呆 / 解除:不動、頭上驚嘆號、模型一直搖頭(emote-no)
func set_panic(on: bool) -> void:
    if on == panicked or eaten:
        return
    panicked = on
    if _mark == null:
        _mark = VisualFactory.label("!", Vector3(0, stack_visual.position.y + 0.9, 0), 72, Color(1.0, 0.3, 0.25))
        add_child(_mark)
    _mark.visible = on
    if model != null:
        if on:
            model.set_action("emote-no", true)
        else:
            model.clear_action()


## 被吃掉:規則上立刻消失(分組 / 旗標 / 物理 / 格子都不再理它),外觀播 die 並縮小 0.5 秒後釋放
func be_eaten() -> void:
    if eaten:
        return
    eaten = true
    panicked = false
    remove_from_group("helper")
    remove_from_group("helper_%s" % role)
    can_fish = false
    takes_output = false
    can_serve = false
    collision_layer = 0
    set_physics_process(false)
    if _mark != null:
        _mark.visible = false
    stack.clear()
    if model != null:
        model.set_action("die", false)
    var tw := create_tween()
    tw.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.5).set_delay(0.15)
    tw.tween_callback(queue_free)


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
## idle -> to_pickup -> picking -> to_dropoff -> dropping -> idle;卸不下去就換目的地,
## 都沒有就 returning(放回來源的輸出堆)-> step_back(走開一步再恢復收貨,不然輸出格會馬上把貨塞回來)。

func _porter(delta: float) -> void:
    match state:
        "to_pickup":
            if not _job_valid():
                job = {}
                state = "idle"
                return
            if go_to(target, delta, 0.3):
                state = "picking"
                _wait_timer = 2.5
        "picking":
            move_toward_dir(Vector3.ZERO, delta)
            _wait_timer -= delta
            var from: Station = job.get("from", null)
            var want := int(job.get("amount", stack.capacity))
            var source_empty := from == null or not is_instance_valid(from) or from.logic.output_count <= 0
            if stack.count >= want or stack.is_full() or (source_empty and not stack.is_empty()) or (_wait_timer <= 0.0 and not stack.is_empty()):
                _start_dropoff(job.get("to", null))
            elif _wait_timer <= 0.0 and stack.is_empty():
                job = {}
                state = "idle"
        "to_dropoff":
            if _dest == null or not is_instance_valid(_dest):
                _start_dropoff(null)
                return
            if go_to(target, delta, 0.3):
                state = "dropping"
                _stall = 0.0
                _stall_count = stack.count
        "dropping":
            move_toward_dir(Vector3.ZERO, delta)
            if stack.is_empty():
                job = {}
                state = "idle"
                return
            if stack.count != _stall_count:
                _stall_count = stack.count
                _stall = 0.0
                return
            _stall += delta
            if _stall < 1.0:
                return
            # 一秒都卸不下去:換個地方,都沒有就放回來源
            _stall = 0.0
            _start_dropoff(level.find_dest_for(stack.item_id, _dest) if level != null else null)
        "returning":
            var from: Station = job.get("from", null)
            if from == null or not is_instance_valid(from):
                takes_output = true
                job = {}
                state = "idle"
                return
            if go_to(target, delta, 0.3):
                var item := stack.item_id
                var back := from.take_back(stack.count)
                for i in back:
                    stack.pop()
                returned_total += back
                if back > 0:
                    EventBus.items_moved.emit("return", item, stack_top(), from.pile_top(false), back)
                target = from.output_pad.global_position + Vector3(0, 0, 2.2)
                state = "step_back"
        "step_back":
            if go_to(target, delta, 0.4):
                takes_output = true
                job = {}
                state = "idle"
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
                    _start_dropoff(d)
                else:
                    var home := level.find_station_with_output(stack.item_id)
                    if home != null:
                        job = {"from": home, "to": null, "item": stack.item_id}
                        _start_return(home)
                return
            job = level.find_porter_job(stack.capacity)
            if not job.is_empty():
                target = (job["from"] as Station).output_pad.global_position
                state = "to_pickup"


## 帶著貨出發去 dest;dest 失效就重找,都沒有就放回來源,連來源都放不下就先 idle(idle 每 0.5 秒再找)
func _start_dropoff(dest: Node3D) -> void:
    if (dest == null or not is_instance_valid(dest)) and level != null:
        dest = level.find_dest_for(stack.item_id, null)
    if dest == null or not is_instance_valid(dest):
        var from: Station = job.get("from", null)
        if from != null and is_instance_valid(from) and from.logic.output_id == stack.item_id and from.logic.output_count < from.logic.output_cap:
            _start_return(from)
        else:
            _dest = null
            state = "idle"
        return
    _dest = dest
    target = _dest_pad_pos(dest)
    state = "to_dropoff"


## 把手上的貨拿回 from 的輸出堆;路上與放回時不收貨
func _start_return(from: Station) -> void:
    takes_output = false
    _dest = null
    target = from.output_pad.global_position
    state = "returning"


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
    # 被改派到別的櫃台(或剛指派)就重新走過去
    var want := assigned_counter.service_pad.global_position
    if state == "idle" or target != want:
        target = want
        state = "to_counter"
    match state:
        "serving":
            move_toward_dir(Vector3.ZERO, delta)
            if planar_distance_to(target) > 0.6:
                state = "to_counter"
        _:
            if go_to(target, delta, 0.25):
                state = "serving"
