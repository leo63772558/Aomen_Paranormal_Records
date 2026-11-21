"""Generate documented procedural replacements for chase_urgent_122.wav (160 BPM intense horror chase) and jumpscare_shriek_122.wav."""
from math import exp, pi, sin, tanh
from pathlib import Path
from random import Random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "audio" / "demo"
RATE = 24_000


def write_wav(name: str, samples: list[float]) -> None:
    peak = max(abs(sample) for sample in samples) or 1.0
    gain = min(1.0, 0.88 / peak)
    payload = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, sample * gain)) * 32767))
        for sample in samples
    )
    with wave.open(str(OUT / name), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(payload)


def build_chase_loop() -> None:
    # 160 BPM -> 1 beat = 0.375s, 16 beats = 6.0s seamless loop (or 8.0s with 0.25s = 240 sixteenth grid)
    duration = 6.0
    count = round(RATE * duration)
    rng = Random(122041)
    lp_noise = 0.0
    bp_noise = 0.0
    samples: list[float] = []
    beat_len = 0.375  # 160 BPM
    sixteenth = beat_len / 4.0

    for index in range(count):
        t = index / RATE
        beat_idx = int(t / beat_len)
        beat_pos = t % beat_len
        sub_idx = int(t / sixteenth) % 16
        sub_pos = t % sixteenth

        # 1. Pounding 160 BPM horror kick + syncopated tom slams (audible on all speakers)
        kick_env = exp(-beat_pos * 18.0)
        kick_freq = 62.0 + 115.0 * exp(-beat_pos * 48.0)
        kick = 0.52 * sin(2 * pi * kick_freq * beat_pos) * kick_env

        # Syncopated off-beat panic tom / heartbeat slam on 16th steps 2, 3, 6, 10, 11, 14, 15
        tom = 0.0
        if sub_idx in (2, 3, 6, 10, 11, 14, 15):
            tom_env = exp(-sub_pos * 26.0)
            tom_freq = (95.0 if sub_idx % 2 == 0 else 128.0) + 80.0 * exp(-sub_pos * 55.0)
            tom = 0.38 * sin(2 * pi * tom_freq * sub_pos) * tom_env

        # 2. Metallic industrial clank on every half-beat (off-beat urgency)
        noise = rng.uniform(-1.0, 1.0)
        lp_noise = 0.88 * lp_noise + 0.12 * noise
        hp_noise = noise - lp_noise
        bp_noise = 0.72 * bp_noise + 0.28 * hp_noise

        clank = 0.0
        if sub_idx in (4, 8, 12, 14):
            clank_env = exp(-sub_pos * 34.0)
            clank = clank_env * (
                0.26 * hp_noise
                + 0.18 * sin(2 * pi * 465.0 * sub_pos)
                + 0.14 * sin(2 * pi * 712.0 * sub_pos)
            )

        # 3. Urgent 16th-note shaker/breath rush
        rush_env = exp(-sub_pos * 38.0) * (0.22 if sub_idx % 2 == 1 else 0.12)
        rush = rush_env * bp_noise

        # 4. Dissonant horror string/brass tension stabs (minor 2nd + tritone tremolo)
        tremolo = 0.65 + 0.35 * sin(2 * pi * 16.0 * t)
        bar_rise = 0.70 + 0.30 * ((t % 3.0) / 3.0)
        base_f = 146.8 if (beat_idx // 4) % 2 == 0 else 155.6
        tritone_f = 207.65 if (beat_idx // 4) % 2 == 0 else 220.0
        shriek_f = 311.1 + 12.0 * sin(2 * pi * 4.5 * t)
        strings = bar_rise * tremolo * (
            0.16 * tanh(2.2 * sin(2 * pi * base_f * t))
            + 0.14 * tanh(2.2 * sin(2 * pi * tritone_f * t + 0.4))
            + 0.09 * sin(2 * pi * shriek_f * t)
        )

        sample = tanh((kick + tom + clank + rush + strings) * 1.25)
        samples.append(sample)

    seam = (samples[0] + samples[-1]) * 0.5
    samples[0] = samples[-1] = seam
    write_wav("chase_urgent_122.wav", samples)


def build_synthetic_shriek() -> None:
    duration = 2.2
    count = round(RATE * duration)
    rng = Random(122042)
    phases = [0.0] * 10
    previous_noise = 0.0
    samples: list[float] = []
    for index in range(count):
        t = index / RATE
        if t < 0.22:
            base = 460.0 + (1340.0 - 460.0) * t / 0.22
        elif t < 0.88:
            base = 1340.0
        else:
            base = 1340.0 - 620.0 * (t - 0.88) / (duration - 0.88)
        f0 = base * (1.0 + 0.025 * sin(2 * pi * 9.5 * t))
        tonal = 0.0
        for harmonic in range(1, len(phases)):
            frequency = f0 * harmonic
            formant = (
                0.42
                + 0.82 * exp(-((frequency - 980.0) / 340.0) ** 2)
                + 0.65 * exp(-((frequency - 2240.0) / 580.0) ** 2)
            )
            tonal += sin(phases[harmonic]) * formant / (harmonic ** 1.22)
            phases[harmonic] = (phases[harmonic] + 2 * pi * frequency / RATE) % (2 * pi)
        attack = min(1.0, t / 0.015)
        decay = 1.0 if t < 0.68 else exp(-1.65 * (t - 0.68))
        tail = min(1.0, max(0.0, (duration - t) / 0.12))
        envelope = attack * decay * tail
        noise = rng.uniform(-1.0, 1.0)
        high_noise = noise - previous_noise
        previous_noise = noise
        # Add sudden low-end sub-impact punch at t=0..0.15s
        impact = 0.45 * sin(2 * pi * (95.0 - 300.0 * min(0.15, t)) * t) * exp(-18.0 * t)
        samples.append(envelope * (0.32 * tonal + 0.085 * high_noise) + impact)
    write_wav("jumpscare_shriek_122.wav", samples)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    build_chase_loop()
    build_synthetic_shriek()
    print("Generated 160 BPM horror chase loop and enhanced jumpscare shriek.")
