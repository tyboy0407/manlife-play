extends Node
## 飛行動畫(Autoload:Fx):聽 EventBus.items_moved,生一個物品外觀的「幽靈」沿拋物線從 from 飛到 to 再消失。
## 純表現層:交易在規則層瞬間完成,這裡只演;現金飛向錢包由 HUD 用 2D 畫(kind "cash" 這裡跳過)。
## 幽靈直接掛在這個 Autoload 底下(Node3D 在非 3D 父節點下就是世界座標),換場景也不會被砍到一半。

const MAX_PER_EVENT := 4
const DURATION := 0.3
const ARC := 1.1

var enabled := true
var spawned_total := 0

var _meshes := {}


func _ready() -> void:
    EventBus.items_moved.connect(_on_items_moved)


## 還在飛的幽靈數
var _pool: Array[Node3D] = []   # 飛完的幽靈(藏著)


func active() -> int:
    return get_child_count()


func _on_items_moved(kind: String, item: String, from: Vector3, to: Vector3, count: int) -> void:
    if not enabled or kind == "cash":
        return
    var n := mini(count, MAX_PER_EVENT)
    for i in n:
        var jitter := Vector3(randf_range(-0.15, 0.15), 0.0, randf_range(-0.15, 0.15))
        fly(item, from + jitter, to, DURATION + 0.05 * float(i), ARC + 0.2 * float(i))


## 生一個 item 外觀的幽靈從 from 拋到 to(幽靈節點用物件池,飛完藏起來等下次用,不每次 new / queue_free)
func fly(item: String, from: Vector3, to: Vector3, duration: float = DURATION, arc: float = ARC) -> void:
    var ghost := _take_ghost()
    var mi: MeshInstance3D = ghost.get_child(0)
    var mesh := ModelLibrary.item_mesh(item)
    if mesh != null:
        mi.mesh = mesh
        mi.transform = ModelLibrary.item_fit(item)
        mi.material_override = null
    else:
        mi.mesh = _mesh_for(item)
        mi.transform = Transform3D.IDENTITY
        mi.material_override = VisualFactory.material(GameData.item_color(item))
    ghost.visible = true
    ghost.scale = Vector3.ONE
    ghost.global_position = from
    spawned_total += 1
    var tw := ghost.create_tween()
    tw.tween_method(_step_ghost.bind(ghost, from, to, arc), 0.0, 1.0, duration)
    tw.tween_callback(_release_ghost.bind(ghost))


func _take_ghost() -> Node3D:
    if not _pool.is_empty():
        return _pool.pop_back()
    var ghost := Node3D.new()
    ghost.add_child(MeshInstance3D.new())
    add_child(ghost)
    return ghost


func _release_ghost(ghost: Node3D) -> void:
    if not is_instance_valid(ghost):
        return
    ghost.visible = false
    _pool.append(ghost)


## 池裡閒置的幽靈數(給測試)
func pooled() -> int:
    return _pool.size()


func _step_ghost(t: float, ghost: Node3D, from: Vector3, to: Vector3, arc: float) -> void:
    if not is_instance_valid(ghost):
        return
    ghost.global_position = from.lerp(to, t) + Vector3(0.0, sin(t * PI) * arc, 0.0)
    ghost.rotation.y = t * PI
    var s := 1.0 - 0.3 * t
    ghost.scale = Vector3(s, s, s)


func _mesh_for(item: String) -> BoxMesh:
    if not _meshes.has(item):
        var m := BoxMesh.new()
        m.size = GameData.item_size(item)
        _meshes[item] = m
    return _meshes[item]
