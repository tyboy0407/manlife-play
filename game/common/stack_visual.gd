class_name StackVisual
extends Node3D
## 一疊物品的外觀:依 GameData 的物品尺寸 / 顏色疊方塊。columns = 1 是背上的單柱,> 1 是地上排成一列再往上疊。
## 整堆用一個 MultiMesh 畫(一次繪製呼叫,手機上才不會幾百個呼叫);位置只在換物品種類時重排,
## 之後只調 visible_instance_count。只顯示到 max_visible 個(數字多的用 HUD / 標籤表達)。

var columns := 1
var max_visible := 60
var spacing := 0.06
var item_id := ""
var count := 0

var _mmi: MultiMeshInstance3D
var _mm: MultiMesh
var _box: BoxMesh
var _laid_out_for := ""
var _laid_out_cols := 0


func _ready() -> void:
    _box = BoxMesh.new()
    _mm = MultiMesh.new()
    _mm.transform_format = MultiMesh.TRANSFORM_3D
    _mm.mesh = _box
    _mmi = MultiMeshInstance3D.new()
    _mmi.multimesh = _mm
    add_child(_mmi)
    _apply()


func show_items(p_item_id: String, p_count: int) -> void:
    item_id = p_item_id
    count = maxi(p_count, 0)
    if _mm != null:
        _apply()


## 目前畫出來的個數(測試用)
func visible_count() -> int:
    return _mm.visible_instance_count if _mm != null else 0


func _apply() -> void:
    var shown := mini(count, max_visible)
    if _mm.instance_count != max_visible:
        _mm.instance_count = max_visible   # 配置一次,之後只改 visible_instance_count
        _laid_out_for = ""
    if shown <= 0 or item_id == "":
        _mm.visible_instance_count = 0
        _mmi.visible = false
        return
    _mmi.visible = true
    if _laid_out_for != item_id or _laid_out_cols != maxi(columns, 1):
        _layout()
    _mm.visible_instance_count = shown


## 依物品尺寸把 max_visible 個位置排好(換種類才需要)
func _layout() -> void:
    var size := GameData.item_size(item_id)
    _box.size = size
    _mmi.material_override = VisualFactory.material(GameData.item_color(item_id))
    var cols := maxi(columns, 1)
    for i in max_visible:
        var col := i % cols
        var level := int(floor(float(i) / float(cols)))
        var pos := Vector3((float(col) - float(cols - 1) / 2.0) * (size.x + spacing), size.y / 2.0 + float(level) * (size.y + 0.02), 0.0)
        _mm.set_instance_transform(i, Transform3D(Basis(), pos))
    _laid_out_for = item_id
    _laid_out_cols = cols


func top_height() -> float:
    if item_id == "" or count == 0:
        return 0.0
    var size := GameData.item_size(item_id)
    var levels := int(ceil(float(mini(count, max_visible)) / float(maxi(columns, 1))))
    return float(levels) * (size.y + 0.02)
