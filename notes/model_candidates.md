# 角色與貨物模型候選清單(2026-10-27)

條件:免費、可商用(CC0 優先)、低多邊形、Godot 4.7 可直接匯入(glTF / GLB 或 FBX)、人物要內建走路 / 待機動畫、順便找魚 / 魚片 / 烤魚。
以下資料都是 2026-10-27 從官網、itch.io、OpenGameArt、Poly Pizza 查證的;數量與格式以下載解壓後為準。

## 建議組合

1. 人物:**Kenney Mini Characters**(Q 版大頭,最像參考影片的閒置遊戲風格)。想要釣魚 / 敲打 / 歡呼這類動作就改用 **KayKit Adventurers + Character Animations**。
2. 貨物:**Quaternius Modular Sushi Restaurant Kit**(整條魚與魚片同一風格,Poly Pizza 可只挑需要的幾個 GLB);Kenney Food Kit 的 Fish / Cutting Board / Skewer 當備用。
3. 水裡游的魚(裝飾):**Quaternius Animated Cute Fish Pack**。
4. 烤魚:沒有找到 CC0 的低多邊形烤魚模型,用魚片模型換棕色材質 + 木籤(Kenney Skewer)或我在程式裡做焦痕。

## 人物

### 1. Kenney — Mini Characters(建議)

- 下載:https://kenney.nl/assets/mini-characters(鏡像:https://opengameart.org/content/mini-character-1)
- 授權:CC0(不需標註)。2024 年 1.0 版,zip 約 2.4 MB。
- 內容:12 個人物(男女各 a ~ f),每個 32 支動畫(含輪椅動作);第三方整理的動作狀態有 walk / run / jump / attack / sit / wave。
- 格式:官網沒標;Kenney 同系列的 Mini Dungeon / Mini Skate / Mini Arcade 都是 OBJ + FBX + glTF,解壓後確認有沒有 .glb / .gltf。
- 風格:大頭短手腳、單色塊面、面數極低,和參考影片的雪地漁市小人最接近;12 個人物夠分玩家 / 漁夫 / 搬運工 / 收銀員 / 顧客,職業再用顏色或帽子區分。
- 注意:沒有「搬東西」動作,背上堆疊維持現在的做法,走路動畫就夠。OpenGameArt 有人反映照 Kenney 教學匯入 FBX 時動畫會掉,Godot 直接用 glTF 版(若有)或內建 FBX 匯入即可。

### 2. KayKit — Character Pack: Adventurers + Character Animations(動作最齊)

- 下載:https://kaylousberg.itch.io/kaykit-adventurers(自訂價格,免費層即可);動畫包 https://kaylousberg.itch.io/kaykit-character-animations(同樣免費層)。
  也在 Godot 資源庫:https://godotengine.org/asset-library/asset/2129 ;GitHub:https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0
- 授權:CC0(作者只要求不要原封不動轉賣)。
- 內容:免費層 5 個人物 Knight / Barbarian / Rogue(含 Rogue_Hooded)/ Mage / Ranger,FBX + GLTF,12 MB,含基本移動動畫;
  動畫包 161 支人形動畫(免費層 150+),FBX + GLTF,14 MB,分 Rig_Medium / Rig_Large,類別有待機、受擊、互動(interacting)、走 / 跑 / 跳 / 蹲、揮手 / 歡呼 / 坐,
  工具類有釣魚(fishing)、敲打(hammering)、一般工作(generic working)、挖掘、鎬。
- 貼圖:單張 1024 × 1024 漸層圖,可縮到 128 × 128。
- 風格:卡通大頭、粗壯身形,很適合閒置經營;缺點是奇幻裝扮(騎士 / 法師),當漁夫要換色或接受風格。平民 / 村民人物在付費的 Mystery Monthly 系列(US$13.39),這次不列。

### 3. Quaternius — Ultimate Modular Men Pack / Ultimate Modular Women Pack(職業最好分)

