extends WorldTestBase
## 世界整合 headless 驗證第二段(約 3 分鐘):從 verify_world 的交接存檔接手(經濟鏈、武器 Lv4、守衛塔、捕熊夾都買好了)->
## 擴建村莊三次 -> 北極熊王(預告、吃魚 / 吃幫手、拆建築、打死、寶箱三選一)-> 強力守衛塔 -> 存檔 / 重建關卡還原 -> 離線收益 ->
## 券 / 祭壇 -> 新遊戲。跑法:先跑 verify_world,再 godot --headless --path . res://tests/verify_world2.tscn。


func _tag() -> String:
    return "WORLD2"


## --- 流程 ---

func _run() -> void:
    if not FileAccess.file_exists(HANDOFF):
        _check(false, "找不到 verify_world 的交接存檔(%s),先跑 verify_world" % HANDOFF)
        return
    DirAccess.copy_absolute(ProjectSettings.globalize_path(HANDOFF), ProjectSettings.globalize_path(SaveManager.save_path))
    await _spawn_level()
    await _step(2)
    _check(_level.loaded_from_save and GameState.weapon_level == 4 and GameState.tutorial_step == 7 and _level.tower_by_id("tower_1").is_alive()
            and _level.station_at("grill") != null and _find_helper("cashier") != null and _find_helper("porter") != null,
            "從 verify_world 的交接存檔接手:武器 Lv4、守衛塔 1、烤魚攤、收銀員 / 搬運工都在")
    var st := _level.station_at("station_1")
    var grill := _level.station_at("grill")
    var cnt := _level.counter_by_id("fillet_counter")
    var fisher_pad: PricePad = _level.price_pads["hire_fisher"]
    await _expand_section()
    await _south_section()
    await _king_section()
    await _tower_strong_section()
    # 存檔 -> 重建 -> 還原
    var saved := _level.save_now()
    var snap := _level.snapshot()
    var cash_saved := _level.money_pad.cash
    var wallet_saved := GameState.wallet
    var earned_saved := GameState.cash_earned
    var hired_saved := GameState.hired_total()
    var pl_item := _player.stack.item_id
    var pl_count := _player.stack.count
    var st1_out := st.logic.output_count
    var belt_saved_items := _level.conveyor_by_id("belt_station_1").logic.count()   # 讀檔後帶子馬上會動,堆 + 帶 + 櫃台的總數才守恆
    var grill_out := grill.logic.output_count
    var fstock := cnt.logic.stock
    var fp_rem := fisher_pad.logic.remaining
    var bear_cd := _level.bears.cooldown
    var king_next_saved := _level.bears.king_next_sec
    var play_time_saved := GameState.play_time
    var weapon_saved := GameState.weapon_level
    var lost_saved := GameState.helpers_lost
    var pelts_saved := GameState.pelts
    var loot_saved := _level.loot.size()
    var tower_saved: Tower = _level.tower_by_id("tower_1")
    var tower_hp_saved := tower_saved.hp
    var tower_alive_saved := tower_saved.is_alive()
    _check(saved and SaveManager.has_save() and int(snap["money"]) == cash_saved and snap["stations"].has("grill")
            and snap["counters"].has("grill_counter") and snap["pads"].has("hire_fisher") and is_equal_approx(float(snap["bear"]["cooldown"]), bear_cd)
            and snap["towers"].has("tower_1") and str(snap["towers"]["tower_1"]["state"]) == "alive",
            "存檔寫入、快照內容(含北極熊冷卻 %.0f 秒)" % bear_cd)
    _level.queue_free()
    await _step(3)
    GameState.reset()
    _check(GameState.hired_total() == 0 and GameState.wallet == 0, "reset 後狀態清空")
    await _spawn_level()
    await _step(2)
    var st2 := _level.station_at("station_1")
    var grill2 := _level.station_at("grill")
    var cnt2 := _level.counter_by_id("fillet_counter")
    _check(_level.loaded_from_save and GameState.cash_earned == earned_saved and GameState.hired_total() == hired_saved
            and GameState.upgrade_level("worker_speed") == 1 and GameState.wallet == wallet_saved and GameState.tutorial_step == 7
            and not _level.guide.in_tutorial, "重建關卡:讀回 GameState(含錢包 $%d、教學已完成)" % wallet_saved)
    _check(not _level.hud.offline_open() and not get_tree().paused and _level.offline_sec < 60,
            "剛存的檔(離線 %d 秒不滿 1 分鐘):沒有離線收益面板、遊戲沒暫停" % _level.offline_sec)
    var tailor2 := _level.station_at("tailor")
    _check(_level.stations.size() == 12 and grill2 != null and _level.counters.size() == 8 and _level.helpers.size() == hired_saved
            and _level.expansion_level() == 4 and _level.has_south_block() and _level.south_walls.is_empty() and _level.station_at("kitchen") != null
            and _level.counter_by_id("soup_counter") != null and _level.fish_areas.size() == 4 and _level.east_gate == null and _level.station_at("grill_2") != null
            and _level.station_at("grill_5") != null and _level.station_at("grill_7") != null and tailor2 != null and tailor2.logic.input_per == 5
            and _level.counter_by_id("sweater_counter") != null
            and _level.annex_east_walls[0].is_empty() and _level.annex_east_walls[1].is_empty() and not _level.annex_east_walls[2].is_empty()
            and (_level.price_pads["tower_13"] as PricePad).visible and (_level.price_pads["tower_24"] as PricePad).visible
            and not (_level.price_pads["expand_village_2"] as PricePad).visible and not (_level.price_pads["expand_village_3"] as PricePad).visible,
            "重建關卡:烤魚攤、烤魚櫃台、%d 個幫手、三塊擴建區(四個水區、十一座工作站含服飾店、七座櫃台、每塊的塔牌)都回來了" % hired_saved)
    var belt2 := _level.conveyor_by_id("belt_station_1")
    var fillets_now := st2.logic.output_count + cnt2.logic.stock + (belt2.logic.count() if belt2 != null else 0)
    _check(_level.money_pad.cash == cash_saved and st2 != null and grill2.logic.output_count == grill_out and cnt2 != null
            and fillets_now == st1_out + fstock + belt_saved_items and belt2 != null and belt2.logic.count() <= belt2.logic.capacity(),
            "重建關卡:錢格、工作站堆、櫃台庫存還原(切魚台堆 + 傳送帶 + 魚片櫃台 %d = 存檔時 %d)" % [fillets_now, st1_out + fstock + belt_saved_items])
    _check(_player.stack.item_id == pl_item and _player.stack.count == pl_count and _player.stack.capacity == 8, "重建關卡:玩家背上還原")
    var fp2: PricePad = _level.price_pads["hire_fisher"]
    var ug2: PricePad = _level.price_pads["unlock_grill"]
    _check(fp2.logic.buys == 1 and fp2.logic.remaining == fp_rem and fp2.logic.current_cost() == 18 and fp2.visible
            and not ug2.visible and ug2.logic.is_exhausted(), "重建關卡:價格牌進度還原(漁夫牌第二次 $18 剩 $%d、烤魚攤建地牌已用掉)(buys %d rem %d cost %d visible %s lost %d)" % [fp_rem, fp2.logic.buys, fp2.logic.remaining, fp2.logic.current_cost(), str(fp2.visible), fp2.logic.lost])
    var cashier2 := _find_helper("cashier")
    _check(cashier2 != null and cashier2.assigned_counter != null and is_equal_approx(st2.logic.speed_mult, 1.5), "重建關卡:收銀員指派(八座櫃台裡的一座)、升級套回")
    _check(GameState.weapon_level == weapon_saved and GameState.helpers_lost == lost_saved and _player.weapon_prop != null
            and _find_helper("fisher") != null and absf(_level.bears.cooldown - bear_cd) < 0.5 and fp2.logic.lost == 0
            and absf(GameState.play_time - play_time_saved) < 0.5 and is_equal_approx(_level.bears.king_next_sec, king_next_saved),
            "重建關卡:武器 Lv%d 掛回腰間、買回的漁夫還在、北極熊冷卻 / 遊戲時間 / 王的下次時間還原(fisher %s cd %.1f/%.1f lost %d pt %.1f/%.1f king %.1f/%.1f)" % [weapon_saved, str(_find_helper("fisher") != null), _level.bears.cooldown, bear_cd, fp2.logic.lost, GameState.play_time, play_time_saved, _level.bears.king_next_sec, king_next_saved])
    var tw2: Tower = _level.tower_by_id("tower_1")
    var wp3: PricePad = _level.price_pads["weapon"]
    _check(tw2 != null and tw2.tier == 1 and tw2.is_strong() and is_equal_approx(tw2.hp_max, 2000.0) and GameState.shop_level == 1
            and GameState.weapon_level == 4 and GameState.pelts == pelts_saved and GameState.teeth == 2 and _level.loot.size() == loot_saved
            and wp3.logic.max_buys == 4 and wp3.logic.is_exhausted() and not wp3.visible and _level.shop_sign.text.contains("1")
            and not (_level.price_pads["tooth_tower_1"] as PricePad).visible and not (_level.price_pads["tooth_tower_2"] as PricePad).visible,
            "重建關卡:強力守衛塔、武器店 Lv1(武器牌 4 級買滿)、毛皮 %d、地上 %d 個掉落物還原" % [pelts_saved, loot_saved])
    _check(_level.conveyors.size() == 1 and _level.conveyor_by_id("belt_station_1") != null and not (_level.price_pads["belt_station_1"] as PricePad).visible
            and (_level.price_pads["belt_grill"] as PricePad).visible and not _level.trap_by_id("trap_1").is_armed() and (_level.price_pads["trap_1"] as PricePad).visible
            and not _level.bait_by_id("bait_1").is_set() and (_level.price_pads["bait_1"] as PricePad).visible and GameState.upgrade_level("porter_cap") == 1
            and (_level.price_pads["upgrade_porter_cap"] as PricePad).logic.remaining == 160,
            "重建關卡:傳送帶蓋回來(牌藏著、烤魚攤的傳送帶牌開著)、用掉的捕熊夾 / 誘餌牌開著、搬運工容量 Lv1(帶 %d、帶牌 %s / %s、夾 %s 牌 %s、餌 %s 牌 %s、容量 Lv%d 剩 %d)"
            % [_level.conveyors.size(), str((_level.price_pads["belt_station_1"] as PricePad).visible), str((_level.price_pads["belt_grill"] as PricePad).visible),
            str(_level.trap_by_id("trap_1").is_armed()), str((_level.price_pads["trap_1"] as PricePad).visible), str(_level.bait_by_id("bait_1").is_set()),
            str((_level.price_pads["bait_1"] as PricePad).visible), GameState.upgrade_level("porter_cap"), (_level.price_pads["upgrade_porter_cap"] as PricePad).logic.remaining])
    _check(tower_alive_saved and tw2 != null and tw2.is_alive() and is_equal_approx(tw2.hp, tower_hp_saved) and tw2._built.visible
            and not (_level.price_pads["tower_1"] as PricePad).visible and _level.tower_by_id("tower_2").state == "none"
            and fp2.logic.max_buys == 11 and (_level.price_pads["hire_porter"] as PricePad).logic.max_buys == 18,
            "重建關卡:守衛塔 1 還在(血 %.0f)、沒蓋的還是地基、四次擴建後的僱用名額還原" % tower_hp_saved)
    # 離線收益:把存檔的 savedAt 撥回 3 小時前、收入速率寫成 2 $/s -> 重建關卡時彈面板、遊戲暫停 -> 領取 $10800 進錢包
    _level.save_now()
    _level.set_physics_process(false)   # 關掉自動存檔
    _level.queue_free()
    await _step(3)   # 舊關卡完全釋放後才改檔:它活著時任何事件(購買 / 被吃 / 領取)都會再存一次,把撥回去的 savedAt 蓋掉
    var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.save_path))
    raw["savedAt"] = int(Time.get_unix_time_from_system()) - 3 * 3600
    raw["world"]["income_rate"] = 2.0
    var fw := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
    fw.store_string(JSON.stringify(raw))
    fw.close()
    GameState.reset()
    await _spawn_level()
    var wallet_before := GameState.wallet
    var rate_loaded := _level.offline.rate(GameState.play_time)
    var oc := _level.hud.offline_cash()   # 離線秒數 = 現在 - savedAt,跑測試花掉的幾秒也算進去:10800 ~ 10810
    _check(_level.loaded_from_save and _level.hud.offline_open() and get_tree().paused and oc >= 10800 and oc <= 10810
            and _level.offline_sec >= 3 * 3600 and _level.offline_sec < 3 * 3600 + 120 and absf(rate_loaded - 2.0) < 0.05,
            "離線 3 小時、速率 2 $/s:面板彈出($10800 = 2 × 10800 × 0.5)、遊戲暫停、速率讀回 %.2f(open %s paused %s cash %d sec %d loaded %s)" % [rate_loaded, str(_level.hud.offline_open()), str(get_tree().paused), _level.hud.offline_cash(), _level.offline_sec, str(_level.loaded_from_save)])
    var pt_paused := GameState.play_time
    await _step(5)
    _check(is_equal_approx(GameState.play_time, pt_paused), "暫停時遊戲時間不走")
    _level.hud.offline_action("claim")
    await _step(3)
    _check(not _level.hud.offline_open() and not get_tree().paused and GameState.wallet == wallet_before + oc
            and GameState.offline_earned == oc and GameState.play_time > pt_paused
            and int(SaveManager.read().get("state", {}).get("offline_earned", 0)) == oc,
            "領取:面板關、恢復、錢包 +$%d、統計與存檔都記了" % oc)
    _level.hud.offline_action("claim")
    _check(GameState.wallet == wallet_before + oc, "再按一次不會重複領")
    await _coupon_section()
    # F9 新遊戲
    _level.clear_save_and_state()
    _check(GameState.weapon_level == 0 and GameState.helpers_lost == 0 and GameState.pelts == 0 and GameState.teeth == 0 and GameState.shop_level == 0,
            "新遊戲:武器、被吃數、毛皮 / 熊王牙 / 武器店等級歸零")
    _check(not SaveManager.has_save() and GameState.hired_total() == 0 and GameState.wallet == 0, "新遊戲:刪存檔、清狀態")
    _level.queue_free()
    await _step(2)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(HANDOFF))


