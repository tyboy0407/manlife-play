# ManLife

休閒閒置經營原型(Godot 4.7、GDScript、3D 方塊占位):雪地漁市。開發約定見 `CLAUDE.md`。

## 快速開始

- 用 Godot 4.7 開啟本資料夾,按 F5 進入星港漁市(`game/levels/harbor.tscn`)。
- 操作:WASD / 方向鍵 / 手把左搖桿移動,沒有其他按鍵。
- 循環:走進上方淺水區碰到魚就抓(疊在背上,8 條滿)→ 站到切魚台左邊「放這裡」格卸貨 → 工人切成魚片 → 站到右邊「從這裡拿」格取魚片
  → 走到櫃台左邊「上架」格 → 排隊的顧客自動購買,錢堆在左下的錢格 → 站到錢格撿錢 → 站到價格牌上自動付錢(可分期、走開暫停):
  僱用漁夫 $10(他會自己抓魚、卸到切魚台)、擴充背包 $25、增建第二座切魚台 $50(橘色建地)。
- 數值:`data/config/game.json`(速度、容量、搬運速率、魚群、顧客、售價);物品 `data/items.json`;站點 `data/stations.json`;價格牌 `data/shop.json`;文字 `data/locale/strings.csv`。
- 跑測試:`powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1`
