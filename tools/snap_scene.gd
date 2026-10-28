extends Node3D
## 開一個小視窗跑主場景、把鏡頭移到幾個地方截圖存成 PNG(接新東西時用來看外觀;headless 畫不出來,所以會短暫跳出視窗)。
## 跑法:godot --path . --resolution 900x900 res://tools/snap_scene.tscn -- <輸出資料夾>(要用場景跑,Autoload 才會在)
## 會截:村子(玩家出生點)、西邊缺口與村外武器店、北極熊咬幫手、帶著 Lv3 武器的玩家、擴建區、一群三隻熊、北極熊王、守衛塔、王拆切魚台、掉落物、村中央的兩座塔。

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
    # 北極熊王在水邊吃魚,玩家打牠(血條扣一半)
    for b in level.bears.bears:
        b.queue_free()
    await _frames(2)
    var king := level.bears.spawn_king()
    king.global_position = Vector3(0, 0, -4.5)
    king.hp = king.hp_max * 0.45
    king._update_hp_bar()
    level.player.global_position = Vector3(1.5, 0, -2.0)
    await _frames(30)
    await _shot("07_bear_king")
    # 守衛塔:西北角的塔蓋好射箭,一隻熊被射中改來拆塔;東北角的塔已經塌了(廢墟 + 修復牌)
    king.queue_free()
    await _frames(2)
    GameState.apply_purchase("tower_1", {"type": "tower", "target": "tower_1"})
    GameState.apply_purchase("tower_2", {"type": "tower", "target": "tower_2"})
    (level.price_pads["tower_1"] as PricePad).restore_state(1, 0)
    (level.price_pads["tower_2"] as PricePad).restore_state(1, 0)
    await _frames(2)
    var t2: Tower = level.tower_by_id("tower_2")
    t2.hp = 1.0
    t2.take_bite(50.0, null)
    var tb := level.bears.spawn()
    tb.global_position = Vector3(-13.0, 0, -8.5)
    tb.hp_max = 400.0
    tb.hp = 400.0
    level.player.global_position = Vector3(-9.0, 0, -5.5)
    await _frames(50)
    await _shot("08_guard_tower")
    # 北極熊王拆切魚台:第一座切魚台已成廢墟(修復牌出現),王正在咬旁邊的第二座
    tb.queue_free()
    await _frames(2)
    (level.station_at("station_1") as Station).wreck(null)
    var king2 := level.bears.spawn_king()
    king2.set_physics_process(false)   # 定住,擺出正在咬切魚台的樣子
    king2.global_position = Vector3(-6.0, 0, -3.6)
    king2.rotation.y = 0.0
    level.player.global_position = Vector3(-3.0, 0, -0.5)
    await _frames(30)
    await _shot("09_king_wrecks")
    # 掉落物與強力守衛塔:地上有毛皮 / 熊王牙,tower_1 用熊王牙強化(金環、金旗)
    king2.queue_free()
    await _frames(2)
    level.drop_loot("pelt", Vector3(-7.0, 0, -4.5))
    level.drop_loot("pelt", Vector3(-5.4, 0, -5.6))
    level.drop_loot("tooth", Vector3(-9.8, 0, -4.0))
    (level.tower_by_id("tower_1") as Tower).upgrade(true)
    level._refresh_tower_pads()
    level.player.global_position = Vector3(-7.5, 0, -7.2)
    await _frames(30)
    await _shot("10_loot_strong_tower")
    # 村中央的兩座塔(tower_5 / 6,切魚台輸入格之間的水邊):左邊蓋好、右邊還是地基牌,玩家站在中間
    for l in level.loot.duplicate():
        l.queue_free()
    level.loot.clear()
    (level.station_at("station_1") as Station).repair(true)
    GameState.apply_purchase("tower_5", {"type": "tower", "target": "tower_5"})
    (level.price_pads["tower_5"] as PricePad).restore_state(1, 0)
    (level.tower_by_id("tower_5") as Tower).build(true)
    level._refresh_tower_pads()
    level.player.global_position = Vector3(0.0, 0, 1.5)
    await _frames(30)
    await _shot("11_center_towers")
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
