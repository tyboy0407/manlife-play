# -*- coding: utf-8 -*-
"""ManLife 經濟 / 進度模型(game-balancer skill 的「spreadsheet model」,用 Python 代替試算表)。

讀 data/ 的 JSON,照 harbor.gd 的擴建內容算每個階段(擴建 0 ~ 7 次)的:
  供給(漁夫抓魚 -> 切魚台 -> 烤魚攤 / 廚房)、需求(顧客來客 × 要幾件)、每分鐘收入、下一次擴建要多久,
  三種玩家輪廓(casual / median / hardcore)累積到每個階段的天數(含離線收益),僱用牌階梯的總價,傳承點數。
假設都寫在 ASSUMPTIONS 裡,改數值不用動程式;輸出 markdown 到 stdout(notes/balance_pass_*.md 貼這個)。

    python tools/balance_model.py            # markdown 報告
    python tools/balance_model.py --json     # 機器可讀
"""
import io, json, math, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load(name):
    return json.load(io.open(os.path.join(ROOT, "data", name), encoding="utf-8"))


G = load("config/game.json")
STATIONS = {s["id"]: s for s in load("stations.json")["stations"]}
_c = load("counters.json")
COUNTERS = {c["id"]: c for c in (_c["counters"] if isinstance(_c, dict) else _c)}
_s = load("shop.json")
SHOP = {p["id"]: p for p in (_s["purchases"] if isinstance(_s, dict) and "purchases" in _s else _s) if isinstance(p, dict)}

# --- 假設(模型外的常數;改這裡) ---
ASSUMPTIONS = {
    "fisher_fish_per_sec": 0.45,     # 一位漁夫每秒抓到的魚(容量 6、一趟含走路約 13 秒)
    "porter_items_per_sec": 0.55,    # 一位搬運工每秒搬到的件數(容量 8、一趟約 15 秒)
    "player_items_per_sec": 0.8,     # 玩家自己搬(前期沒搬運工時)
    "helpers_hired_frac": 0.8,       # 玩家通常把名額僱到幾成(後面幾位太貴買不下去)
    "avg_session_min": {"casual": 15, "median": 40, "hardcore": 120},   # 每天在線分鐘
    "offline_hours": {"casual": 8, "median": 8, "hardcore": 6},         # 每天離線可算的小時(上限 8)
    "other_sinks_frac": 0.35,        # 收入裡拿去買幫手 / 升級 / 塔 / 武器的比例(其餘存給擴建)
}

# 各階段(擴建 k 次後)的建築;照 harbor.gd 的 UNLOCKS(主村含 $50 切魚台 2 與 $60 烤魚攤)
STAGE_BUILDINGS = [
    {"cutting_table": 2, "grill": 1, "counters": ["fillet_counter", "grill_counter"], "cost": 0},
    {"cutting_table": 1, "grill": 1, "counters": ["fillet_counter_2", "grill_counter_2"], "cost": 1000},
    {"cutting_table": 1, "grill": 3, "counters": ["fillet_counter_3", "grill_counter_3"], "cost": 2000},
    {"grill": 2, "tailor": 1, "counters": ["sweater_counter"], "cost": 8000},
    {"kitchen": 1, "counters": ["soup_counter"], "cost": 20000},
    {"cutting_table": 2, "grill": 1, "counters": ["fillet_counter_4", "grill_counter_4"], "cost": 16000},
    {"grill": 2, "kitchen": 1, "counters": ["grill_counter_5", "soup_counter_2"], "cost": 32000},
    {"kitchen": 2, "counters": ["soup_counter_3", "soup_counter_4"], "cost": 64000},
]


def hire_slots(role, expansions):
    p = SHOP["hire_" + role]
    return int(p.get("maxBuys", 1)) + int(p.get("expandBuys", 0)) * min(expansions, 7)


def hire_ladder_cost(role, n):
    """買到第 n 位的累計價(cost × costMult^i)"""
    p = SHOP["hire_" + role]
    c, m = float(p["cost"]), float(p.get("costMult", 1.0))
    return [round(c * m ** i) for i in range(n)]