## --- 擴建村莊 ---
## 付 $1000(大額牌付得快)-> 東門拆掉、往東多一塊地:第二個水區有魚、第二座切魚台 + 烤魚攤、第二組櫃台有顧客來
func _expand_section() -> void:
    var pad: PricePad = _level.price_pads["expand_village"]
    var stations0 := _level.stations.size()
    var counters0 := _level.counters.size()
    GameState.add_wallet(1000)
    await _go(Vector3(9.0, 0, 2.5))   # 繞開烤魚攤的輸出格,免得順手拿走烤魚
    var t0 := Time.get_ticks_msec()
    var bought := await _pay_pad(pad)
    var pay_sec := float(Time.get_ticks_msec() - t0) / 1000.0
    await _step(3)
    _check(bought and pay_sec < 20.0 and not pad.visible and GameState.is_unlocked("village_2"), "擴建村莊:$1000 在 %.1f 秒內付清(大額牌加速)" % pay_sec)
    _check(_level.is_expanded() and _level.annex != null and _level.east_gate == null and _level.east_gate_mesh == null and _level.east_walls.is_empty()
            and _level.fish_areas.size() == 2 and _level.stations.size() == stations0 + 2 and _level.counters.size() == counters0 + 2
            and _level.station_at("station_3") != null and _level.station_at("grill_2") != null and _level.counter_by_id("fillet_counter_2") != null
            and _level.counter_by_id("grill_counter_2") != null, "東牆整段拆掉、第二個水區、切魚台 + 烤魚攤、兩座櫃台都蓋好")
    var fa2: FishArea = _level.fish_areas[1]
    await _step(30)
    _check(fa2.fish.size() >= 4 and fa2.rect.position.x > 13.0, "第二個水區有魚(%d)" % fa2.fish.size())
    var walked := await _go(Vector3(20.0, 0, 3.0), 600)
    _check(walked and _player.global_position.x > 14.0 and _level.nearest_fish_area(_player.global_position) == fa2, "玩家走得進擴建區;最近的水區是新的那個")
    var c2: Counter = _level.counter_by_id("fillet_counter_2")
    var came := await _wait_until(func() -> bool: return c2.customers.size() >= 1, 400)
    _check(came and c2.logic.item_id == "fillet" and c2.logic.price == 2, "新櫃台也有顧客排隊")
    _check(_level.bears.logic.entries(_level.expansion_level())[1].x > 30.0 and _level.expansion_level() == 1, "擴建後熊的東邊入口在 annex 外")
    var t7p: PricePad = _level.price_pads["tower_7"]
    var ev2: PricePad = _level.price_pads["expand_village_2"]
    _check(t7p.visible and (_level.price_pads["tower_12"] as PricePad).visible and not (_level.price_pads["tower_13"] as PricePad).visible
            and t7p.global_position.x > 13.0 and t7p.global_position.distance_to(_level.tower_by_id("tower_7").global_position) < 0.1
            and ev2.visible and ev2.logic.current_cost() == 2000 and ev2.global_position.x > 13.0 and ev2.global_position.x < 31.6,
            "擴建區的六座塔牌出現(第二塊的還藏著);第二次擴建牌 $2000 在擴建區裡")
    var hf: PricePad = _level.price_pads["hire_fisher"]
    var hpp: PricePad = _level.price_pads["hire_porter"]
    var hc: PricePad = _level.price_pads["hire_cashier"]
    _check(hf.logic.max_buys == 5 and hpp.logic.max_buys == 6 and hc.logic.max_buys == 4 and hf.visible and hpp.visible and hc.visible
            and not hf.logic.is_exhausted() and not hpp.logic.is_exhausted() and not hc.logic.is_exhausted() and hf.label.text.contains("/5")
            and (_level.price_pads["capacity_1"] as PricePad).logic.max_buys == 3,
            "擴建後僱用牌多開放名額:漁夫 5、搬運工 6、收銀員 4(其他牌不變)")

    # 第二次擴建 $2000:牌子在第一塊擴建區裡 -> 第一塊的東牆拆掉、再往東一塊:第三個水區、切魚台 + 烤魚攤、第三組櫃台、僱用牌再開名額、熊入口再往東
    var stations1 := _level.stations.size()
    var counters1 := _level.counters.size()
    GameState.add_wallet(2000)
    await _go(Vector3(29.5, 0, 3.5))
    var bought2 := await _pay_pad(ev2)
    await _step(3)
    _check(bought2 and not ev2.visible and GameState.is_unlocked("village_3") and _level.expansion_level() == 2 and _level.annexes.size() == 2
            and _level.fish_areas.size() == 3 and _level.stations.size() == stations1 + 4 and _level.counters.size() == counters1 + 2
            and _level.station_at("station_4") != null and _level.station_at("grill_3") != null and _level.station_at("grill_4") != null
            and _level.station_at("grill_5") != null and _level.station_at("grill_5").position.x < 50.0 and _level.counter_by_id("fillet_counter_3") != null
            and _level.counter_by_id("grill_counter_3") != null and _level.annex_east_walls[0].is_empty(),
            "第二次擴建:第三個水區、切魚台 + 三座烤魚攤、第三組櫃台,第一塊擴建區的東牆拆掉")
    var walked3 := await _go(Vector3(40.0, 0, 3.0), 600)
    var fa3: FishArea = _level.fish_areas[2]
    await _step(20)
    _check(walked3 and _player.global_position.x > 36.0 and fa3.rect.position.x > 31.0 and fa3.fish.size() >= 3
            and _level.nearest_fish_area(_player.global_position) == fa3, "走得進第二塊擴建區(x 31.6 沒有牆);第三個水區有魚(%d)" % fa3.fish.size())
    var ev3: PricePad = _level.price_pads["expand_village_3"]
    _check((_level.price_pads["tower_13"] as PricePad).visible and (_level.price_pads["tower_18"] as PricePad).visible
            and not (_level.price_pads["tower_19"] as PricePad).visible
            and _level.bears.logic.entries(_level.expansion_level())[1].x > 50.0 and hf.logic.max_buys == 7 and hpp.logic.max_buys == 10
            and hc.logic.max_buys == 6 and hf.label.text.contains("/7") and ev3.visible and ev3.logic.current_cost() == 8000
            and ev3.global_position.x > 31.6 and ev3.global_position.x < 50.2,
            "第二塊的六座塔牌出現(第三塊的還藏著)、熊的東邊入口在第二塊外、僱用名額 7 / 10 / 6;第三次擴建牌 $8000 在第二塊擴建區裡")
    await _third_expansion(ev3, hf, hpp, hc)
    await _go(Vector3(36.4, 0, 5.0), 900)
    await _go(Vector3(20.0, 0, 3.0), 600)
    await _go(Vector3(11.0, 0, 0.5))
    await _go(Vector3(0, 0, 7))


