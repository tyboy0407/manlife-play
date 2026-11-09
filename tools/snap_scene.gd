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
    for tid in ["tower_7", "tower_8", "tower_11"]:   # 擴建區照主村布置的塔:北邊兩角與中央那座蓋起來看(tower_12 留地基牌)
        GameState.apply_purchase(tid, {"type": "tower", "target": tid})
        (level.price_pads[tid] as PricePad).restore_state(1, 0)
        (level.tower_by_id(tid) as Tower).build(true)
    level._refresh_tower_pads()
    level.player.global_position = Vector3(22.5, 0, 5.5)
    await _frames(30)
    await _shot("05_annex")
    # 第二次擴建:第一塊擴建區裡的 $2000 牌子付掉後,再往東一塊(第三個水區、第二塊的塔牌)
    GameState.apply_purchase("expand_village_2", {"type": "unlock", "target": "village_3"})
    (level.price_pads["expand_village_2"] as PricePad).restore_state(1, 0)
    GameState.apply_purchase("tower_13", {"type": "tower", "target": "tower_13"})
    (level.price_pads["tower_13"] as PricePad).restore_state(1, 0)
    (level.tower_by_id("tower_13") as Tower).build(true)
    level._refresh_tower_pads()
    level.player.global_position = Vector3(40.0, 0, 5.5)
    await _frames(30)
    await _shot("05b_annex2")
    # 第三次擴建:第二塊擴建區裡的 $8000 牌子付掉後,再往東一塊(兩座烤魚攤 + 服飾店 + 毛衣櫃台、第三塊的塔牌)
    GameState.apply_purchase("expand_village_3", {"type": "unlock", "target": "village_4"})
    (level.price_pads["expand_village_3"] as PricePad).restore_state(1, 0)
    GameState.apply_purchase("tower_23", {"type": "tower", "target": "tower_23"})
    (level.price_pads["tower_23"] as PricePad).restore_state(1, 0)
    (level.tower_by_id("tower_23") as Tower).build(true)
    level._refresh_tower_pads()
    var tailor := level.station_at("tailor")
    if tailor != null:
        tailor.logic.input_count = 7
        tailor.logic.output_count = 1
        tailor.refresh_piles()
    var sc := level.counter_by_id("sweater_counter")
    if sc != null:
        sc.logic.stock = 2
        sc.refresh_pile()
    level.player.global_position = Vector3(60.0, 0, 5.5)
    await _frames(30)
    await _shot("05c_annex3")
    level.player.global_position = Vector3(16.0, 0, 4.0)
    await _frames(5)
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
    # 捕熊夾放好、誘餌魚堆、切魚台 -> 魚片櫃台的傳送帶上有貨、搬運工容量牌
    GameState.apply_purchase("trap_1", {"type": "trap", "target": "trap_1"})
    (level.price_pads["trap_1"] as PricePad).restore_state(1, 0)
    (level.trap_by_id("trap_1") as Trap).arm(true)
    GameState.apply_purchase("bait_1", {"type": "bait", "target": "bait_1"})
    (level.price_pads["bait_1"] as PricePad).restore_state(1, 0)
    (level.bait_by_id("bait_1") as Bait).place(true)
    GameState.apply_purchase("belt_station_1", {"type": "conveyor", "target": "belt_station_1"})
    (level.price_pads["belt_station_1"] as PricePad).restore_state(1, 0)
    var belt := level.conveyor_by_id("belt_station_1")   # apply_purchase 發 purchased 事件,關卡已經蓋好了
    if belt != null:
        belt.restore([6.0, 4.4, 2.8, 1.2])
    level.player.global_position = Vector3(-7.5, 0, -1.0)
    await _frames(30)
    await _shot("13_trap_bait_belt")
    # 故事:武器店老闆的泡泡(王打死過 -> 海的顏色那句)、章節短文面板
    GameState.king_kills = 1
    GameState.set_story_flag("bear_seen")
    GameState.set_story_flag("bear_beaten")
    level.player.global_position = Vector3(-18.3, 0, 2.2)
    await _frames(80)
    level.hud.panel_action("story_close")   # 序章短文會自己彈出來,先關掉才看得到泡泡
    await _frames(2)
    await _shot("14_story_bubble")
    level.hud.show_chapter(tr("STORY_CH1_TITLE"), tr("STORY_CH1_TEXT"))
    await _frames(5)
    await _shot("14b_story_chapter")
    level.hud.panel_action("story_close")
    # 三片地圖拼齊:雪原東北角的冰母神龕與牌
    GameState.map_pieces = 3
    level._sync_map_pads()
    level._refresh_tower_pads()
    level.player.global_position = Vector3(86.0, 0, -5.0)
    await _frames(40)
    level.hud.panel_action("story_close")
    await _frames(2)
    await _shot("15_shrine")
    # 日誌頁
    level.story.refresh()
    level.hud.show_journal(level.story.chapter_entries(), level.story.journal_entries())
    await _frames(5)
    await _shot("16_journal")
    level.hud.panel_action("journal_close")
    # 守衛塔升級面板(站在 tower_5 旁 5 秒會開;這裡直接開)與衛兵打熊
    var t5 := level.tower_by_id("tower_5") as Tower
    t5.rate_level = 3
    t5.damage_level = 2
    level.tower_upgrading = t5
    level.player.global_position = Vector3(-3.0, 0, -0.8)
    await _frames(60)   # 相機從神龕那邊慢慢跟回來
    level.hud.show_tower_upgrade(level.tower_upgrade_data(t5))
    await _frames(10)
    await _shot("17_tower_upgrade")
    level.hud.panel_action("tower_close")
    GameState.apply_purchase("hire_guard", {"type": "hire", "role": "guard"})
    var guard := level.spawn_helper("guard", true)
    var gbear := level.bears.spawn()
    gbear.set_physics_process(false)
    gbear.hp_max = 400.0
    gbear.hp = 300.0
    gbear.global_position = Vector3(2.0, 0, 1.0)
    guard.global_position = Vector3(-1.5, 0, 1.0)
    level.player.global_position = Vector3(0.0, 0, 5.0)
    await _frames(70)
    await _shot("18_guard")
    gbear.queue_free()
    # 雪地貨車停在車庫(車上 12 條魚)、放置區 120 條、搬運工來拿
    GameState.apply_purchase("truck", {"type": "truck"})
    (level.price_pads["truck"] as PricePad).restore_state(1, 0)
    var tk := level.trucks[0] if not level.trucks.is_empty() else level.spawn_truck(true)
    tk.fish = 12
    tk._refresh_pile()
    tk.set_physics_process(false)
    level.depot.receive(120)
    level.player.global_position = Vector3(2.5, 0, 8.0)
    await _frames(40)
    await _shot("19_truck_depot")
    # 往南疊四塊(第四 ~ 七次擴建),鏡頭停在南塊 2 的櫃台排
    for k in [4, 5, 6, 7]:
        GameState.apply_purchase("expand_village_%d" % k, {"type": "unlock", "target": "village_%d" % (k + 1)})
        (level.price_pads["expand_village_%d" % k] as PricePad).restore_state(1, 0)
        await _frames(2)
    level.player.global_position = Vector3(0.0, 0, 41.0)
    await _frames(40)
    level.story.refresh()
    level.hud.panel_action("story_close")   # 南邊擴建會解鎖新章節,短文先關掉
    await _frames(40)
    await _shot("20_south_blocks")
    level.player.global_position = Vector3(0.0, 0, 76.0)
    await _frames(70)
    level.hud.panel_action("story_close")
    await _frames(5)
    await _shot("21_south_block4")
    tk.set_physics_process(true)
    level.player.global_position = Vector3(0.0, 0, 1.5)
    await _frames(5)
    # 選單打開:詳細統計收在面板裡,左上角只剩錢包 / 背包 / 毛皮 / 牙 / 武器
    level.hud.menu_action("toggle")
    await _frames(5)
    await _shot("12_menu_stats")
    level.hud.menu_action("close")
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
    await RenderingServer.frame_post_draw   # 等這一幀真的畫完再讀,不然會拿到舊的畫面
    var img := get_viewport().get_texture().get_image()
    var path := out_dir.path_join(name + ".png")
    var err := img.save_png(path)
    print("snap %s -> %s (%s)" % [name, path, "ok" if err == OK else str(err)])
