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
