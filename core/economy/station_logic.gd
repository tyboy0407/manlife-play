class_name StationLogic
extends RefCounted
## 工作站規則(純資料):原料堆 -> 每 process_sec 消耗每種原料 input_per 個,產出 yield_count 個成品到輸出堆;
## 輸出堆放不下就停工(不消耗輸入)。tick() 回傳本幀產出數。服飾店:5 張毛皮 -> 1 件毛衣(inputPer 5)。
## 多種原料(廚房:魚片 + 烤魚 -> 魚湯):stations.json 的 input 給陣列,每種原料各自一堆(counts),每堆上限 input_cap,
## 每種都夠 input_per 才做一批。單原料的舊介面(input_id / input_count / add_input / input_space)對應第一種原料,舊程式不用改。

var id := ""
var inputs: Array[String] = []   # 原料種類(至少一種)
var output_id := ""
var input_cap := 12
var output_cap := 24
var process_sec := 1.0
var yield_count := 2
var input_per := 1        # 每批每種原料消耗幾個(服飾店 5 張毛皮做一件毛衣)
var speed_mult := 1.0

var counts := {}          # 原料 -> 堆裡有幾個
var output_count := 0
var progress := 0.0
var processing := false

var input_id: String:
    get:
        return inputs[0] if not inputs.is_empty() else ""
    set(v):
        if inputs.is_empty():
            inputs.append(v)
        else:
            inputs[0] = v

var input_count: int:
    get:
        return input_count_of(input_id)
    set(v):
        counts[input_id] = maxi(v, 0)


static func from_def(d: Dictionary) -> StationLogic:
    var s := StationLogic.new()
    s.id = str(d.get("id", ""))
    var inp = d.get("input", "")
    if typeof(inp) == TYPE_ARRAY:
        for i in inp:
            s.inputs.append(str(i))
    else:
        s.inputs.append(str(inp))
    s.output_id = str(d.get("output", ""))
    s.input_cap = maxi(int(d.get("inputCap", 12)), 1)
    s.output_cap = maxi(int(d.get("outputCap", 24)), 1)
    s.process_sec = maxf(float(d.get("processSec", 1.0)), 0.05)
    s.yield_count = maxi(int(d.get("yield", 1)), 1)
    s.input_per = maxi(int(d.get("inputPer", 1)), 1)
    return s


## 這座工作站收不收 item 當原料
func accepts(item: String) -> bool:
    return inputs.has(item)


func is_multi_input() -> bool:
    return inputs.size() > 1


func input_count_of(item: String) -> int:
    return int(counts.get(item, 0))


func input_space_of(item: String) -> int:
    return input_cap - input_count_of(item) if accepts(item) else 0


func can_accept_input_of(item: String) -> bool:
    return input_space_of(item) > 0


func add_input_of(item: String, n: int = 1) -> int:
    var accepted := mini(n, input_space_of(item))
    if accepted > 0:
        counts[item] = input_count_of(item) + accepted
    return accepted


## 所有原料堆的總數(給統計 / 提示「堆裡有東西」用)
func total_input() -> int:
    var n := 0
    for item in inputs:
        n += input_count_of(item)
    return n


## --- 單原料的舊介面(對應第一種原料)---

func can_accept_input() -> bool:
    return can_accept_input_of(input_id)


func input_space() -> int:
    return input_space_of(input_id)


func add_input(n: int = 1) -> int:
    return add_input_of(input_id, n)


func has_output() -> bool:
    return output_count > 0


## 每種原料都夠做一批
func has_enough_input() -> bool:
    for item in inputs:
        if input_count_of(item) < input_per:
            return false
    return not inputs.is_empty()


## 哪種原料不夠做一批(給提示:多原料的工作站缺什麼);都夠回空字串
func missing_input() -> String:
    for item in inputs:
        if input_count_of(item) < input_per:
            return item
    return ""


func take_output(n: int = 1) -> int:
    var taken := mini(n, output_count)
    output_count -= taken
    return taken


## 輸出堆放不下一批產出
func is_blocked() -> bool:
    return output_count + yield_count > output_cap


func is_working() -> bool:
    return processing


func work_progress() -> float:
    return clampf(progress / process_sec, 0.0, 1.0)


func tick(delta: float) -> int:
    if not processing:
        if not has_enough_input() or is_blocked():
            progress = 0.0
            return 0
        processing = true
        progress = 0.0
    progress += delta * speed_mult
    if progress < process_sec:
        return 0
    processing = false
    progress = 0.0
    for item in inputs:
        counts[item] = input_count_of(item) - input_per
    var made := mini(yield_count, output_cap - output_count)
    output_count += made
    return made
