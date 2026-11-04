extends Node
## HUD 版面 headless 驗證:選單鈕與面板都要貼在畫面右上角、不超出視窗;面板裡的按鈕在面板內;搖桿排除區涵蓋它們。
## 跑法:godot --headless --path . res://tests/verify_ui.tscn(先 --import)

var _fails := 0


func _check(cond: bool, label: String) -> void:
    if cond:
        print("  OK   %s" % label)
    else:
        _fails += 1
        print("  FAIL %s" % label)


func _ready() -> void:
    print("VERIFY UI: begin")
    var hud := Hud.new()
    add_child(hud)
    await get_tree().process_frame
    await get_tree().process_frame
    var vp := get_viewport().get_visible_rect().size
    var btn := hud.menu_button.get_global_rect()
    _check(absf(btn.end.x - (vp.x - 14.0)) < 1.0 and btn.position.y >= 10.0 and btn.size.x >= 70.0,
            "選單鈕貼右上角、留 14 邊距(鈕 %s,視窗 %s)" % [str(btn), str(vp)])
    hud.menu_action("toggle")
    await get_tree().process_frame
    await get_tree().process_frame
    var panel := hud.menu_panel.get_global_rect()
    _check(hud.menu_panel.visible and absf(panel.end.x - (vp.x - 14.0)) < 1.0 and panel.position.x > 0.0 and panel.size.x >= 236.0
            and panel.size.y >= 200.0, "選單面板貼右上角、不超出視窗(面板 %s,最小 %s)" % [str(panel), str(hud.menu_panel.get_combined_minimum_size())])
    var inside := true
    var detail := ""
    for b in hud.menu_panel.get_child(0).get_children():
        var r: Rect2 = (b as Control).get_global_rect()
        if r.end.x > vp.x - 14.0 + 0.5 or r.position.x < panel.position.x - 0.5:
            inside = false
            detail += " %s" % str(r)
    _check(inside, "面板裡的按鈕都在面板內%s" % detail)
    _check(hud.joystick.is_excluded(btn.get_center()) and hud.joystick.is_excluded(panel.get_center())
            and not hud.joystick.is_excluded(Vector2(vp.x * 0.5, vp.y * 0.8)), "搖桿排除區涵蓋選單鈕與面板,畫面中下不算")
    hud.menu_action("close")
    _check(not hud.menu_panel.visible, "關閉面板")
    # 統計分三頁、三選一卡片面板
    _check(hud.stats_tab_count() == 3 and hud.stats_text().count("\n") >= 6, "統計分三頁(經濟 / 幫手與熊 / 王與券),合起來至少 7 行")
    hud.show_choice("T", "B", [{"title": "A", "desc": "a", "color": Color.RED}, {"title": "B", "desc": "b", "color": Color.BLUE}])
    await get_tree().process_frame
    _check(hud.choice_open() and hud.choice_count() == 2 and hud.choice_title(0) == "A" and hud.choice_title(1) == "B", "三選一面板:兩張卡片、標題正確")
    hud.choice_action(1)
    _check(not hud.choice_open(), "選了卡片面板就關")
    # 通知排隊:一秒內連來三則不互相蓋掉;同一類(撿毛皮累計)只更新數字
    hud.show_notice("You beat the polar bear!")
    hud.show_notice("Picked up a polar bear pelt (1 total)")
    hud.show_notice("Picked up a polar bear pelt (2 total)")
    hud.show_notice("Hire a fisher unlocked!")
    _check(hud.notice_text() == "You beat the polar bear!" and hud.queued_notices() == 2, "第一則還在顯示:後面的排隊(同類毛皮只留一則)")
    hud._process(1.0)   # headless 的幀率不固定,直接餵時間
    _check(hud.notice_text() == "Picked up a polar bear pelt (2 total)" and hud.queued_notices() == 1, "1 秒後換下一則(毛皮累計 2)")
    hud._process(1.0)
    _check(hud.notice_text() == "Hire a fisher unlocked!" and hud.queued_notices() == 0, "再 1 秒換最後一則")
    hud.free()
    if _fails == 0:
        print("VERIFY UI: ALL OK")
    else:
        print("VERIFY UI: %d FAILURES" % _fails)
    Sfx.stop_all()
    for i in 30:
        await get_tree().physics_frame
    get_tree().quit(1 if _fails > 0 else 0)
