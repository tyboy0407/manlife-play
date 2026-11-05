extends Node
## 全域事件匯流排(Autoload:EventBus):世界物件發事件,HUD / 關卡 / 統計各自訂閱,彼此不直接相依。

signal fish_caught(carrier: Node3D)
signal items_processed(station_id: String, count: int)
signal sale_made(item_id: String, count: int, cash: int)
signal cash_collected(carrier: Node3D, amount: int)
signal purchase_progress(id: String, remaining: int)
signal purchased(id: String, effect: Dictionary)
signal helper_hired(role: String, helper: Node3D)
signal notice(text: String)
## 東西從 from 移到 to(世界座標):kind = catch / to_station / from_station / to_counter / sold / cash / pay / trash / return。
## 規則層瞬間完成交易後發,飛行動畫(Fx)、音效(Sfx)、HUD 只聽這個演出來。
signal items_moved(kind: String, item_id: String, from: Vector3, to: Vector3, count: int)
signal tutorial_step_done(step: int)
signal tutorial_finished
## 北極熊:出現 / 開始咬某個幫手 / 被玩家打一下(剩多少血)/ 血條歸零被打跑 / 走了(reason = fled 被打跑、no_prey 沒人可吃)/
## 吃掉幫手 / 王吃掉魚 / 王吃東西回血變大
signal bear_appeared(bear: Node3D)
signal bear_biting(helper: Node3D)
signal bear_hit(bear: Node3D, damage: float, hp_left: float)
signal bear_defeated(bear: Node3D, by: Node3D)
signal bear_left(reason: String)
signal helper_eaten(role: String, helper: Node3D)
signal fish_eaten(bear: Node3D)
signal bear_fed(bear: Node3D)
## 守衛塔:蓋好(含修好)/ 射出一箭 / 被熊咬(剩多少血)/ 被熊拆了
signal tower_built(tower: Node3D)
signal tower_shot(tower: Node3D, bear: Node3D)
signal tower_damaged(tower: Node3D, hp_left: float)
signal tower_destroyed(tower: Node3D, by: Node3D)
signal station_destroyed(station: Node3D, by: Node3D)   # 北極熊王拆掉工作站
signal station_repaired(station: Node3D)
signal loot_dropped(kind: String, pos: Vector3)        # 熊被打跑掉落毛皮 / 王掉落牙齒
signal loot_collected(kind: String, total: int)
signal shop_upgraded(level: int)                        # 武器店升級
signal tower_upgraded(tower: Node3D)                    # 守衛塔強化
signal trap_triggered(trap: Node3D, bear: Node3D)       # 捕熊夾夾到熊
signal bait_eaten(bait: Node3D, bear: Node3D)           # 誘餌被熊吃光
signal conveyor_built(conveyor: Node3D)                 # 傳送帶蓋好
signal offline_claimed(cash: int, offline_sec: int)     # 領取離線收益
signal king_warning(sec_left: int)                      # 北極熊王來襲倒數(每秒)
signal chest_opened(reward: Dictionary)                 # 熊王寶箱打開(三選一面板)
signal chest_claimed(card: Dictionary)                  # 選了哪張卡
signal king_leveled(level: int)                         # 王升級
signal helper_insured(role: String)                     # 保險券:被吃的幫手會回來
signal order_posted(order: Dictionary)                 # 碼頭貼了新訂單
signal order_delivered(item: String, count: int)        # 送了幾件到碼頭
signal order_completed(reward: Dictionary)              # 訂單送齊(現金 + 附贈)
signal order_expired                                    # 訂單逾時
signal rare_fish_spawned(fish: Node3D)                  # 水裡出現稀有魚
signal rare_fish_caught(total: int)                     # 抓到稀有魚(累計)
signal building_repaired(building: Node3D, by: Node3D)  # 修理工修好建築
signal map_piece_bought(pieces: int)                    # 旅行商人:地圖碎片
signal chapter_started(id: String)                      # 故事:章節解鎖(HUD 彈短文)
signal journal_unlocked(id: String)                     # 故事:日誌新增一條
signal npc_spoke(npc: String, key: String)              # 故事:NPC 冒了一句泡泡
signal shrine_offered                                   # 故事:神龕付清(結局)
