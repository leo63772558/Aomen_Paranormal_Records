"""Expand project audio library with realistic dry shoe-sole footsteps (derived from real stone step transients, zero sine-wave beeps), clean ambiences, 8 horror micro-scare & boss battle SFX, and CC0 foley bank."""
from array import array
from math import exp, pi, sin, cos, tanh
from pathlib import Path
from random import Random
import shutil
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
AUDIO_ROOT = ROOT / "assets" / "audio"
DEMO = AUDIO_ROOT / "demo"
FOLEY = AUDIO_ROOT / "foley"
SRC_WM = ROOT / "tools" / "audio_sources" / "wood_metal"
SRC_DOOR = ROOT / "tools" / "audio_sources" / "qubodup-DoorSet" / "qubodup-DoorSet" / "ogg"
RATE = 24000


def read_wav_samples(path: Path) -> list[float]:
    with wave.open(str(path), "rb") as w:
        n = w.getnframes()
        raw = w.readframes(n)
        vals = struct.unpack(f"<{n}h", raw)
        return [v / 32768.0 for v in vals]


def write_wav(path: Path, samples: list[float], max_gain: float = 0.80) -> None:
    peak = max((abs(x) for x in samples), default=0.01)
    gain = min(1.0, max_gain / max(peak, 0.01))
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        w.writeframes(array("h", (int(max(-1.0, min(1.0, x * gain)) * 32700) for x in samples)).tobytes())


def lowpass(samples: list[float], cutoff: float) -> list[float]:
    a = 1.0 - exp(-2.0 * pi * cutoff / RATE)
    y = 0.0
    out = []
    for x in samples:
        y += a * (x - y)
        out.append(y)
    return out


def highpass(samples: list[float], cutoff: float) -> list[float]:
    lp = lowpass(samples, cutoff)
    return [x - y for x, y in zip(samples, lp)]


