class_name ProgressRing
extends Node3D
## 平放的進度環(XZ 平面):底環 + 依進度畫的弧,從螢幕上方(世界 -Z)順時針。
## set_progress 量化成 segments 段,段數沒變就不重建網格;材質不受光、雙面。

var inner := 1.0
var outer := 1.2
var color := Color(1.0, 0.8, 0.2)
var bg_color := Color(0.1, 0.1, 0.12, 0.8)
var segments := 48
var progress := 0.0

var _bg: MeshInstance3D
var _fg: MeshInstance3D
var _last_n := -1


func _ready() -> void:
    _bg = MeshInstance3D.new()
    _bg.mesh = _arc_mesh(1.0, segments)
    _bg.material_override = _material(bg_color)
    add_child(_bg)
    _fg = MeshInstance3D.new()
    _fg.material_override = _material(color)
    _fg.position.y = 0.005
    add_child(_fg)
    _rebuild()


func set_progress(p: float) -> void:
    progress = clampf(p, 0.0, 1.0)
    if _fg != null:
        _rebuild()


## 目前畫了幾段(測試用)
func drawn_segments() -> int:
    return maxi(_last_n, 0)


func _rebuild() -> void:
    var n := int(ceil(progress * float(segments) - 0.0001))
    n = clampi(n, 0, segments)
    if n == _last_n:
        return
    _last_n = n
    _fg.mesh = _arc_mesh(float(n) / float(segments), n) if n > 0 else null


func _material(c: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    if c.a < 1.0:
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    return m


## 畫 frac 圈(0 ~ 1)的環,分 n 段
func _arc_mesh(frac: float, n: int) -> ArrayMesh:
    var verts := PackedVector3Array()
    var normals := PackedVector3Array()
    var indices := PackedInt32Array()
    var total := TAU * frac
    for i in n + 1:
        var a := -PI / 2.0 + total * float(i) / float(maxi(n, 1))
        var c := cos(a)
        var s := sin(a)
        verts.append(Vector3(inner * c, 0.0, inner * s))
        normals.append(Vector3.UP)
        verts.append(Vector3(outer * c, 0.0, outer * s))
        normals.append(Vector3.UP)
    for i in n:
        var k := i * 2
        indices.append_array(PackedInt32Array([k, k + 1, k + 2, k + 1, k + 3, k + 2]))
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh
