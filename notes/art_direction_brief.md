# ManLife 美術方向簡報(create-game-assets skill 的 art-direction-brief,2026-11-09)

照 skill 的流程:先盤點現有資產、鎖定技術框架、用具體視覺屬性描述系統(不借用在世藝術家的名字),再列資產清單(notes/asset-manifest.json)。
這份是「既有方向的整理」,不是重新設計;新資產(模型、圖示、貼圖)都要能放進這個系統。

## Game frame

- Player fantasy:在雪地漁村把一攤魚市做成一條街,幫手替你跑腿,北極熊來了自己拿鎚子上;把火種留給下一代。
- Core verbs:走路、抓魚、放 / 拿、賣、付錢、打熊、擴建、過冬。
- Engine and renderer:Godot 4.7,Compatibility(網頁匯出唯一選項),無即時陰影時用腳下圓影。
- Target platforms:iPhone PWA(直式優先)+ 桌機瀏覽器 / 桌機視窗(橫式)。
- Camera/view/facing:等角俯視,從 +Z 往 -Z 看(螢幕上 = 世界 -Z);人物 local +Z 是臉;直式 fov 40 偏移 (0, 13.5, 9.5)、橫式 fov 42 (0, 17, 11.5)。
- Native viewport and common display scale:540 × 960 邏輯解析度,像素密度上限 2;流暢畫質 3D 以 0.75 倍算。
- Typical asset size on screen:人物約 1.5 世界單位高,直式畫面上約 70 ~ 90 px;格子 2 × 2 單位;價格牌標籤字 36 ~ 48(Label3D pixel_size 0.01)。

## Visual system

- Shape language:圓角方塊與矮胖比例(Kenney Mini Characters 的頭身比);建築 = 方塊 + 圓柱 + 圓錐屋頂;沒有尖銳薄片。
- Silhouette priorities:人物靠頭與帽子分辨角色;建築靠屋頂顏色與高度;熊靠白色大塊頭 + 深色鼻子;王多金冠與體型。
- Value structure:雪地 / 沙地 (0.93 / 0.88 亮) 當底,建築中灰到中亮,文字與 HUD 用深底亮字疊上去;重要互動物(牌子、錢格)比環境暗一階。
- Palette roles and exact swatches:
  - 雪 #EDF2FA(0.93, 0.95, 0.98)、沙地 #E0C299(0.88, 0.76, 0.6)、柵欄木 #CC9E6B(0.8, 0.62, 0.42)、深木 #73503300(0.45, 0.3, 0.2)
  - 水 #3373D9(0.2, 0.45, 0.85)、魚 #9CC4E8、魚片 #F28C8C、烤魚 棕、魚湯 橙黃、毛衣 藍 / 紅
  - UI token(UiTheme):面板 #14171F、金 #FFE073、主動作 #F59E0B(獎勵金)、危險 #DC2626、次要 #333D54
  - 角色:玩家 male-a、漁夫 male-b、搬運工 male-f、收銀員 male-c、工人 male-e、衛兵 female-c + 盔甲方塊;顧客 7 種輪流
- Materials and surface cues:全部平面色(Kenney colormap),沒有貼圖細節;金屬只用亮一階的灰;水面是平的藍方塊 + 魚在裡面游。
- Edge/line treatment:無描邊;靠顏色對比分辨;3D 文字有黑色描邊(outline 8 ~ 10)。
- Lighting direction and contrast:一盞方向光 (-52°, -28°) 能量 1.1,環境光偏藍白 (0.75, 0.8, 0.9) × 0.9;精細畫質開陰影,流暢畫質關。
- Detail density and focal hierarchy:地面極簡,建築中等,人物最細(動畫);一個畫面同時只有一個會動的 UI(升級鈕脈動 / 火堆火焰)。
- Motion character:人物 idle / walk / interact / emote 循環;貨物拋物線飛;按鈕 0.2 秒 ease-out;相機 trauma 震動(見 JuiceLogic)。
- Explicit exclusions:寫實貼圖、血、黑暗恐怖的熊、emoji 當圖示、照片。

## Technical contract

- Asset dimensions/aspect:人物 GLB 等比例縮到 1.5(顧客 1.3、工人 ×0.95);物品 items.json size 框(魚 0.7 × 0.23 × 0.36);圖示 128 / 144 / 180 / 512 正方形。
- Alpha/background:圖示不透明圓角方;啟動畫面不透明。
- Grid/tile/frame size:格子 2 × 2 單位,價格牌排間距 4;擴建區 18.6 寬、南塊 25.2 × 18。
- Anchor/pivot/baseline:人物腳底 0、XZ 置中、臉朝 +Z;物品底貼框底;Label3D 在物件上方 1.6 ~ 2.4。
- Filtering/mipmaps/compression:Compatibility 預設;GLB 匯入照 Godot 4.7 預設;WAV 16-bit mono。
- Color space:sRGB。
- Texture/poly/material budgets:StaticBatch 每色一個 surface、不超過 10 色;堆疊用 MultiMesh;每件物品不另開繪製呼叫。
- Naming and folders:遊戲用模型只放 assets/models/game/(characters / props / fish),原始套件放 assets/models/<套件>/ 並 .gdignore;音效 assets/sfx/<name>.wav + patches/;圖示 assets/icons/。

## Visual target

- Approved seed/reference paths:assets/models/game/characters/character-male-a.glb(玩家)、assets/models/game/props/fish.glb(貨物)、tools/snap_scene 的 01_village.png。
- Required do/don't examples:DO 平面色方塊建築 + 圓錐屋頂(守衛塔);DON'T 高模或貼圖寫實物件混進來(會和 Kenney 人物打架)。
- Native-scale gameplay capture:tools/snap_scene.tscn 產的 900 × 900 截圖(01_village、05_annex、08_guard_tower、20_south_blocks)。
- Approval owner/date:使用者(tyboy0407)/ 2026-10-27 模型方向定案(1a 免費 CC0 低多邊形、2b 人物 + 貨物、3a 內建動畫)。

## 現況與缺口(skill 的「inspect before inventing」)

| 資產 | 現況 | 缺口 / 建議 |
|---|---|---|
| 人物 ×12 | Kenney Mini Characters,32 支動畫 | 無 |
| 魚(貨物 / 水裡) | Survival Kit fish.glb / Quaternius FBX | 無 |
| 魚片 / 烤魚 / 魚湯 / 毛衣 | items.json 色塊方塊 | 候選:Quaternius Modular Sushi Restaurant Kit(CC0)的食物;魚湯可用碗 + 圓柱 |
| 北極熊 / 王 | 程式用方塊拼的熊(身體 / 頭 / 耳 / 鼻 / 四腿,王多金冠) | 候選:Quaternius Animals 的熊(CC0);接上去只要填 game.json models.bear.file |
| 建築(切魚台 / 烤魚攤 / 廚房 / 服飾店 / 櫃台 / 塔 / 武器店) | 程式方塊 + 圓柱 + 圓錐 | 保持程式化即可(風格一致);若換模型要維持屋頂色 = 功能色 |
| 圖示 / 啟動畫面 | tools/gen_icons.py 的 Pillow 占位(藍底 + 簡單圖形) | 建議重畫:雪地底 + 魚 + 火堆的三色剪影,四個尺寸同一張向量來源縮放(asset_report 檢查見 manifest) |
| 音效 / 音樂 | 2026-11-09 起分層合成 patch + chiptune 循環 | 已處理(assets/sfx/SOUND_STYLE.md) |