def avg_want(expansions):
    cu = G["customers"]
    w = list(cu["wantWeights"])
    pe = cu.get("perExpansion", {})
    shift = int(pe.get("wantShift", 1)) * expansions
    wmax = int(pe.get("wantMax", 9))
    # CounterLogic.shift_weights:權重往多件偏(每次擴建整體往右移一格,最多到 wantMax 件)
    weights = [0.0] * wmax
    for i, x in enumerate(w):
        j = min(i + shift, wmax - 1)
        weights[j] += x
    tot = sum(weights)
    return sum((i + 1) * x for i, x in enumerate(weights)) / tot if tot > 0 else 1.0


def customer_demand_per_sec(expansions, max_customers_override=None):
    """一座櫃台每秒想買幾件 = 來客速率 × 平均要幾件(排隊上限夠的話)"""
    cu = G["customers"]
    interval = float(cu["spawnIntervalSec"]) * float(cu.get("perExpansion", {}).get("intervalMult", 0.85)) ** expansions
    return avg_want(expansions) / interval


def stage_model(k, profile_frac=1.0):
    """擴建 k 次後整個村子的供給 / 需求 / 收入(每秒)"""
    stations = {"cutting_table": 0, "grill": 0, "kitchen": 0, "tailor": 0}
    counters = []
    for i in range(k + 1):
        for sid, n in STAGE_BUILDINGS[i].items():
            if sid in stations:
                stations[sid] += n
        counters += STAGE_BUILDINGS[i]["counters"]
    fishers = max(1, round(hire_slots("fisher", k) * ASSUMPTIONS["helpers_hired_frac"]))
    porters = round(hire_slots("porter", k) * ASSUMPTIONS["helpers_hired_frac"])
    fish_in = fishers * ASSUMPTIONS["fisher_fish_per_sec"] * profile_frac
    carry = porters * ASSUMPTIONS["porter_items_per_sec"] + ASSUMPTIONS["player_items_per_sec"]
    # 切魚台:每 processSec 吃 1 魚出 yield 片
    ct = STATIONS["cutting_table"]
    cut_cap = stations["cutting_table"] * float(ct["yield"]) / float(ct["processSec"])
    fillet_supply = min(fish_in * float(ct["yield"]), cut_cap)
    gr = STATIONS["grill"]
    grill_cap = stations["grill"] / float(gr["processSec"])
    kt = STATIONS["kitchen"]
    kitchen_cap = stations["kitchen"] / float(kt["processSec"])
    # 魚片分配:先餵烤魚攤與廚房(高價),剩下的上魚片櫃台
    demand = {}
    for cid in counters:
        c = COUNTERS[cid]
        demand[cid] = customer_demand_per_sec(k)
    grilled_demand = sum(v for cid, v in demand.items() if COUNTERS[cid]["item"] == "grilled")
    soup_demand = sum(v for cid, v in demand.items() if COUNTERS[cid]["item"] == "soup")
    fillet_demand = sum(v for cid, v in demand.items() if COUNTERS[cid]["item"] == "fillet")
    soup = min(kitchen_cap, soup_demand, fillet_supply / 2.0)        # 一碗湯要 1 片 + 1 烤
    fillet_left = fillet_supply - soup * 2.0
    grilled_for_soup = soup
    grilled_total = min(grill_cap, fillet_left)
    grilled_sale = max(0.0, min(grilled_total - grilled_for_soup, grilled_demand))
    fillet_left -= grilled_total
    fillet_sale = max(0.0, min(fillet_left, fillet_demand))
    moved = fillet_sale + grilled_sale + soup * 3.0 + grilled_total
    carry_frac = min(1.0, carry / moved) if moved > 0 else 1.0   # 搬運跟不上就整體打折
    income = (fillet_sale * COUNTERS["fillet_counter"]["price"] + grilled_sale * COUNTERS["grill_counter"]["price"]
              + soup * COUNTERS["soup_counter"]["price"]) * carry_frac
    return {"stage": k, "fishers": fishers, "porters": porters, "fish_per_sec": round(fish_in, 2), "cut_cap": round(cut_cap, 2),
            "fillet_supply": round(fillet_supply, 2), "grill_cap": round(grill_cap, 2), "kitchen_cap": round(kitchen_cap, 2),
            "fillet_demand": round(fillet_demand, 2), "grilled_demand": round(grilled_demand, 2), "soup_demand": round(soup_demand, 2),
            "fillet_sale": round(fillet_sale, 2), "grilled_sale": round(grilled_sale, 2), "soup_sale": round(soup, 2),
            "carry_frac": round(carry_frac, 2), "income_per_min": round(income * 60.0), "next_cost": STAGE_BUILDINGS[k + 1]["cost"] if k + 1 < len(STAGE_BUILDINGS) else 0,
            "avg_want": round(avg_want(k), 2)}


