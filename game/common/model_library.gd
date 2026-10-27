class_name ModelLibrary
extends RefCounted
## 模型載入(靜態快取):人物 GLB(game.json 的 models 區塊)、物品模型(items.json 的 model 欄位)、水裡游的魚(models.waterFish)。
## 載不到就回 null,呼叫端退回占位方塊 / 膠囊,所以沒有模型檔專案也跑得起來(之後換模型只改資料)。
## 模型檔只放 assets/models/game/(原始套件資料夾有 .gdignore,Godot 不會匯入)。

static var _scenes := {}        # path -> PackedScene(null = 載過但失敗)
static var _item_meshes := {}   # item_id -> Mesh(null = 沒有模型)
static var _item_fits := {}     # item_id -> Transform3D


static func config() -> Dictionary:
    return GameData.section("models")


static func clear_cache() -> void:
    _scenes.clear()
    _item_meshes.clear()
    _item_fits.clear()


static func _scene(path: String) -> PackedScene:
    if path == "":
        return null
    if _scenes.has(path):
        return _scenes[path]
    var res: PackedScene = null
    if ResourceLoader.exists(path):
        var r = load(path)
        if r is PackedScene:
            res = r
    if res == null:
        push_warning("模型載入失敗:%s" % path)
    _scenes[path] = res
    return res


## --- 人物 ---

## 人物場景:models.characterDir + name + ".glb";name 空字串回 null
static func character(name: String) -> PackedScene:
    if name == "":
        return null
    return _scene(str(config().get("characterDir", "")) + name + ".glb")


static func character_height() -> float:
    return float(config().get("characterHeight", 1.5))


static func customer_height() -> float:
    return float(config().get("customerHeight", 1.3))


static func player_model() -> String:
    return str(config().get("player", ""))


static func worker_model() -> String:
    return str(config().get("worker", ""))


static func role_model(role: String) -> String:
    var roles = config().get("roles", {})
    return str(roles.get(role, "")) if typeof(roles) == TYPE_DICTIONARY else ""


static func customer_models() -> Array:
    var v = config().get("customers", [])
    return v if typeof(v) == TYPE_ARRAY else []


## 任意道具 / 建築模型場景(武器、北極熊...);路徑空或載不到回 null
static func prop(path: String) -> PackedScene:
    return _scene(path)


## 武器店老闆用哪個人物(models.shopkeeper)
static func shopkeeper_model() -> String:
    return str(config().get("shopkeeper", ""))


## 守衛塔上的守衛用哪個人物(models.guard)
static func guard_model() -> String:
    return str(config().get("guard", ""))


## 北極熊模型(models.bear.file);沒有就 null,Bear 用方塊占位
static func bear() -> PackedScene:
    var v = config().get("bear", {})
    return _scene(str(v.get("file", ""))) if typeof(v) == TYPE_DICTIONARY else null


## --- 水裡游的魚(models.waterFish:dir / files / length / yawDeg)---

static func _water_cfg() -> Dictionary:
    var v = config().get("waterFish", {})
    return v if typeof(v) == TYPE_DICTIONARY else {}


static func water_fish_count() -> int:
    var files = _water_cfg().get("files", [])
    return files.size() if typeof(files) == TYPE_ARRAY else 0


static func water_fish(index: int) -> PackedScene:
    var files = _water_cfg().get("files", [])
    if typeof(files) != TYPE_ARRAY or files.is_empty():
        return null
    return _scene(str(_water_cfg().get("dir", "")) + str(files[posmod(index, files.size())]))


static func water_fish_length() -> float:
    return float(_water_cfg().get("length", 0.9))


static func water_fish_yaw() -> float:
    return deg_to_rad(float(_water_cfg().get("yawDeg", 0.0)))


## --- 物品模型(items.json 的 model:{file, rotationDeg})---

## 物品模型的網格(model.file 裡第一個 MeshInstance3D 的 mesh);沒有就 null(呼叫端用方塊)
static func item_mesh(item_id: String) -> Mesh:
    _ensure_item(item_id)
    return _item_meshes[item_id]


