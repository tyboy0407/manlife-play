class_name VisualFactory
extends RefCounted
## 占位外觀工廠:方塊 / 膠囊 / 圓柱 MeshInstance3D 與共用材質(依顏色快取)。之後換正式模型時只改這裡與呼叫端。

static var _materials := {}


static func material(color: Color, emission: Color = Color.BLACK, transparent: bool = false) -> StandardMaterial3D:
    var key := "%08x_%08x_%s" % [color.to_rgba32(), emission.to_rgba32(), str(transparent)]
    if _materials.has(key):
        return _materials[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.9
    if emission != Color.BLACK:
        m.emission_enabled = true
        m.emission = emission
        m.emission_energy_multiplier = 1.0
    if transparent or color.a < 1.0:
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _materials[key] = m
    return m


static func box(size: Vector3, color: Color, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mi.mesh = mesh
    mi.material_override = material(color)
    mi.position = pos
    return mi


static func capsule(radius: float, height: float, color: Color, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = height
    mi.mesh = mesh
    mi.material_override = material(color)
    mi.position = pos
    return mi


static func cylinder(radius: float, height: float, color: Color, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mi.mesh = mesh
    mi.material_override = material(color)
    mi.position = pos
    return mi


static func label(text: String, pos: Vector3, font_size: int = 48, color: Color = Color.WHITE) -> Label3D:
    var l := Label3D.new()
    l.text = text
    l.font_size = font_size
    l.modulate = color
    l.outline_size = 8
    l.outline_modulate = Color(0, 0, 0, 0.85)
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.no_depth_test = true
    l.pixel_size = 0.01
    l.position = pos
    return l
