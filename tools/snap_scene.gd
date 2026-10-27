extends Node3D
## 開一個小視窗跑主場景、把鏡頭移到幾個地方截圖存成 PNG(接新東西時用來看外觀;headless 畫不出來,所以會短暫跳出視窗)。
## 跑法:godot --path . --resolution 900x900 res://tools/snap_scene.tscn -- <輸出資料夾>(要用場景跑,Autoload 才會在)
## 會截:村子(玩家出生點)、西邊缺口與村外武器店、北極熊咬幫手、帶著 Lv3 武器的玩家、擴建區、一群三隻熊。

const HARBOR := preload("res://game/levels/harbor.tscn")

var out_dir := "user://snaps"
var level: Harbor


func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() > 0:
        out_dir = str(args[0])
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
    SaveManager.save_path = "user://_snap_save.json"
    SaveManager.delete()
    GameState.reset()
    Settings.quality = Settings.FINE
    await _run()


func _run() -> void:
    level = HARBOR.instantiate()
    add_child(level)
    level.bears.enabled = false
    await _frames(10)
    await _shot("01_village")
    # 村外武器店:玩家站在缺口外看
    level.player.global_position = Vector3(-15.5, 0, 2.5)
    await _frames(20)
    await _shot("02_weapon_shop")
    # 北極熊咬幫手:僱一個收銀員放在水邊,熊從入口進來
    var h := level.spawn_helper("cashier", true)
    h.global_position = Vector3(-2.0, 0, -1.0)
    h.assigned_counter = null
    var bear := level.bears.spawn(h)
    bear.global_position = Vector3(-2.0, 0, -2.4)
    level.player.global_position = Vector3(2.0, 0, 2.0)
    await _frames(40)
    await _shot("03_bear_biting")
    # 帶著 Lv3 武器
    GameState.weapon_level = 3
    GameState.changed.emit()
    level.player.global_position = Vector3(-2.0, 0, 3.5)
    bear.set_physics_process(false)
    await _frames(15)
    await _shot("04_weapon_lv3")
    # 擴建村莊:東門拆掉、東邊多一塊地;一群三隻熊從擴建區的入口進來
    bear.queue_free()
    GameState.apply_purchase("expand_village", {"type": "unlock", "target": "village_2"})
    level.player.global_position = Vector3(16.0, 0, 4.0)
    await _frames(30)
    await _shot("05_annex")
    level.bears.spawn_pack(3)
    level.player.global_position = Vector3(24.0, 0, -2.0)
    await _frames(45)
    await _shot("06_bear_pack")
    SaveManager.delete()
    SaveManager.save_path = SaveManager.DEFAULT_PATH
    GameState.reset()
    Sfx.stop_all()
    await _frames(2)
    get_tree().quit(0)


func _frames(n: int) -> void:
    for i in n:
        await get_tree().process_frame


func _shot(name: String) -> void:
    await get_tree().process_frame
    var img := get_viewport().get_texture().get_image()
    var path := out_dir.path_join(name + ".png")
    var err := img.save_png(path)
    print("snap %s -> %s (%s)" % [name, path, "ok" if err == OK else str(err)])
