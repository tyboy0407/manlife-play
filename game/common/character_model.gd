class_name CharacterModel
extends Node3D
## 人物模型(Kenney Mini Characters 這類帶 AnimationPlayer 的 GLB):等比例縮到指定身高、腳底貼 0、XZ 置中,
## 依移動速度切 idle / walk;也能指定動作(工作站工人的 interact、顧客道謝的 emote),一次性動作播完自動回 idle / walk。
## 沒有 AnimationPlayer 的模型只縮放。動畫名稱照 Kenney 的:idle / walk / sprint / pick-up / interact-right / emote-yes ...

const LOOPING := ["idle", "walk", "sprint", "interact-left", "interact-right", "holding-both", "holding-left", "holding-right"]
const WALK_THRESHOLD := 0.15
const BLEND := 0.1

var height := 1.5
var anim: AnimationPlayer = null
var scene_root: Node3D = null

var _action := ""
var _action_loops := false


static func create(scene: PackedScene, p_height: float) -> CharacterModel:
    var cm := CharacterModel.new()
    cm.name = "Model"
    cm.height = p_height
    cm.scene_root = scene.instantiate() as Node3D
    cm.add_child(cm.scene_root)
    cm._setup()
    return cm


func _setup() -> void:
    var box := ModelLibrary.scene_aabb(scene_root)
    var s := height / maxf(box.size.y, 0.01)
    scene_root.scale = Vector3(s, s, s)
    var c := box.get_center()
    scene_root.position = Vector3(-c.x * s, -box.position.y * s, -c.z * s)
    anim = ModelLibrary.find_anim(scene_root)
    if anim == null:
        return
    for n in LOOPING:
        if anim.has_animation(n):
            anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
    if anim.has_animation("idle"):
        anim.play("idle")


## 每幀餵移動速度比例(0 = 站著,1 = 全速):走路動畫速度跟著比例;有動作在播就不切
func set_moving(ratio: float) -> void:
    if anim == null:
        return
    if _action != "":
        if _action_loops or anim.is_playing():
            return
        _action = ""   # 一次性動作播完
    var want := "walk" if ratio > WALK_THRESHOLD else "idle"
    if not anim.has_animation(want):
        return
    if anim.current_animation != want:
        anim.play(want, BLEND)
    anim.speed_scale = clampf(ratio, 0.7, 1.6) if want == "walk" else 1.0


## 指定動作:loop = true 一直播到 clear_action;false 播完自動回 idle / walk。speed 是播放倍速。
func set_action(action: String, loop: bool = true, speed: float = 1.0) -> void:
    if anim == null or not anim.has_animation(action):
        return
    if _action == action and anim.is_playing():
        anim.speed_scale = speed
        return
    _action = action
    _action_loops = loop
    anim.get_animation(action).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
    anim.speed_scale = speed
    anim.play(action, BLEND)


func clear_action() -> void:
    _action = ""


## 目前在播的動畫名(測試用;沒有 AnimationPlayer 回空字串)
func current() -> String:
    return anim.current_animation if anim != null else ""