## 第三次擴建 $8000:牌在第二塊擴建區 -> 第二塊的東牆拆掉、第四個水區、兩座烤魚攤 + 服飾店 + 毛衣櫃台、僱用名額再開、第三塊的塔牌;
## 玩家把 10 張毛皮放進服飾店(站滿 0.8 秒才開始放)-> 工人 5 張做一件毛衣 -> 毛衣到毛衣櫃台賣 $200
func _third_expansion(ev3: PricePad, hf: PricePad, hpp: PricePad, hc: PricePad) -> void:
    var stations2 := _level.stations.size()
    var counters2 := _level.counters.size()
    GameState.add_wallet(8000)
    await _go(Vector3(40.9, 0, 7.0), 600)
    var t0 := Time.get_ticks_msec()
    var bought3 := await _pay_pad(ev3)
    var pay_sec := float(Time.get_ticks_msec() - t0) / 1000.0
    await _step(3)
    var tailor := _level.station_at("tailor")
    var sc: Counter = _level.counter_by_id("sweater_counter")
    _check(bought3 and pay_sec < 20.0 and not ev3.visible and GameState.is_unlocked("village_4") and _level.expansion_level() == 3
            and _level.annexes.size() == 3 and _level.fish_areas.size() == 4,
            "第三次擴建:$8000 在 %.1f 秒內付清;第三塊擴建區、第四個水區(買成 %s、等級 %d、水區 %d)" % [pay_sec, str(bought3), _level.expansion_level(), _level.fish_areas.size()])
    _check(_level.stations.size() == stations2 + 3 and _level.counters.size() == counters2 + 1 and _level.station_at("grill_6") != null
            and _level.station_at("grill_7") != null and tailor != null and tailor.logic.input_id == "pelt" and tailor.logic.output_id == "sweater"
            and tailor.logic.input_per == 5, "第三塊:兩座烤魚攤 + 服飾店(毛皮 -> 毛衣,一批 5 張)(工作站 %d / %d、櫃台 %d / %d)"
            % [_level.stations.size(), stations2 + 3, _level.counters.size(), counters2 + 1])
    _check(sc != null and sc.logic.item_id == "sweater" and sc.logic.price == 200 and sc.want_weights.size() == 1 and int(sc.want_weights[0]) == 1
            and CounterLogic.roll_want(sc.want_weights, 0.99) == 1, "毛衣櫃台 $200、顧客一次只買一件(權重 %s)" % str(sc.want_weights))
    _check(_level.annex_east_walls[1].is_empty() and not _level.annex_east_walls[2].is_empty(), "第二塊的東牆拆掉、第三塊的東牆還在")
    _check((_level.price_pads["tower_19"] as PricePad).visible and (_level.price_pads["tower_24"] as PricePad).visible
            and (_level.price_pads["tower_24"] as PricePad).global_position.x > 60.0
            and _level.bears.logic.entries(_level.expansion_level())[1].x > 70.0 and hf.logic.max_buys == 9 and hpp.logic.max_buys == 14
            and hc.logic.max_buys == 8 and hf.label.text.contains("/9"), "第三塊的六座塔牌出現、熊的東邊入口在第三塊外、僱用名額 9 / 14 / 8")
    # 毛皮放進服飾店:走過輸入格不會放(要站滿 0.8 秒),站著才一張張放
    GameState.pelts = 0   # 先前撿到的毛皮清掉,才能剛好做兩件
    GameState.add_resource("pelt", 10)
    var pelts0 := GameState.pelts
    await _go(Vector3(67.5, 0, 5.0), 900)
    await _go(Vector3(67.5, 0, -2.2), 600)
    var in_pad := tailor.input_pad.global_position
    await _go(Vector3(62.0, 0, -2.2), 600)   # 全速穿過輸入格(x 63.5 ~ 65.5,0.43 秒)
    _check(GameState.pelts == pelts0 and tailor.logic.input_count == 0, "帶著毛皮走過服飾店輸入格:不會放(要站滿 0.8 秒)")
    await _go(in_pad, 300)
    var fed := await _wait_until(func() -> bool: return tailor.logic.input_count >= 10, 300)
    _check(fed and GameState.pelts == pelts0 - 10 and tailor.logic.input_count == 10, "站在輸入格:10 張毛皮從資源扣進服飾店(毛皮 %d)" % GameState.pelts)
    var pt0 := _count("processed_tailor")
    var made := await _wait_until(func() -> bool: return _count("processed_tailor") >= pt0 + 2, 900)
    _check(made and tailor.logic.input_count == 0, "工人 5 張毛皮做一件毛衣:10 張做了 2 件(成品 %d、櫃台 %d、手上 %d)"
            % [tailor.logic.output_count, sc.logic.stock, _carried("sweater")])
    # 自己(或搬運工)把毛衣送到毛衣櫃台,站到收銀格賣 $200
    if not _player.stack.is_empty() and _player.stack.item_id != "sweater":
        print("  (玩家背上有 %s ×%d,先清掉再去拿毛衣)" % [_player.stack.item_id, _player.stack.count])
        _player.stack.clear()
    if tailor.logic.output_count > 0:
        await _go(tailor.output_pad.global_position, 300)
        await _wait_until(func() -> bool: return tailor.logic.output_count == 0, 120)
    if _carried("sweater") > 0:
        await _go(sc.deposit_pad.global_position + Vector3(0, 0, 0.0), 600)
        await _wait_until(func() -> bool: return _carried("sweater") == 0, 120)
    var stocked := await _wait_until(func() -> bool: return sc.logic.stock >= 1, 600)
    var cash0 := _level.money_pad.cash
    var sales0 := _sales.size()
    await _go(sc.service_pad.global_position, 600)
    var sold := await _wait_until(func() -> bool: return not _sale_after(sales0, "sweater").is_empty(), 900)
    var sale := _sale_after(sales0, "sweater")
    _check(stocked and sold and int(sale[1]) == 1 and int(sale[2]) == 200 and _level.money_pad.cash >= cash0 + 200,
            "毛衣上架、顧客一次買一件 $200(錢格 %d -> %d;上架 %s、庫存 %d、手上 %s ×%d、成品 %d、顧客 %d、收銀員 %s、拿貨 %s、玩家 (%.1f, %.1f))"
            % [cash0, _level.money_pad.cash, str(stocked), sc.logic.stock, _player.stack.item_id, _player.stack.count, tailor.logic.output_count,
            sc.customers.size(), str(sc.cashier != null), str(_player.takes_output), _player.global_position.x, _player.global_position.z])
    await _go(Vector3(59.5, 0, 5.0), 600)


