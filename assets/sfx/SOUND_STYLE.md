# Sound style: ManLife(星港漁市)

照 game-sfx skill 的「sound bible」格式;改音效前先讀這份,新音效要和這一家人像。

## Identity
- **Game:** 休閒閒置經營:雪地漁市,抓魚 -> 切 / 烤 / 煮 -> 賣給顧客,僱幫手自動化,北極熊來搗亂,打王、擴建、過冬傳承
- **Style:** cartoon / casual(Kenney 低多邊形、Claymorphism UI、溫暖配色;不是 8-bit,也不是寫實)
- **Mood:** 溫暖、俏皮、節奏輕快;熊的段落偏厚重但不恐怖
- **Engine:** Godot 4.7(音檔 `assets/sfx/<name>.wav`,16-bit mono 44.1 kHz;Sfx autoload 依 NAMES 載入,同名覆蓋即可)

## Palette
- **Sources:** sine + FM 小鈴(收錢 / 選卡)、木琴倍頻(放貨 / 買單 / 解鎖 / 教學)、帶顫音的正弦口哨(僱人)、驅動正弦悶響 + 帶通噪音(熊 / 打擊 / 崩塌)、
  三角波 + 噪音 tick(UI)。不用方波 buzz、不用鋸齒,噪音都要帶通 / 低通。
- **Materials in the world:** 冰冷海水(抓魚的啵)、木棧板 / 木桌(放貨、櫃台)、雪地(悶)、硬幣、魚、熊毛與牙(咬合)、弓弦與箭
- **Music key / tempo:** 背景 chiptune 循環 bgm_harbor:C 大調、80 BPM(Game Boy 音色,放很小聲);叮噹聲用 C / E / G / A 系列音
- **Space:** 戶外偏乾:reverb mix 0.06 ~ 0.12、decay 0.3 ~ 0.5;只有「獎勵」類(解鎖 / 寶箱 / 選卡)加到 0.15 ~ 0.18

## Loudness ladder(master.lufs)
| Tier | LUFS | Sounds |
|---|---|---|
| Hero | -12 ~ -14 | crash、roar、chomp、hit、unlock、chest、warn |
| Gameplay | -15 ~ -17 | catch、sale、pick、hire、goal、card、arrow |
| Frequent | -18 ~ -19 | drop、trash、coin(每秒多次,要輕) |
| UI | -21 | tap、pay |
| Ambient | -24 | ambient_waves(循環) |

## Sound list
| Name | Event in code | Status |
|---|---|---|
| catch | FishArea 抓到魚(items_moved kind catch) | done(卡通) |
| drop / pick | 格子放下 / 拿起(items_moved) | done |
| sale | Counter 賣出(items_moved sold) | done |
| coin / pay | 錢格收錢 / 價格牌分期 | done |
| trash | TrashPad | done |
| unlock / hire | purchased(一般 / 僱用) | done |
| goal | tutorial_step_done、offline_claimed | done |
| roar / chomp / hit | 熊出現 & 被打跑 / 吃掉 / 被打 | done |
| arrow / crash | 守衛塔射箭 / 塔塌 & 工作站被拆 | done |
| warn / chest / card | 王預告 / 開箱 / 選卡 | done |
| tap | UI 按鈕(UiTheme.press_fx) | done |
| ambient_waves | 環境循環 | done(8 秒循環) |
| bgm_harbor | 背景音樂循環(retro-audio mml.py) | done |

## Decisions
- 2026-11-09 全部音效從 tools/gen_sfx.py 的單層正弦占位換成分層 patch(assets/sfx/patches/*.json,tools/render_sfx.py 重新算):doctor 原本報 coin 100% 能量在 2-5 kHz(刺耳)、
  pay / sale / warn / ambient 起迄不在零點(會喀),新版全部 OK。
- coin 比其他撿取聲低 3 dB(-19):每秒可響 20 次,要退到背景。
- 熊的 roar 不用噪音當主體(會像風聲),改厚倍頻 + 顫音;chomp 兩下咬合比一下有「吃」的感覺。
