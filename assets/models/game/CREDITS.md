# 模型來源(全部 CC0,不需標註)

遊戲只載入這個資料夾(`assets/models/game/`)裡的檔案;原始套件留在 `assets/models/<套件名>/`
(裡面放了 `.gdignore`,Godot 不匯入也不匯出,git 也不追蹤)。要用別的模型就從原始套件複製過來。

- `characters/`:Kenney「Mini Characters」1.0(2024-07-17)https://kenney.nl/assets/mini-characters — 12 個人物 GLB + `Textures/colormap.png`(GLB 用相對路徑引用,資料夾結構要保留)。每個人物 32 支動畫:static / idle / walk / sprint / jump / fall / crouch / sit / drive / die / pick-up / emote-yes / emote-no / holding-* / attack-* / interact-left / interact-right / wheelchair-*。
- `props/`:Kenney「Survival Kit」2.0(2024-04-03)https://kenney.nl/assets/survival-kit — fish / fish-large / bucket / tool-hammer / tool-axe / tool-axe-upgraded / tool-pickaxe / tool-pickaxe-upgraded GLB
  (鎚 / 斧 / 強化斧是玩家的武器 Lv1 ~ Lv3,鎬 / 強化鎬是武器店升級後的 Lv4 ~ Lv6)+ `Textures/colormap.png`。
- `fish/`:Quaternius「Animated Fish Pack」https://quaternius.com/packs/animatedfish.html — Fish1 / Fish2 / Fish3 FBX(含游泳動畫,平面色材質)。