## --- 北極熊王 ---
## 把遊戲時間撥到 5 分鐘 -> 王出場(更大、血量 ×4)-> 盯上水裡的魚吃掉:回血、變大 -> 玩家用 Lv3 武器打到血條歸零 -> 王倒下、下一次在 5 分鐘後
func _king_section() -> void:
    var bs: BearSpawner = _level.bears
    var fa: FishArea = _level.fish_areas[0]
    var fish0 := fa.fish.size()
    var t_before := GameState.play_time
    var t1: Tower = _level.tower_by_id("tower_1")
    var t1_alive := t1.is_alive()
    if t1_alive:
        t1.state = "none"   # 王吃魚會繞到西北角順手把塔拆了;這段先把塔收起來(存檔檢查要看它)
        t1._apply_state()
    # 來襲預告:王出場前 45 秒 HUD 倒數、一般熊不來(冷卻擺 0.1 也不生)
    GameState.play_time = bs.logic.king_at_sec() - 40.0
    bs.cooldown = 0.1
    bs.enabled = true
    await _step(8)
    _check(bs.king_warning_active() and bs.king_warning_left() >= 38 and bs.king_warning_left() <= 41 and not bs.has_king() and not bs.has_pack()
            and _level.hud.warning_text().contains(str(bs.king_warning_left())) or _level.hud.warning_text() != "",
            "王來襲預告:倒數 %d 秒、HUD 紅字、一般熊群暫停(冷卻 0.1 也沒生)" % bs.king_warning_left())
    _check(not bs.has_pack() and bs.king_warning_active(), "預告期間一般熊沒來")
    GameState.play_time = bs.logic.king_at_sec() + 1.0
    bs.cooldown = 999.0   # 這段只看王,一般熊先不要來
    await _step(3)
    var king := bs.king
    _check(not bs.king_warning_active() and _level.hud.warning_text() == "" and king != null and king.king_level == 0 and GameState.king_level == 0,
            "王出場:預告消失、第一隻是 Lv0")
    _check(king != null and bs.has_king() and king.is_king and bs.kings_total == 1 and bs.king_next_sec == INF
            and king.size_scale > 1.5 and absf(king.hp_max - bs.logic.hp(GameState.play_time) * bs.logic.king_hp_mult()) < 2.0,
            "5 分鐘:北極熊王出場(體型 %.1f、血 %.0f)" % [king.size_scale if king != null else 0.0, king.hp_max if king != null else 0.0])
    if king == null:
        bs.enabled = false
        GameState.play_time = t_before
        return
    # 漁夫先調到擴建區的水,免得王順手把牠吃了(後面的存檔檢查要看漁夫)
    var fisher := _find_helper("fisher")
    if fisher != null:
        fisher.fish_area = _level.fish_areas[1]
        fisher.global_position = Vector3(22.3, 0, -7.0)   # 從交接存檔重生的漁夫還在出生點,直接傳到擴建區水裡,王才不會順手吃掉牠
        fisher.set_physics_process(false)   # 這段先定住(牠抓滿魚會走回主村卸貨,正好撞上王);段落結束再放開
        fisher.global_position = Vector3(22.0, 0, -7.0)
        fisher.state = "idle"
    # 先把王丟進水邊、血扣一半,看牠吃魚回血變大(玩家站遠一點不要打牠)
    await _go(Vector3(0, 0, 9))
    king.hp = king.hp_max * 0.5
    king.global_position = Vector3(0, 0, -5.0)
    var nearest_fish: Fish = null   # 直接盯最近的魚(王現在也會盯建築,別讓牠先跑去拆切魚台)
    for f in fa.fish:
        if nearest_fish == null or f.global_position.distance_to(king.global_position) < nearest_fish.global_position.distance_to(king.global_position):
            nearest_fish = f
    king.target = nearest_fish
    king.state = "hunting"
    var hp_before := king.hp
    var scale_before := king.size_scale
    var ate := await _wait_until(func() -> bool: return _count("fish_eaten") >= 1, 600)
    await _step(2)
    _check(ate and _count("bear_fed") >= 1 and absf(king.hp_ratio() - 0.5) < 0.01 and king.size_scale > scale_before and fish0 > 0,
            "王吃掉水裡的魚:不回血(血條還是 %.0f%%)、只變大(%.2f -> %.2f)" % [king.hp_ratio() * 100.0, scale_before, king.size_scale])
    # 王也會盯幫手:把搬運工放到牠旁邊,咬 2.5 秒吃掉 -> 不回血、變更大(後面的存檔檢查不看搬運工)
    var porter := _find_helper("porter")
    var helpers0 := _level.helpers.size()
    if porter != null:
        king.hp = king.hp_max * 0.3
        king.target = porter
        king.state = "hunting"
        porter.global_position = king.global_position + Vector3(1.0, 0, 0)
        var scale2 := king.size_scale
        var eaten := await _wait_until(func() -> bool: return not is_instance_valid(porter) or porter.eaten, 600)
        await _step(2)
        _check(eaten and _level.helpers.size() == helpers0 - 1 and absf(king.hp_ratio() - 0.3) < 0.01 and king.size_scale > scale2
                and (_level.price_pads["hire_porter"] as PricePad).logic.is_rebuy(), "王吃掉搬運工:不回血(血條 %.0f%%)、體型 %.2f -> %.2f、搬運工牌可買回" % [king.hp_ratio() * 100.0, scale2, king.size_scale])
    await _king_wreck_section(king)
    # 打死王
    king.hp = minf(king.hp, 35.0 * 4.0)   # 測試不想打幾十下:留四下的血(牠在水邊還會邊吃魚邊回血,所以實際會多幾下)
    var hp_left := king.hp
    await _chase_bear(king, 1200)
    # 王倒在玩家腳邊,寶箱掉下來通常立刻被踩到打開(三選一面板、遊戲暫停);沒踩到就走過去
    var down := await _wait_until(func() -> bool: return _level.hud.choice_open() or not bs.has_king(), 900)
    _check(down and _count("bear_defeated") >= 1 and (not is_instance_valid(king) or not king.alive()) and bs.kings_total == 1,
            "王被打到血條歸零(剩 %.0f 血)倒下(狀態 %s)" % [hp_left, (king.state + "/hp %.0f" % king.hp) if is_instance_valid(king) else "freed"])
    var teeth0 := GameState.teeth
    if not _level.hud.choice_open():
        var chest: Loot = null
        for l in _level.loot:
            if l.kind == "chest":
                chest = l
        _check(chest != null and int(chest.data.get("teeth", 0)) == 3, "打死王掉下寶箱(走過去開)")
        if chest != null:
            await _go(chest.global_position)
            await _step(3)
    var pc: Dictionary = _level.pending_chest.duplicate(true)
    _check(_level.hud.choice_open() and _level.hud.choice_count() == 3 and get_tree().paused and GameState.teeth == 3 and teeth0 <= 3
            and int(pc.get("teeth", 0)) == 3 and pc.get("cards", []).size() == 3 and GameState.king_level == 1 and GameState.king_kills == 1
            and _level.trophies.get_child_count() == 2,
            "寶箱打開:保底 3 顆牙、三選一面板、遊戲暫停;王 Lv1、擊殺 1、戰利品牆一顆頭骨(表現 %s ×%.1f)" % [str(pc.get("grade", "")), float(pc.get("mult", 0.0))])
    _check(str(pc.get("grade", "")) == "normal" and is_equal_approx(float(pc.get("mult", 0.0)), 1.0) and int(pc.get("streak", -1)) == 0,
            "這隻王吃了搬運工、拆了切魚台:表現 normal ×1.0、連勝 0")
    var wallet_c := GameState.wallet
    var cash_card := int(pc["cards"][0]["amount"]) if pc.has("cards") else 0
    var pelts_c := GameState.pelts
    _level.hud.choice_action(0)
    await _step(3)
    _check(not _level.hud.choice_open() and not get_tree().paused and GameState.wallet == wallet_c + cash_card and cash_card >= 100
            and _level.pending_chest.is_empty() and _count("chest_claimed") == 1, "選現金卡:錢包 +$%d、恢復" % cash_card)
    _level.hud.choice_action(1)
    _check(GameState.pelts == pelts_c, "面板關了再按不會重複拿")
    var gone := await _wait_until(func() -> bool: return not bs.has_king(), 900)
    _check(gone and not is_instance_valid(king) and bs.king_next_sec >= GameState.play_time + bs.logic.king_respawn_sec() - 5.0 and bs.king_next_sec < INF,
            "王逃走消失,下一隻 %.0f 秒後" % (bs.king_next_sec - GameState.play_time))
    _check(str(_level.hud.objective_text()) != "" and _level.hud.stats_text().contains(":") and _level.hud._info.text.contains("Lv"), "HUD:左上只剩資源 / 武器,統計收進選單(有遊戲時間)")
    if t1_alive:
        t1.restore({"state": "alive", "hp": t1.hp_max})
    bs.enabled = false
    if fisher != null and is_instance_valid(fisher):
        fisher.set_physics_process(true)
    await _go(Vector3(0, 0, 7))