def days_to_stages(profile):
    """每種玩家輪廓到達每個階段的累積天數(擴建錢 = 收入 × (1 - other_sinks) + 離線 0.5 倍)"""
    mins = ASSUMPTIONS["avg_session_min"][profile]
    off_h = min(ASSUMPTIONS["offline_hours"][profile], G["offline"]["maxSec"] / 3600.0)
    out = []
    total_days = 0.0
    for k in range(len(STAGE_BUILDINGS) - 1):
        m = stage_model(k)
        rate = m["income_per_min"] * (1.0 - ASSUMPTIONS["other_sinks_frac"])
        per_day = rate * mins + rate * off_h * 60.0 * float(G["offline"]["rateMult"])
        days = STAGE_BUILDINGS[k + 1]["cost"] / per_day if per_day > 0 else float("inf")
        total_days += days
        out.append({"to_stage": k + 1, "cost": STAGE_BUILDINGS[k + 1]["cost"], "income_per_min": m["income_per_min"], "per_day": round(per_day), "days": round(days, 2), "cum_days": round(total_days, 2)})
    return out


def legacy_points(total):
    lg = G["legacy"]
    return int(math.sqrt(max(total, 0)) / float(lg["pointsDiv"]))


def legacy_estimate(stage, cash_earned, bears, king_kills, chapters, ending=False):
    sc = G["legacy"]["score"]
    stations = sum(sum(n for sid, n in STAGE_BUILDINGS[i].items() if sid in ("cutting_table", "grill", "kitchen", "tailor")) for i in range(stage + 1))
    counters = sum(len(STAGE_BUILDINGS[i]["counters"]) for i in range(stage + 1))
    towers = 6 * (stage + 1) if stage <= 3 else 6 * 4 + 2 * (stage - 3)
    income = cash_earned // G["legacy"]["cashPerPoint"]
    build = sc["expansion"] * stage + sc["tower"] * towers + sc["station"] * max(stations - 1, 0) + sc["counter"] * max(counters - 1, 0)
    battle = sc["bear"] * bears + sum(sc["kingBase"] * (min(i, sc["kingMaxLevel"]) + 1) for i in range(king_kills))
    story = sc["chapter"] * max(chapters - 1, 0) + (sc["ending"] if ending else 0)
    total = income + build + battle + story
    return {"income": income, "build": build, "battle": battle, "story": story, "total": total, "points": legacy_points(total)}


