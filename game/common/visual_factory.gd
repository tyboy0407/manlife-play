class_name VisualFactory
extends RefCounted
## 占位外觀工廠:方塊 / 膠囊 / 圓柱 MeshInstance3D 與共用材質(依顏色快取)。之後換正式模型時只改這裡與呼叫端。

## 內建字型沒有中文,網頁版又拿不到系統字型,所以 Label3D 一律用專案內的 Noto Sans TC(Controls 由 gui/theme/custom_font 設定)
const CJK_FONT: Font = preload("res://assets/fonts/NotoSansTC-VF.ttf")

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


## 腳下的圓影:流暢模式用它代替即時陰影(透明圓片,不投影);加進 blob_shadow 群組,Harbor 依畫質開關
static func blob_shadow(radius: float, visible_now: bool) -> MeshInstance3D:
    var mi := cylinder(radius, 0.02, Color(0, 0, 0, 0.28), Vector3(0, 0.02, 0))
    (mi.mesh as CylinderMesh).radial_segments = 20
    mi.material_override = material(Color(0, 0, 0, 0.28), Color.BLACK, true)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mi.add_to_group("blob_shadow")
    mi.visible = visible_now
    return mi


## 圓錐(尖端朝 +Y)
static func cone(radius: float, height: float, color: Color, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.0
    mesh.bottom_radius = radius
    mesh.height = height
    mi.mesh = mesh
    mi.material_override = material(color)
    mi.position = pos
    return mi


static func label(text: String, pos: Vector3, font_size: int = 48, color: Color = Color.WHITE) -> Label3D:
    var l := Label3D.new()
    l.text = text
    l.font = CJK_FONT
    l.font_size = font_size
    l.modulate = color
    l.outline_size = 8
    l.outline_modulate = Color(0, 0, 0, 0.85)
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.no_depth_test = true
    l.pixel_size = 0.01
    l.position = pos
    l.add_to_group("label3d")   # Harbor._fade_labels:離玩家遠的標籤淡出(meta keep 的不淡:價格牌、招牌)
    return l


## 標記這個 3D 標籤不隨距離淡出(價格牌、村外招牌)
static func keep(l: Label3D) -> Label3D:
    l.set_meta("keep", true)
    return l