## 打死王掉下熊王牙 -> 撿起來 -> 完好的 tower_1 底下有熊王牙牌(沒蓋的塔沒有)-> 站上去付 1 顆 -> 強力守衛塔:血 2000、每箭 25
func _tower_strong_section() -> void:
    var t1: Tower = _level.tower_by_id("tower_1")
    var tp: PricePad = _level.price_pads["tooth_tower_1"]
    var tp2: PricePad = _level.price_pads["tooth_tower_2"]
    _check(GameState.teeth == 3 and t1.is_alive() and t1.tier == 0 and tp.visible and not tp.logic.is_exhausted() and tp.logic.currency == "tooth"
            and tp.logic.remaining == 1 and tp.label.text.contains(tr("COST_tooth") % 1) and not tp2.visible,
            "撿到熊王牙;完好的守衛塔底下有強化牌(收 1 顆),沒蓋的塔沒有")
    await _go(Vector3(-11.6, 0, 7.0))
    await _go(Vector3(-11.6, 0, -6.0))
    var paid := await _pay_pad(tp)
    await _step(3)
    _check(paid and GameState.teeth == 2 and t1.tier == 1 and t1.is_strong() and is_equal_approx(t1.hp_max, 2000.0) and is_equal_approx(t1.hp, 2000.0)
            and not tp.visible and tp.logic.is_exhausted() and _count("tower_upgraded") == 1 and t1._strong_band.visible
            and t1.logic.bites_to_break(t1.tier) == 50 and is_equal_approx(t1.logic.damage(t1.tier), 25.0),
            "1 顆熊王牙強化守衛塔:血 2000(扛 50 口)、每箭 25、金色塔環、牌消失")
    await _go(Vector3(-11.6, 0, -6.0))
    await _go(Vector3(-11.6, 0, 7.0))
    await _go(Vector3(0, 0, 7))