def report():
    lines = []
    p = lines.append
    p("# ManLife 經濟 / 進度模型(tools/balance_model.py 產生)\n")
    p("假設:" + ", ".join("%s=%s" % (k, v) for k, v in ASSUMPTIONS.items() if not isinstance(v, dict)))
    p("\n## 每階段供需與收入(名額僱到 %d%%)\n" % round(ASSUMPTIONS["helpers_hired_frac"] * 100))
    p("| 擴建 | 漁夫 | 搬運 | 魚/s | 切魚上限 | 魚片供給 | 烤魚上限 | 廚房上限 | 魚片需求 | 烤魚需求 | 魚湯需求 | 魚片賣 | 烤魚賣 | 魚湯賣 | 搬運跟得上 | 平均要幾件 | $/分 | 下一次擴建 |")
    p("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for k in range(len(STAGE_BUILDINGS)):
        m = stage_model(k)
        p("| %d | %d | %d | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.0f%% | %.2f | %d | %s |" % (
            k, m["fishers"], m["porters"], m["fish_per_sec"], m["cut_cap"], m["fillet_supply"], m["grill_cap"], m["kitchen_cap"], m["fillet_demand"], m["grilled_demand"],
            m["soup_demand"], m["fillet_sale"], m["grilled_sale"], m["soup_sale"], m["carry_frac"] * 100, m["avg_want"], m["income_per_min"], ("$%d" % m["next_cost"]) if m["next_cost"] else "-"))
    p("\n## 到達每個階段要幾天(擴建錢 = 收入 × (1 - %.0f%%) + 離線五折)\n" % (ASSUMPTIONS["other_sinks_frac"] * 100))
    p("| 到擴建 | 價格 | casual %d 分/天 | median %d 分/天 | hardcore %d 分/天 |" % tuple(ASSUMPTIONS["avg_session_min"][x] for x in ("casual", "median", "hardcore")))
    p("|---|---|---|---|---|")
    rows = {pr: days_to_stages(pr) for pr in ("casual", "median", "hardcore")}
    for i in range(len(rows["median"])):
        r = rows["median"][i]
        p("| %d | $%d | %.1f 天(累計 %.1f) | %.1f 天(累計 %.1f) | %.1f 天(累計 %.1f) |" % (
            r["to_stage"], r["cost"], rows["casual"][i]["days"], rows["casual"][i]["cum_days"], r["days"], r["cum_days"], rows["hardcore"][i]["days"], rows["hardcore"][i]["cum_days"]))
    p("\n## 僱用牌階梯(cost × costMult^i,七次擴建後的名額)\n")
    p("| 角色 | 名額 | 第 1 位 | 第 5 位 | 第 10 位 | 最後一位 | 買滿累計 |")
    p("|---|---|---|---|---|---|---|")
    for role in ("fisher", "porter", "cashier"):
        n = hire_slots(role, 7)
        lad = hire_ladder_cost(role, n)
        p("| %s | %d | $%d | $%s | $%s | $%s | $%s |" % (role, n, lad[0], "{:,}".format(lad[4]) if n >= 5 else "-", "{:,}".format(lad[9]) if n >= 10 else "-", "{:,}".format(lad[-1]), "{:,}".format(sum(lad))))
    p("\n## 傳承點數(一輪結束在哪個階段)\n")
    p("| 停在擴建 | 累積收入 | 熊 | 王 | 章節 | 收入分 | 建設分 | 戰績分 | 故事分 | 總分 | 點數 |")
    p("|---|---|---|---|---|---|---|---|---|---|---|")
    for stage, cash, bears, kings, ch, end in [(1, 3000, 10, 0, 2, False), (3, 25000, 60, 2, 4, False), (4, 60000, 120, 5, 5, False), (7, 250000, 300, 10, 7, True)]:
        e = legacy_estimate(stage, cash, bears, kings, ch, end)
        p("| %d | $%s | %d | %d | %d | %d | %d | %d | %d | %d | %d |" % (stage, "{:,}".format(cash), bears, kings, ch, e["income"], e["build"], e["battle"], e["story"], e["total"], e["points"]))
    p("\n## 敏感度(median 到第 7 次擴建的累計天數,各槓桿 ±20%)\n")
    base = days_to_stages("median")[-1]["cum_days"]
    p("| 槓桿 | -20% | 基準 | +20% |")
    p("|---|---|---|---|")
    for key, label in [("fisher_fish_per_sec", "漁夫抓魚速率"), ("porter_items_per_sec", "搬運工搬運速率"), ("other_sinks_frac", "其他支出比例")]:
        v = ASSUMPTIONS[key]
        ASSUMPTIONS[key] = v * 0.8
        lo = days_to_stages("median")[-1]["cum_days"]
        ASSUMPTIONS[key] = v * 1.2
        hi = days_to_stages("median")[-1]["cum_days"]
        ASSUMPTIONS[key] = v
        p("| %s | %.1f 天 | %.1f 天 | %.1f 天 |" % (label, lo, base, hi))
    for key, label in [("spawnIntervalSec", "顧客來客間隔")]:
        v = G["customers"][key]
        G["customers"][key] = v * 0.8
        lo = days_to_stages("median")[-1]["cum_days"]
        G["customers"][key] = v * 1.2
        hi = days_to_stages("median")[-1]["cum_days"]
        G["customers"][key] = v
        p("| %s | %.1f 天 | %.1f 天 | %.1f 天 |" % (label, lo, base, hi))
    return "\n".join(lines)


if __name__ == "__main__":
    if "--json" in sys.argv:
        print(json.dumps({"stages": [stage_model(k) for k in range(len(STAGE_BUILDINGS))], "days": {pr: days_to_stages(pr) for pr in ("casual", "median", "hardcore")}}, ensure_ascii=False, indent=1))
    else:
        sys.stdout.reconfigure(encoding="utf-8")
        print(report())
