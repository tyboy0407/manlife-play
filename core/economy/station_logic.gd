class_name StationLogic
extends RefCounted
## 工作站規則(純資料):輸入堆 -> 每 process_sec 消耗 input_per 個原料,產出 yield_count 個成品到輸出堆;
## 輸出堆放不下就停工(不消耗輸入)。tick() 回傳本幀產出數。服飾店:5 張毛皮 -> 1 件毛衣(inputPer 5)。

var id := ""
var input_id := ""
var output_id := ""
var input_cap := 12
var output_cap := 24
var process_sec := 1.0
var yield_count := 2
var input_per := 1        # 每批消耗幾個原料(服飾店 5 張毛皮做一件毛衣)
var speed_mult := 1.0

var input_count := 0
var output_count := 0
var progress := 0.0
var processing := false


static func from_def(d: Dictionary) -> StationLogic:
    var s := StationLogic.new()
    s.id = str(d.get("id", ""))
    s.input_id = str(d.get("input", ""))
    s.output_id = str(d.get("output", ""))
    s.input_cap = maxi(int(d.get("inputCap", 12)), 1)
    s.output_cap = maxi(int(d.get("outputCap", 24)), 1)
    s.process_sec = maxf(float(d.get("processSec", 1.0)), 0.05)
    s.yield_count = maxi(int(d.get("yield", 1)), 1)
    s.input_per = maxi(int(d.get("inputPer", 1)), 1)
    return s


func can_accept_input() -> bool:
    return input_count < input_cap


func input_space() -> int:
    return input_cap - input_count


func add_input(n: int = 1) -> int:
    var accepted := mini(n, input_space())
    input_count += accepted
    return accepted


func has_output() -> bool:
    return output_count > 0


## 原料夠做一批
func has_enough_input() -> bool:
    return input_count >= input_per


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
    input_count -= input_per
    var made := mini(yield_count, output_cap - output_count)
    output_count += made
    return made
