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