## 把模型塞進 items.json 尺寸框的變換:先轉 rotationDeg,再等比例縮到框內,XZ 置中、底部貼框底
## (StackVisual 的實例原點是框的中心,所以底部在 -size.y / 2);沒有模型回 IDENTITY
static func item_fit(item_id: String) -> Transform3D:
    _ensure_item(item_id)
    return _item_fits[item_id]


static func _ensure_item(item_id: String) -> void:
    if _item_meshes.has(item_id):
        return
    _item_meshes[item_id] = null
    _item_fits[item_id] = Transform3D.IDENTITY
    var m = GameData.item(item_id).get("model", null)
    if typeof(m) != TYPE_DICTIONARY:
        return
    var scene := _scene(str(m.get("file", "")))
    if scene == null:
        return
    var inst := scene.instantiate()
    var mi := first_mesh(inst)
    if mi == null or mi.mesh == null:
        inst.free()
        return
    var mesh: Mesh = mi.mesh
    var rot := Vector3.ZERO
    var r = m.get("rotationDeg", null)
    if typeof(r) == TYPE_ARRAY and r.size() >= 3:
        rot = Vector3(deg_to_rad(float(r[0])), deg_to_rad(float(r[1])), deg_to_rad(float(r[2])))
    var pre := Transform3D(Basis.from_euler(rot), Vector3.ZERO) * local_xform(mi, inst)
    var box := pre * mesh.get_aabb()
    var size := GameData.item_size(item_id)
    var s := minf(size.x / maxf(box.size.x, 0.0001), minf(size.y / maxf(box.size.y, 0.0001), size.z / maxf(box.size.z, 0.0001)))
    var center := box.get_center() * s
    var offset := Vector3(-center.x, -size.y / 2.0 - box.position.y * s, -center.z)
    _item_fits[item_id] = Transform3D(Basis.IDENTITY.scaled(Vector3(s, s, s)), offset) * pre
    _item_meshes[item_id] = mesh
    inst.free()


## --- 場景工具 ---

## 節點相對於 root 的變換(沿父節點累乘;節點不在 root 底下就只回自己的)
static func local_xform(n: Node3D, root: Node) -> Transform3D:
    if n == root:
        return Transform3D.IDENTITY
    var xf := n.transform
    var p := n.get_parent()
    while p != null and p != root and p is Node3D:
        xf = (p as Node3D).transform * xf
        p = p.get_parent()
    return xf


## root 底下第一個有 mesh 的 MeshInstance3D
static func first_mesh(root: Node) -> MeshInstance3D:
    for mi in mesh_instances(root):
        return mi
    return null


## root 底下所有 MeshInstance3D(含自己)
static func mesh_instances(root: Node) -> Array[MeshInstance3D]:
    var out: Array[MeshInstance3D] = []
    var stack: Array[Node] = [root]
    while not stack.is_empty():
        var cur: Node = stack.pop_back()
        if cur is MeshInstance3D and (cur as MeshInstance3D).mesh != null:
            out.append(cur as MeshInstance3D)
        for i in range(cur.get_child_count() - 1, -1, -1):
            stack.append(cur.get_child(i))
    return out


static func find_anim(root: Node) -> AnimationPlayer:
    var stack: Array[Node] = [root]
    while not stack.is_empty():
        var cur: Node = stack.pop_back()
        if cur is AnimationPlayer:
            return cur as AnimationPlayer
        for i in range(cur.get_child_count() - 1, -1, -1):
            stack.append(cur.get_child(i))
    return null


## root 底下所有網格合起來的 AABB(root 的區域座標;骨架網格用的是綁定姿勢的網格框)
static func scene_aabb(root: Node) -> AABB:
    var out := AABB()
    var first := true
    for mi in mesh_instances(root):
        var box := local_xform(mi, root) * mi.mesh.get_aabb()
        if first:
            out = box
            first = false
        else:
            out = out.merge(box)
    return out