## 券:保險券(被吃的幫手名額不扣、10 秒後自己回來)、平靜券(一般熊 120 秒不來、存檔記剩餘秒數)、免費升級券(站上升級牌直接付清不扣錢)、
## 嚇熊圖騰(插了的那塊地入口不選)、冰封夾解鎖
func _coupon_section() -> void:
    var bs: BearSpawner = _level.bears
    bs.enabled = false
    var fisher := _find_helper("fisher")
    if fisher == null:
        fisher = _level.spawn_helper("fisher", true)
        GameState.hired["fisher"] = GameState.hired_count("fisher") + 1
    var hired0 := GameState.hired_count("fisher")
    var helpers0 := _level.helpers.size()
    var fp: PricePad = _level.price_pads["hire_fisher"]
    var fp_rem := fp.logic.remaining
    GameState.add_coupon("insurance", 1)
    var b := bs.spawn(fisher)
    b.set_physics_process(false)
    _level.helper_eaten(fisher, b)
    await _step(3)
    _check(GameState.coupon("insurance") == 0 and GameState.hired_count("fisher") == hired0 and _level.helpers.size() == helpers0 - 1
            and fp.logic.remaining == fp_rem and _count("helper_insured") == 1, "保險券:漁夫被吃但名額不扣、牌不漲、券用掉")
    var came_back := await _wait_until(func() -> bool: return _level.helpers.size() == helpers0, 60 * 12)
    _check(came_back and _find_helper("fisher") != null, "10 秒後漁夫自己回來")
    b.queue_free()
    await _step(2)
    bs.bears.clear()
    # 平靜券
    bs.calm(bs.king_logic.calm_sec())
    _check(bs.calm_left() > 119.0 and bs.calm_left() <= 120.0 and absf(float(bs.snapshot().get("calmLeft", 0.0)) - bs.calm_left()) < 0.5, "平靜券:120 秒內一般熊不來、快照記剩餘秒數")
    bs.calm_until = -1.0
    # 免費升級券:站上工人速度牌(第二級 $34)直接付清
    var up: PricePad = _level.price_pads["upgrade_worker_speed"]
    var lv0 := GameState.upgrade_level("worker_speed")
    var wallet0 := GameState.wallet
    GameState.add_coupon("upgrade", 1)
    await _go(up.global_position)
    var free := await _wait_until(func() -> bool: return GameState.upgrade_level("worker_speed") == lv0 + 1, 120)
    _check(free and GameState.coupon("upgrade") == 0 and GameState.wallet == wallet0 and _count("purchased_upgrade_worker_speed") >= 1,
            "免費升級券:工人速度 Lv%d -> Lv%d、錢包沒扣、券用掉" % [lv0, lv0 + 1])
    await _go(Vector3(0, 0, 7))
    # 冰封夾
    GameState.apply_purchase("altar_ice", {"type": "unlock", "target": "ice_traps"})
    var trap := _level.trap_by_id("trap_2")
    trap.arm()
    var b2 := bs.spawn()
    b2.set_physics_process(false)
    b2.hp = b2.hp_max
    var hp0 := b2.hp
    trap.trigger(b2)
    _check(GameState.is_unlocked("ice_traps") and absf(hp0 - b2.hp - 150.0) < 0.01 or (hp0 - 150.0 <= 0.0 and not b2.alive()), "冰封夾:夾到扣 150(一般夾 60)")
    b2.queue_free()
    await _step(2)
    bs.bears.clear()


