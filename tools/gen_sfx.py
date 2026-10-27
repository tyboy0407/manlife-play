"""產生占位音效到 assets/sfx/*.wav(22050 Hz、16-bit、單聲道)。正式音效同名覆蓋即可換掉。
用法:python tools/gen_sfx.py
"""
import math
import os
import random
import struct
import wave

SR = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sfx")


def seconds(n):
    return int(SR * n)


def tone(freq, dur, vol=1.0, decay=10.0, sweep_to=None, harmonics=((1, 1.0),), attack=0.004):
    """正弦音:decay 越大消失越快;sweep_to 給了就從 freq 滑到 sweep_to;harmonics = [(倍頻, 音量)]。"""
    n = seconds(dur)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = freq if sweep_to is None else freq + (sweep_to - freq) * (i / max(n - 1, 1))
        phase += 2 * math.pi * f / SR
        env = math.exp(-decay * t) * min(1.0, t / attack if attack > 0 else 1.0)
        s = 0.0
        for mult, amp in harmonics:
            s += amp * math.sin(phase * mult)
        out[i] = s * env * vol
    return out


def noise(dur, vol=1.0, decay=10.0, lowpass=1.0, attack=0.002):
    """白噪音 + 一階低通(lowpass 1 = 不濾,越小越悶)。"""
    n = seconds(dur)
    out = [0.0] * n
    y = 0.0
    for i in range(n):
        t = i / SR
        y += lowpass * (random.uniform(-1, 1) - y)
        env = math.exp(-decay * t) * min(1.0, t / attack if attack > 0 else 1.0)
        out[i] = y * env * vol
    return out


def delay(samples, sec):
    return [0.0] * seconds(sec) + samples


def mix(*parts):
    n = max(len(p) for p in parts)
    out = [0.0] * n
    for p in parts:
        for i, v in enumerate(p):
            out[i] += v
    return out


def normalize(samples, peak=0.8):
    m = max(1e-6, max(abs(v) for v in samples))
    return [v / m * peak for v in samples]


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in samples)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print("%-16s %5.2fs" % (name, len(samples) / SR))


def ambient(dur=8.0):
    """海浪(低通噪音、週期 4 秒的起伏)+ 風(更悶的噪音、週期 8 秒),頭尾交叉淡化方便循環。"""
    n = seconds(dur)
    out = [0.0] * n
    yw = 0.0
    yd = 0.0
    for i in range(n):
        t = i / SR
        yw += 0.08 * (random.uniform(-1, 1) - yw)
        yd += 0.015 * (random.uniform(-1, 1) - yd)
        wave_env = (0.55 + 0.45 * math.sin(2 * math.pi * t / 4.0)) ** 2
        wind_env = 0.6 + 0.4 * math.sin(2 * math.pi * t / 8.0 + 1.0)
        out[i] = yw * wave_env * 0.9 + yd * wind_env * 1.6
    fade = seconds(0.25)
    for i in range(fade):
        k = i / fade
        out[i] = out[i] * k + out[n - fade + i] * (1 - k)
    return out[: n - fade]


def main():
    random.seed(7)
    write("catch", normalize(tone(500, 0.10, decay=22, sweep_to=1000, harmonics=((1, 1.0), (2, 0.3)))))
    write("drop", normalize(mix(tone(170, 0.14, decay=28, harmonics=((1, 1.0), (2, 0.4))),
                                noise(0.04, 0.5, decay=60, lowpass=0.3))))
    write("pick", normalize(tone(900, 0.06, decay=45, harmonics=((1, 1.0), (2, 0.5)))))
    write("sale", normalize(mix(tone(988, 0.35, 0.8, decay=9, harmonics=((1, 1.0), (3, 0.15))),
                                delay(tone(1319, 0.3, 0.8, decay=9, harmonics=((1, 1.0), (3, 0.15))), 0.11))))
    write("coin", normalize(mix(tone(2093, 0.07, decay=40), tone(2637, 0.06, 0.6, decay=45))))
    write("pay", normalize(mix(noise(0.03, 0.6, decay=80, lowpass=0.6), tone(1400, 0.035, 0.8, decay=60))))
    write("unlock", normalize(mix(*[delay(tone(f, 0.55, 0.7, decay=6, harmonics=((1, 1.0), (2, 0.25))), 0.1 * i)
                                    for i, f in enumerate((523, 659, 784, 1047))])))
    write("hire", normalize(mix(tone(880, 0.16, decay=12, sweep_to=1175), delay(tone(1175, 0.2, decay=10), 0.14))))
    write("trash", normalize(noise(0.16, 1.0, decay=18, lowpass=0.25)))
    write("goal", normalize(mix(tone(1319, 0.12, decay=18), delay(tone(1760, 0.2, decay=14), 0.08))))
    # 北極熊吼叫:低頻鋸齒般的和聲往下滑 + 悶噪音
    write("roar", normalize(mix(tone(110, 0.8, 1.0, decay=3.5, sweep_to=70, harmonics=((1, 1.0), (2, 0.6), (3, 0.35), (5, 0.15)), attack=0.03),
                                noise(0.7, 0.5, decay=4, lowpass=0.08, attack=0.03))))
    # 咬一口:短促的悶噪音 + 低音撞擊
    write("chomp", normalize(mix(noise(0.12, 1.0, decay=30, lowpass=0.2), tone(120, 0.18, 0.8, decay=25, sweep_to=60),
                                 delay(noise(0.08, 0.6, decay=50, lowpass=0.3), 0.09))))
    # 打到熊:短促的悶擊 + 一點高頻
    write("hit", normalize(mix(noise(0.07, 1.0, decay=45, lowpass=0.35), tone(220, 0.09, 0.7, decay=40, sweep_to=140),
                               tone(1800, 0.03, 0.3, decay=90))))
    write("ambient_waves", normalize(ambient(), peak=0.6))


if __name__ == "__main__":
    main()