def build_synthesized_cues() -> None:
    rng = Random(20261121)

    # Load the confirmed real dry shoe-sole waveforms from step_stone_0..3.wav
    base_steps = []
    for idx in range(4):
        p = AUDIO_ROOT / f"step_stone_{idx}.wav"
        if p.exists():
            base_steps.append(read_wav_samples(p))

    # 1. Heartbeat tension loop (1.2s, faster 100 BPM deep chest thump, no high beep)
    hb_len = int(1.2 * RATE)
    hb = [0.0] * hb_len
    for start, freq, amp in [(0.05, 48.0, 0.88), (0.23, 40.0, 0.66), (0.65, 48.0, 0.88), (0.83, 40.0, 0.66)]:
        idx0 = int(start * RATE)
        for i in range(int(0.16 * RATE)):
            t = i / RATE
            if idx0 + i < hb_len:
                hb[idx0 + i] += amp * sin(2 * pi * freq * t) * exp(-20.0 * t)
    write_wav(DEMO / "heartbeat_tension.wav", hb)

    # 2. Hac Sa Beach waves + night wind ambience (4.0s loop)
    b_len = int(4.0 * RATE)
    noise = [rng.uniform(-1.0, 1.0) for _ in range(b_len)]
    surf = lowpass(noise, 380.0)
    beach = []
    for i in range(b_len):
        t = i / RATE
        swell = 0.35 + 0.30 * sin(2 * pi * t / 4.0) + 0.12 * cos(4 * pi * t / 4.0)
        beach.append(surf[i] * swell)
    write_wav(DEMO / "beach_waves_ambience.wav", beach, 0.65)

    # 3. Macau old street night ambience (3.6s loop — pure night air & distant harbor rumble, NO 880Hz sine beep!)
    s_len = int(3.6 * RATE)
    s_noise = lowpass([rng.uniform(-1.0, 1.0) for _ in range(s_len)], 210.0)
    breeze = highpass(lowpass([rng.uniform(-1.0, 1.0) for _ in range(s_len)], 540.0), 140.0)
    street = []
    for i in range(s_len):
        t = i / RATE
        gust = 0.45 + 0.35 * sin(2 * pi * t / 3.6)
        street.append(s_noise[i] * 0.32 + breeze[i] * 0.18 * gust)
    write_wav(DEMO / "street_macau_ambience.wav", street, 0.48)

    # 4. Valve turn heavy creak + water rush (0.65s)
    v_len = int(0.65 * RATE)
    v_noise = lowpass([rng.uniform(-1.0, 1.0) for _ in range(v_len)], 780.0)
    valve = []
    for i in range(v_len):
        t = i / RATE
        creak = 0.28 * tanh(2.5 * sin(2 * pi * (175.0 + 28.0 * sin(16.0 * t)) * t)) * exp(-3.5 * t)
        clunk = 0.55 * v_noise[i] * exp(-22.0 * abs(t - 0.50))
        valve.append(creak + clunk + v_noise[i] * 0.25)
    write_wav(DEMO / "valve_turn_heavy.wav", valve)

    # 5. Valve resisted backflow clank (0.48s)
    r_len = int(0.48 * RATE)
    r_noise = lowpass([rng.uniform(-1.0, 1.0) for _ in range(r_len)], 1100.0)
    resist = []
    for i in range(r_len):
        t = i / RATE
        impact = r_noise[i] * (exp(-18.0 * t) + 0.7 * exp(-24.0 * abs(t - 0.22)))
        resist.append(impact)
    write_wav(DEMO / "valve_resist_clank.wav", resist)

    # 6. Realistic dry shoe-sole surface footsteps (derived from real step_stone transients, ZERO pure sine tones!)
    for idx in range(2):
        src = base_steps[idx % len(base_steps)] if base_steps else [rng.uniform(-1.0, 1.0) * exp(-18.0 * (i / RATE)) for i in range(int(0.25 * RATE))]
        n_len = len(src)
        raw = [rng.uniform(-1.0, 1.0) for _ in range(n_len)]

        # Wood: warm low-pass filtered dry shoe sole + natural short room reflection (8ms delay)
        wood_lp = lowpass(src, 620.0 + idx * 70.0)
        delay = int(0.007 * RATE)
        wood = []
        for i in range(n_len):
            refl = wood_lp[i - delay] * 0.36 if i >= delay else 0.0
            wood.append(wood_lp[i] * 0.85 + refl)
        write_wav(DEMO / f"step_wood_{idx}.wav", wood, 0.68)

        # Sand: soft dry sole + crisp high-passed sand grain rustle envelope
        sand_grain = highpass(lowpass(raw, 2600.0), 650.0)
        sand_sole = lowpass(src, 480.0)
        sand = []
        for i in range(n_len):
            t = i / RATE
            env = sin(pi * min(1.0, t / 0.16)) * exp(-9.5 * t)
            sand.append(sand_sole[i] * 0.55 + sand_grain[i] * 0.38 * env)
        write_wav(DEMO / f"step_sand_{idx}.wav", sand, 0.62)

        # Water / wet puddle: dry sole + broadband droplet splash tail
        splash_noise = highpass(lowpass(raw, 3400.0), 850.0)
        water = []
        for i in range(n_len):
            t = i / RATE
            splash_env = exp(-11.0 * max(0.0, t - 0.015)) * (1.0 if t >= 0.01 else t / 0.01)
            water.append(src[i] * 0.65 + splash_noise[i] * 0.42 * splash_env)
        write_wav(DEMO / f"step_water_{idx}.wav", water, 0.66)

        # Metal: crisp high-passed dry sole + short 3.5ms comb reflection (no pitched sine beep!)
        metal_hp = highpass(src, 220.0)
        m_delay = int(0.0034 * RATE)
        metal = []
        for i in range(n_len):
            comb = metal_hp[i - m_delay] * 0.42 if i >= m_delay else 0.0
            comb2 = metal_hp[i - m_delay * 2] * 0.18 if i >= m_delay * 2 else 0.0
            metal.append(src[i] * 0.50 + metal_hp[i] * 0.45 + comb + comb2)
        write_wav(DEMO / f"step_metal_{idx}.wav", metal, 0.68)

    # 7. Horror Micro-Scare & Final Boss Battle Cues
    # 7a. scare_bulb_pop.wav (0.45s electrical snap + glass pop)
    pop_len = int(0.45 * RATE)
    pop_raw = [rng.uniform(-1.0, 1.0) for _ in range(pop_len)]
    pop_hp = highpass(pop_raw, 1400.0)
    bulb_pop = [pop_hp[i] * (exp(-45.0 * (i / RATE)) + 0.65 * exp(-80.0 * abs((i / RATE) - 0.06))) for i in range(pop_len)]
    write_wav(DEMO / "scare_bulb_pop.wav", bulb_pop, 0.82)

    # 7b. scare_door_bang.wav (0.75s heavy sudden door pound)
    bang_len = int(0.75 * RATE)
    bang_raw = lowpass([rng.uniform(-1.0, 1.0) for _ in range(bang_len)], 320.0)
    door_bang = []
    for i in range(bang_len):
        t = i / RATE
        hit1 = exp(-19.0 * t) * (bang_raw[i] * 0.8 + 0.5 * sin(2 * pi * (68.0 - 110.0 * min(0.1, t)) * t))
        hit2 = exp(-22.0 * abs(t - 0.24)) * bang_raw[i] * 0.65 if t >= 0.20 else 0.0
        door_bang.append(hit1 + hit2)
    write_wav(DEMO / "scare_door_bang.wav", door_bang, 0.86)

    # 7c. scare_extra_step.wav (0.38s eerie close behind-you step)
    if base_steps:
        extra = [x * 0.95 for x in base_steps[0]]
    else:
        extra = [rng.uniform(-1.0, 1.0) * exp(-16.0 * (i / RATE)) for i in range(int(0.30 * RATE))]
    write_wav(DEMO / "scare_extra_step.wav", extra, 0.82)

    # 7d. scare_whisper_ear.wav (0.95s breathy reversed hush)
    w_len = int(0.95 * RATE)
    w_raw = highpass(lowpass([rng.uniform(-1.0, 1.0) for _ in range(w_len)], 1900.0), 520.0)
    whisper = []
    for i in range(w_len):
        t = i / RATE
        env = exp(-10.0 * ((t - 0.42) ** 2)) * (0.6 + 0.4 * sin(2 * pi * 11.0 * t))
        whisper.append(w_raw[i] * env)
    write_wav(DEMO / "scare_whisper_ear.wav", whisper, 0.72)

    # 7e. scare_pipe_scrape.wav (0.80s metallic pipe groan/scrape)
    p_len = int(0.80 * RATE)
    p_raw = highpass(lowpass([rng.uniform(-1.0, 1.0) for _ in range(p_len)], 2200.0), 400.0)
    pipe_scrape = [p_raw[i] * sin(pi * min(1.0, (i / RATE) / 0.75)) * (0.5 + 0.5 * sin(2 * pi * 24.0 * (i / RATE))) for i in range(p_len)]
    write_wav(DEMO / "scare_pipe_scrape.wav", pipe_scrape, 0.75)

    # 7f. scare_radio_static.wav (0.70s sudden radio static burst + cutoff)
    rs_len = int(0.70 * RATE)
    rs_raw = highpass(lowpass([rng.uniform(-1.0, 1.0) for _ in range(rs_len)], 2800.0), 350.0)
    radio_static = [rs_raw[i] * (0.85 if 0.02 <= (i / RATE) <= 0.58 else exp(-40.0 * abs((i / RATE) - 0.60))) for i in range(rs_len)]
    write_wav(DEMO / "scare_radio_static.wav", radio_static, 0.74)

    # 7g. electric_arc_blast.wav (0.90s high-voltage discharge explosion for Final Boss)
    arc_len = int(0.90 * RATE)
    arc_raw = [rng.uniform(-1.0, 1.0) for _ in range(arc_len)]
    arc_hp = highpass(arc_raw, 900.0)
    arc = []
    for i in range(arc_len):
        t = i / RATE
        boom = 0.65 * sin(2 * pi * (82.0 - 150.0 * min(0.2, t)) * t) * exp(-10.0 * t)
        zaps = arc_hp[i] * exp(-3.8 * t) * (0.6 + 0.4 * sin(2 * pi * 55.0 * t))
        arc.append(tanh((boom + zaps) * 1.4))
    write_wav(DEMO / "electric_arc_blast.wav", arc, 0.88)

    # 7h. boss_roar_impact.wav (1.15s concrete-shattering sub-bass roar for Final Boss)
    br_len = int(1.15 * RATE)
    br_raw = lowpass([rng.uniform(-1.0, 1.0) for _ in range(br_len)], 480.0)
    roar = []
    for i in range(br_len):
        t = i / RATE
        env = min(1.0, t / 0.04) * exp(-2.4 * max(0.0, t - 0.15))
        growl = 0.55 * tanh(2.5 * sin(2 * pi * (64.0 - 18.0 * t) * t + 1.5 * br_raw[i]))
        roar.append(env * (growl + br_raw[i] * 0.55))
    write_wav(DEMO / "boss_roar_impact.wav", roar, 0.88)


def copy_foley_bank() -> int:
    FOLEY.mkdir(parents=True, exist_ok=True)
    copied = 0
    if SRC_WM.exists():
        for f in sorted(SRC_WM.glob("*.ogg")):
            shutil.copy2(f, FOLEY / f.name)
            copied += 1
    if SRC_DOOR.exists():
        for f in sorted(SRC_DOOR.glob("*.ogg")):
            shutil.copy2(f, FOLEY / f.name)
            copied += 1
    return copied


if __name__ == "__main__":
    build_synthesized_cues()
    count = copy_foley_bank()
    print(f"Built realistic footsteps, clean ambiences, 8 horror/boss SFX, and copied {count} CC0 foley files.")