- 下載:https://quaternius.com/packs/ultimatemodularcharacters.html 、https://quaternius.com/packs/ultimatemodularwomen.html
  (Poly Pizza 可單個下載 GLB:https://poly.pizza/bundle/Ultimate-Modular-Men-Pack-ZiH8muWqwQ 、https://poly.pizza/bundle/Ultimate-Modular-Women-Pack-aCBDXDdTNN)
- 授權:套件頁與 Poly Pizza 都標 CC0。官網的授權頁 2026-08-28 改成 Quaternius Asset License 1.0(商用免標註,只禁止再打包販售,不溯及已下載的舊版)。
- 內容:男 11 人(Adventurer / King / Farmer / Hoodie / Beach / Casual / Worker / Punk / SWAT / Business Man / Astronaut)、女 10 人;每個人物拆成 4 個可互換部件;24 支動畫(頁面沒列名稱)。
- 格式:FBX / OBJ / Blend + glTF(Poly Pizza 給 GLB)。
- 風格:正常比例的低多邊形,比 Kenney / KayKit 寫實一點;Farmer / Worker / Casual 直接對應漁夫 / 搬運工 / 顧客。

### 4. Kenney — Blocky Characters 2.0(方塊人)

- 下載:https://kenney.nl/assets/blocky-characters(鏡像:https://opengameart.org/content/blocky-characters)
- 授權:CC0。2025 年重製版,2.1 MB。
- 內容:18 種皮膚、27 支動畫,FBX + OBJ + glTF。
- 風格:Minecraft 式方塊人,和現在的方塊世界最像,但不像參考影片。

### 5. 其他(不建議,列著備查)

- Kenney Animated Characters Protagonists / Retro / Survivors(https://kenney.nl/assets/animated-characters-protagonists 等):CC0,但每包只有 4 種皮膚、3 支動畫(idle / jump / run,沒有 walk)。
- Quaternius Ultimate Animated Character Pack(https://quaternius.com/packs/ultimatedanimatedcharacter.html):52 個人物,CC0,2019 年,只有 FBX / OBJ / Blend(Godot 4.7 可直接匯 FBX),已被上面的 Modular 系列取代。
- Quaternius Universal Base Characters + Universal Animation Library(https://quaternius.com/packs/universalbasecharacters.html 、https://quaternius.com/packs/universalanimationlibrary.html):
  6 個基礎人物 + 免費層 45 支動畫(第 2 代 130+ 支,七成免費),要在 Godot 做骨架重定向,多一道工序,比例也偏寫實。
- Quaternius Modular Sushi Restaurant Kit 裡的動物角色(兔子 5 種、熊貓 1 種,30 支動畫):若接受動物當店員,人物與魚一包搞定。

## 貨物(魚 / 魚片 / 烤魚)

### 1. Quaternius — Modular Sushi Restaurant Kit(建議)

- 下載:https://quaternius.com/packs/sushirestaurantkit.html(官網 108 件,FBX / OBJ / Blend / glTF,CC0);
  Poly Pizza 單檔下載:https://poly.pizza/bundle/Modular-Sushi-Restaurant-Kit-LJZrZsNPM7(86 件,FBX + glTF)
- 魚:Dead Fish、Dead Mackerel、Dead Salmon、Dead Tuna、Dead Flounder、Dead Eel、Salmon(整條,https://poly.pizza/m/2BeZAlQ73h)、Bucket of Fish(https://poly.pizza/m/G61jVPof0G)
- 魚片:Fish Fillet(https://poly.pizza/m/nQVHa5aYfP)、Shimesaba(醋漬鯖魚片,有魚皮紋,換棕色可當烤魚)、Crabsticks
- 可順便用的道具:Chopping board、Kitchen Knives、Counter Straight / Corner / End、Plate、Wooden Board

### 2. Kenney — Food Kit

- 下載:https://kenney.nl/assets/food-kit ;Poly Pizza:https://poly.pizza/bundle/Food-Kit-vOc58LJ0ge(148 件,OBJ + glTF)
- 授權:CC0。約 200 個檔案,OBJ / FBX / glTF。
- 相關模型:Fish(https://poly.pizza/m/HkUAXudvBt)、Fish Bones、Sushi Salmon、Sushi Egg、Cutting Board、Cooking Knife / Knife Block、Skewer Vegetables(木籤可拿來做烤魚串)、Mussel Open
- 風格:和 Mini Characters 同作者,色塊風一致。沒有魚片,也沒有烤魚。

### 3. Kenney — Survival Kit

- 下載:https://kenney.nl/assets/survival-kit ;Poly Pizza:https://poly.pizza/bundle/Survival-Kit-yGnSPFp2lH(43 件)
- 授權:CC0。相關模型:Fish、Fishing Stand、Campfire、Barrel / Barrel Open。

### 4. 水裡游的魚(裝飾用,目前是 6 個方塊)

- Quaternius Animated Cute Fish Pack:https://quaternius.com/packs/cutefish.html(52 件,含釣竿 / 魚餌,FBX / OBJ / Blend,CC0)
- Quaternius Animated Fish Pack:https://quaternius.com/packs/animatedfish.html ;itch 版 https://quaternius.itch.io/lowpoly-animated-fish(1 MB,每條只有游泳動畫);
  Poly Pizza:https://poly.pizza/bundle/Animated-Fish-Bundle-ZkGbjS8m8g(7 件,FBX + GLB)

### 5. 烤魚

- Poly Pizza、Sketchfab、itch.io 都沒有 CC0 低多邊形的烤魚;Sketchfab 唯一的鹽烤鮭魚串是 CC-BY 的 8,883 面掃描模型,不適合。
- 做法:魚片模型(Fish Fillet 或 Shimesaba)換棕色材質 + Kenney Skewer 的木籤;或由我用 VisualFactory 在魚片上加焦痕色塊。

## Poly Pizza 使用說明

- https://poly.pizza 可直接搜尋、預覽、單個下載 GLB,每個模型頁都標授權;Kenney / Quaternius 的是 CC0,「Poly by Google」的是 CC-BY(要在遊戲裡標註作者)。
- 同一套件的模型色調一致,挑貨物時盡量同一作者。

## 匯入與尺寸

- Godot 4.7:.glb / .gltf 直接丟進 `res://assets/models/<套件名>/`,匯入後是場景 + AnimationPlayer;.fbx 也能直接匯入(4.3 起內建 ufbx,不用 FBX2glTF)。Kenney 的知識庫也建議 Godot 用 GLB。
- 目前人物是膠囊:半徑 0.4、高 1.6,腳底到頭頂約 1.7;顧客 1.4。模型會等比例縮到這個高度,碰撞與格子判定不用改。
- 貨物尺寸(data/items.json):魚 0.7 × 0.22 × 0.3、魚片 0.5 × 0.12 × 0.4、烤魚 0.5 × 0.14 × 0.42。堆疊用 MultiMesh,一種貨物最好是單一材質的單一網格;多 surface 的模型我會先合併。
- 下載量:Kenney 單包 2 ~ 3 MB、KayKit 兩包共 26 MB,但只有用到的模型會進 pck;KayKit 的 1024 貼圖可縮到 128。
- 授權:全部 CC0 不用標註;若之後混用 CC-BY 的 Poly by Google 模型,要在選單加「致謝」。

## 下載後

把解壓的資料夾放到 `assets/models/`(例如 `assets/models/kenney_mini_characters/`、`assets/models/quaternius_sushi/`),告訴我用哪一包,我再接:
人物換模型 + 依移動狀態播 idle / walk(幫手的釣魚 / 工作動作若有就用)、貨物堆疊換模型網格、水裡的魚換模型,並跑全部測試。
