class_name KingLogic
extends RefCounted
## 北極熊王的獎勵循環(純資料,數值在 game.json king.reward):
## - 預告:王出場前 warnSec 秒倒數,期間一般熊不來。
## - 表現分:王在村裡期間吃了幾個幫手、拆了幾棟建築 -> grade():perfect(0 / 0)×perfectMult、good(沒拆建築)×goodMult、normal ×1。
## - 連勝:連續 perfect 每層 +streakStep,上限 streakMax;不是 perfect 就歸零。
## - 王的等級:每打死一次 +1(上限 maxLevel):血 ×(1 + hpPerLevel × 級)、體型 ×(1 + scalePerLevel × 級)、咬建築 ×biteMultPerLevel^級、
##   寶箱倍率 ×(1 + rewardPerLevel × 級)。等級從 0 起算(第一次來的王是 Lv0 = 原本的王)。
## - 寶箱三選一:現金 = 收入速率 × cashSec × 倍率(至少 cashMin)、毛皮 = pelts × 倍率、券(保險 / 平靜 / 免費升級,權重 couponWeights)。
##   保底熊王牙 teeth 顆(不乘倍率)。
## - 戰利品牆里程碑:殺到 milestones 裡的次數時永久背包 +1。

const COUPONS := ["insurance", "calm", "upgrade"]

var cfg := {}


static func from_config(king_cfg: Dictionary) -> KingLogic:
    var k := KingLogic.new()
    var r = king_cfg.get("reward", {}) if king_cfg != null else {}
    k.cfg = r if typeof(r) == TYPE_DICTIONARY else {}
    return k


func warn_sec() -> float:
    return maxf(float(cfg.get("warnSec", 45.0)), 0.0)


func max_level() -> int:
    return maxi(int(cfg.get("maxLevel", 10)), 0)


func clamp_level(level: int) -> int:
    return clampi(level, 0, max_level())


## --- 王的成長 ---

func hp_mult(level: int) -> float:
    return 1.0 + maxf(float(cfg.get("hpPerLevel", 0.25)), 0.0) * float(clamp_level(level))


func scale_mult(level: int) -> float:
    return 1.0 + maxf(float(cfg.get("scalePerLevel", 0.05)), 0.0) * float(clamp_level(level))


## 咬建築的秒數倍率(每級 ×0.9 -> 拆得更快)
func building_bite_mult(level: int) -> float:
    return pow(clampf(float(cfg.get("biteMultPerLevel", 0.9)), 0.1, 1.0), float(clamp_level(level)))


func reward_level_mult(level: int) -> float:
    return 1.0 + maxf(float(cfg.get("rewardPerLevel", 0.2)), 0.0) * float(clamp_level(level))


## --- 表現分與連勝 ---

## 王在村裡期間:吃掉 eaten 個幫手、拆掉 wrecked 棟建築
func grade(eaten: int, wrecked: int) -> String:
    if eaten <= 0 and wrecked <= 0:
        return "perfect"
    if wrecked <= 0:
        return "good"
    return "normal"


func grade_mult(g: String) -> float:
    match g:
        "perfect":
            return maxf(float(cfg.get("perfectMult", 2.0)), 1.0)
        "good":
            return maxf(float(cfg.get("goodMult", 1.5)), 1.0)
    return 1.0


## 打死後的新連勝數
func next_streak(streak: int, g: String) -> int:
    return streak + 1 if g == "perfect" else 0


func streak_bonus(streak: int) -> float:
    var step := maxf(float(cfg.get("streakStep", 0.1)), 0.0)
    return minf(step * float(maxi(streak, 0)), maxf(float(cfg.get("streakMax", 0.5)), 0.0))


## 寶箱總倍率 = 表現分 × (1 + 連勝加成) × 等級倍率;streak 是打死前的連勝(這次 perfect 才會算進去)
func total_mult(g: String, streak_before: int, level: int) -> float:
    var streak_after := next_streak(streak_before, g)
    return grade_mult(g) * (1.0 + streak_bonus(streak_after)) * reward_level_mult(level)


## --- 寶箱 ---

func teeth() -> int:
    return maxi(int(cfg.get("teeth", 3)), 0)


## 現金卡:最近的收入速率(每秒)× cashSec × 倍率,至少 cashMin
func cash_card(rate_per_sec: float, mult: float) -> int:
    var base := maxf(rate_per_sec, 0.0) * maxf(float(cfg.get("cashSec", 90.0)), 0.0)
    return maxi(int(round(base * mult)), int(cfg.get("cashMin", 100)))


func pelt_card(mult: float) -> int:
    return maxi(int(round(float(cfg.get("pelts", 5)) * mult)), 1)


## 券卡:依權重抽一種(roll 0 ~ 1)
func coupon_card(roll: float) -> String:
    var w = cfg.get("couponWeights", [1, 1, 1])
    var weights: Array = w if typeof(w) == TYPE_ARRAY and not w.is_empty() else [1, 1, 1]
    var total := 0.0
    for i in COUPONS.size():
        total += maxf(float(weights[i]) if i < weights.size() else 0.0, 0.0)
    if total <= 0.0:
        return COUPONS[0]
    var acc := 0.0
    var r := clampf(roll, 0.0, 0.999999) * total
    for i in COUPONS.size():
        acc += maxf(float(weights[i]) if i < weights.size() else 0.0, 0.0)
        if r < acc:
            return COUPONS[i]
    return COUPONS[COUPONS.size() - 1]


## 寶箱內容:{teeth, mult, grade, cards: [{kind: "cash", amount}, {kind: "pelt", amount}, {kind: "coupon", coupon}]}
func chest(g: String, streak_before: int, level: int, rate_per_sec: float, roll: float) -> Dictionary:
    var mult := total_mult(g, streak_before, level)
    return {
        "teeth": teeth(), "mult": mult, "grade": g,
        "cards": [
            {"kind": "cash", "amount": cash_card(rate_per_sec, mult)},
            {"kind": "pelt", "amount": pelt_card(mult)},
            {"kind": "coupon", "coupon": coupon_card(roll)},
        ],
    }


## --- 券 ---

func calm_sec() -> float:
    return maxf(float(cfg.get("calmSec", 120.0)), 0.0)


func insurance_return_sec() -> float:
    return maxf(float(cfg.get("insuranceReturnSec", 10.0)), 0.0)


## --- 戰利品牆 ---

## 第 kills 次擊殺是不是里程碑(永久背包 +1)
func is_milestone(kills: int) -> bool:
    var m = cfg.get("milestones", [5, 10])
    if typeof(m) != TYPE_ARRAY:
        return false
    for v in m:
        if int(v) == kills:
            return true
    return false


func trophy_cap() -> int:
    return maxi(int(cfg.get("trophyCap", 10)), 0)