## 王拆建築:把牠放到第二座切魚台旁邊盯著咬,10 秒就拆掉 -> 廢墟、工人不見、格子停用、搬運工 / 漁夫不再送去、修復牌出現 $200;
## 站上廢墟付清修好 -> 桌子回來、牌消失。存檔快照記 broken。
func _king_wreck_section(king: Bear) -> void:
    var st1 := _level.station_at("station_1")
    var rp: PricePad = _level.price_pads.get("repair_station_1", null)
    if st1 == null or rp == null:
        _check(false, "找不到 station_1 或它的修復牌")
        return
    var bite_sec: float = king.logic.king_building_bite_sec()
    _check(not rp.visible and rp.logic.is_exhausted() and rp.global_position.distance_to(st1.global_position) < 0.1 and not st1.is_broken()
            and st1._built.visible and not st1._rubble.visible, "切魚台完好:修復牌藏著")
    await _go(Vector3(0, 0, 9))
    king.global_position = Vector3(-6, 0, -4.0)
    king.target = st1
    king.state = "hunting"
    var t0 := GameState.play_time
    var biting := await _wait_until(func() -> bool: return king.state == "biting" and king.target == st1, 300)
    var wrecked := await _wait_until(func() -> bool: return st1.is_broken(), int(bite_sec * 60.0) + 240)
    var took := GameState.play_time - t0
    await _step(3)
    var dests_ok := true
    for d in _level.porter_dests():
        if d.get("node", null) == st1:
            dests_ok = false
    for s in _level.porter_sources():
        if s.get("node", null) == st1:
            dests_ok = false
    _check(biting and wrecked and took >= bite_sec - 0.5 and king.buildings_broken == 1 and _count("station_destroyed") == 1
            and not st1._built.visible and st1._rubble.visible and not st1.logic.is_working() and not st1.input_pad.monitoring
            and not st1.output_pad.monitoring and not st1.input_pad.visible,
            "王盯著切魚台咬 %.1f 秒(規則 %.0f 秒)就拆掉:廢墟、工人不見、格子停用" % [took, bite_sec])
    _check(dests_ok and _level.find_station_accepting("fish") != st1 and _level.find_station_with_input("fish") != st1
            and _level.find_station_with_output("fillet") != st1, "被拆的切魚台不再是搬運工 / 漁夫的目的地或來源")
    _check(rp.visible and rp.logic.is_rebuy() and rp.logic.buys == 0 and rp.logic.lost == 1 and rp.logic.remaining == 100
            and rp.label.text.contains(tr("PAD_REPAIR")) and rp.label.text.contains(tr("STATION_cutting_table")) and not rp.label.text.contains("×")
            and bool(_level.snapshot()["stations"]["station_1"].get("broken", false)), "廢墟上出現修復牌 $200(存檔記 broken)")
    # 王先定住、挪遠一點,玩家去修
    king.set_physics_process(false)
    king.target = null
    king.state = "hunting"
    king.global_position = Vector3(-6, 0, -7.0)
    GameState.add_wallet(200)
    rp.logic.pay(80)   # 測試時間預算:先付 80
    rp._update_label()
    var repaired := await _pay_pad(rp)
    await _step(3)
    _check(repaired and not st1.is_broken() and st1._built.visible and not st1._rubble.visible and st1.input_pad.monitoring and st1.output_pad.monitoring
            and not rp.visible and rp.logic.is_exhausted() and rp.logic.lost == 0 and _count("station_repaired") == 1 and st1.times_broken == 1
            and st1.times_repaired == 1 and not bool(_level.snapshot()["stations"]["station_1"].get("broken", true)),
            "花 $200 修好:切魚台回來、牌消失、存檔不再記 broken")
    await _go(Vector3(0, 0, 9))
    await _empty_hands()
    king.set_physics_process(true)



