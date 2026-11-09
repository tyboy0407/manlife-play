# UI 設計決策(2026-11-09,依 ui-ux-pro-max 的設計系統輸出調整)

來源:`notes/design-system/manlife/MASTER.md`(ui-ux-pro-max 的 `--design-system` 輸出,查詢「casual idle mobile game snowy fishing village playful cozy」,
dials variance 5 / motion 4 / density 8),加上 `--domain ux` 的準則查詢(touch target、toast、contrast、reduced motion、destructive confirmation、number formatting)。
MASTER.md 是網頁版的通用建議(Google Fonts、GSAP、Tailwind token),這裡記下實際套到 Godot HUD 的對應與沒採用的原因。

## 採用

| 設計系統 | 套到哪裡 |
|---|---|
| 風格 Claymorphism(休閒遊戲:圓角 16 ~ 24、厚邊 3 ~ 4px、柔和陰影、soft press 200ms ease-out) | UiTheme:面板圓角 18 / 邊 2 + 陰影 10;按鈕圓角 14 / 厚邊 3;primary / danger 鈕有陰影、按下收掉;press_fx 0.2 秒 ease-out |
| Accent / CTA #F59E0B「獎勵金」+ On Accent #0F172A | UiTheme.PRIMARY / PRIMARY_TEXT(領取 / 過冬 / 塔升級 / 回村 / 升級鈕) |
| Destructive #DC2626 | UiTheme.DANGER(重新開始、過冬第二下) |
| 文字對比 >= 4.5:1、body >= 16px、說明文字 >= 14 | 面板內文 16、小籤 / 副標 14、底部提示 15;TEXT_DIM 調亮 |
| 觸控目標 >= 44、間距 >= 8 | 按鈕高 48、方格開關 54 × 56、火種列 54、清單間距 8 |
| toast 3 ~ 5 秒自動消失 | Hud.NOTICE_SEC 3.5 |
| 大數字分隔 | UiTheme.fmt_int,錢包顯示 $1,234,567 |
| 危險動作要確認 | 重新開始 / 過冬都要按兩下(原本就有) |
| 一個畫面一個主動作、次要動作視覺上退後 | 每個面板只有一顆 primary,其他 secondary |
| 不只靠顏色傳達狀態 | 方格開關綠 / 灰之外還寫「開 / 關」 |
| 動畫不要每個都動 | 只有守衛塔「升級」鈕脈動、火堆火焰閃 |

## 沒採用(與原因)

- Primary #EC4899 粉 / Secondary #8B5CF6 紫、淺粉背景:設計系統的「休閒益智遊戲」配色和雪地漁市 + 深色面板不搭,只取 Accent / Destructive。
- Fredoka + Nunito:網頁版拿不到系統字型、也沒有中文,遊戲內只有 Noto Sans TC(assets/fonts),字級照設計系統的比例調。
- Hero + Testimonials 版型、GSAP stagger:行銷頁的東西,遊戲 HUD 用不到。
- prefers-reduced-motion:Godot 讀不到系統設定;目前動效只有兩處,暫不加開關。
- 安全區(瀏海):PWA 的 canvas 沒有 viewport-fit=cover,畫布不會伸到瀏海下,HUD 上緣 10px 即可;若之後改 cover 再加 DisplayServer.get_display_safe_area。
