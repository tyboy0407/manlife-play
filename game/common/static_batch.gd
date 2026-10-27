class_name StaticBatch
extends MeshInstance3D
## 把不會動的方塊 / 圓柱依顏色合併成一個 ArrayMesh:每種顏色一個 surface = 一次繪製呼叫,
## 取代幾十個 MeshInstance3D(手機 WebGL 每個繪製呼叫都貴)。用法:add_box / add_cylinder 收集,最後 build()。

var _parts := []   # {"mesh": Mesh, "color": Color, "pos": Vector3}


func add_box(size: Vector3, color: Color, pos: Vector3) -> void:
    var m := BoxMesh.new()
    m.size = size
    _parts.append({"mesh": m, "color": color, "pos": pos})


func add_cylinder(radius: float, height: float, color: Color, pos: Vector3, segments: int = 12) -> void:
    var m := CylinderMesh.new()
    m.top_radius = radius
    m.bottom_radius = radius
    m.height = height
    m.radial_segments = segments
    _parts.append({"mesh": m, "color": color, "pos": pos})


## 合併;回傳 surface 數(= 繪製呼叫數)
func build() -> int:
    var groups := {}
    var order := []
    for p in _parts:
        var key: int = (p["color"] as Color).to_rgba32()
        if not groups.has(key):
            groups[key] = []
            order.append(key)
        groups[key].append(p)
    var am := ArrayMesh.new()
    for key in order:
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        var color: Color = groups[key][0]["color"]
        for p in groups[key]:
            st.append_from(p["mesh"], 0, Transform3D(Basis(), p["pos"]))
        st.commit(am)
        am.surface_set_material(am.get_surface_count() - 1, VisualFactory.material(color))
    mesh = am
    _parts.clear()
    return am.get_surface_count()
