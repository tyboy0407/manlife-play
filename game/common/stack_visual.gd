class_name StackVisual
extends Node3D
## 一疊物品的外觀:依 GameData 的物品尺寸 / 顏色疊方塊。columns = 1 是背上的單柱,> 1 是地上排成一列再往上疊。
## 只顯示到 max_visible 個(數字多的用 HUD / 標籤表達)。

var columns := 1
var max_visible := 60
var spacing := 0.06
var item_id := ""
var count := 0

var _meshes: Array[MeshInstance3D] = []


func show_items(p_item_id: String, p_count: int) -> void:
    item_id = p_item_id
    count = maxi(p_count, 0)
    var size := GameData.item_size(item_id) if item_id != "" else Vector3(0.4, 0.1, 0.4)
    var color := GameData.item_color(item_id)
    var shown := mini(count, max_visible)
    while _meshes.size() < shown:
        var m := VisualFactory.box(size, color)
        add_child(m)
        _meshes.append(m)
    var cols := maxi(columns, 1)
    for i in _meshes.size():
        var m := _meshes[i]
        if i >= shown:
            m.visible = false
            continue
        m.visible = true
        (m.mesh as BoxMesh).size = size
        m.material_override = VisualFactory.material(color)
        var col := i % cols
        var level := int(floor(float(i) / float(cols)))
        m.position = Vector3((float(col) - float(cols - 1) / 2.0) * (size.x + spacing),
                size.y / 2.0 + float(level) * (size.y + 0.02), 0.0)


func top_height() -> float:
    if item_id == "" or count == 0:
        return 0.0
    var size := GameData.item_size(item_id)
    var levels := int(ceil(float(mini(count, max_visible)) / float(maxi(columns, 1))))
    return float(levels) * (size.y + 0.02)