## --- 第四次擴建(往南):魚湯廚房 ---
## $20000 的牌在主村南牆邊 -> 拆南牆、南塊沙地與柵欄、廚房(兩個輸入格)、魚湯櫃台、塔 25 / 26 的牌、僱用名額再開、熊多一個南入口 ->
## 廚房要魚片 + 烤魚各一才做湯(只有一種不做)-> 做出魚湯 -> 玩家送到魚湯櫃台 -> 顧客以 $15 買走
func _south_section() -> void:
    var pad: PricePad = _level.price_pads["expand_village_4"]
    var hf: PricePad = _level.price_pads["hire_fisher"]
    var hp: PricePad = _level.price_pads["hire_porter"]
    var max0 := hf.logic.max_buys
    _check(pad.visible and pad.logic.current_cost() == 20000 and not _level.has_south_block() and _level.south_walls.size() >= 3
            and _level.tower_by_id("tower_25") != null and not (_level.price_pads["tower_25"] as PricePad).visible,
            "第三次擴建後主村南牆邊出現 $20000 的牌;南塊還沒有、塔 25 的牌藏著")
    GameState.add_wallet(20000)
    await _go(Vector3(-6.5, 0, 9.0))
    var bought := await _pay_pad(pad)
    await _step(5)
    var kitchen := _level.station_at("kitchen")
    var sc := _level.counter_by_id("soup_counter")
    _check(bought and _level.has_south_block() and _level.expansion_level() == 4 and _level.south_walls.is_empty() and kitchen != null and sc != null
            and sc.logic.price == 15 and (_level.price_pads["tower_25"] as PricePad).visible and (_level.price_pads["tower_26"] as PricePad).visible
            and hf.logic.max_buys == max0 + 2 and hp.logic.max_buys == 18 and _level.bears.logic.entries(4).size() == 3
            and _level.is_inside_village(Vector3(0, 0, 25)) and not pad.visible,
            "付清 $20000:南塊蓋好(南牆拆掉)、廚房 + 魚湯櫃台 $15、塔 25 / 26 的牌出現、僱用名額 %d / %d、熊多一個南入口" % [hf.logic.max_buys, hp.logic.max_buys])
    _check(kitchen.logic.is_multi_input() and kitchen.input_pads.size() == 2 and kitchen.input_pad_for("grilled") != kitchen.input_pad_for("fillet")
            and (_level.price_pads["belt_kitchen"] as PricePad).visible, "廚房兩個輸入格(魚片 / 烤魚)、傳送帶牌出現")
    # 只放魚片不做;再放烤魚就做(5 秒一碗)
    kitchen.logic.add_input_of("fillet", 3)
    kitchen.refresh_piles()
    await _step(90)
    _check(kitchen.logic.output_count == 0 and not kitchen.logic.is_working() and kitchen.logic.missing_input() == "grilled", "廚房只有魚片:不做,缺烤魚")
    kitchen.logic.add_input_of("grilled", 2)
    kitchen.refresh_piles()
    var made := await _wait_until(func() -> bool: return kitchen.logic.output_count >= 1, 60 * 8)
    _check(made and kitchen.logic.input_count_of("fillet") <= 2 and kitchen.logic.input_count_of("grilled") <= 1 and kitchen.input_pile.visible_count() == kitchen.logic.input_count_of("fillet"),
            "加了烤魚:做出魚湯 %d 碗,魚片 / 烤魚各扣一個" % kitchen.logic.output_count)
    # 玩家送湯去櫃台、自己收銀 -> 顧客 $15 買走
    await _empty_hands()
    await _go(kitchen.output_pad.global_position)
    var took := await _wait_until(func() -> bool: return _player.stack.item_id == "soup" and _player.stack.count >= 1, 240)
    var sales0 := _sales.size()   # 收銀員可能已經被派到魚湯櫃台,一上架就賣掉:先記再上架
    await _go(sc.deposit_pad.global_position)
    var stocked := await _wait_until(func() -> bool: return sc.logic.stock >= 1 or _sale_after(sales0, "soup").size() > 0, 240)
    await _go(sc.service_pad.global_position)
    var sold := await _wait_until(func() -> bool: return _sale_after(sales0, "soup").size() > 0, 900)
    var rec := _sale_after(sales0, "soup")
    _check(took and stocked and sold and not rec.is_empty() and int(rec[2]) == 15 * int(rec[1]), "魚湯上架、顧客以 $15 買走(%s;took %s stocked %s sold %s stock %d customers %d door %s)" % [str(rec), str(took), str(stocked), str(sold), sc.logic.stock, sc.customers.size(), str(sc.spawn_point())])
    await _empty_hands()
    await _go(Vector3(0, 0, 7))
