"""Build v5 realistic horror audio cues, replace female shriek hall_wail_026,
and synthesize atmospheric AM-radio Cantonese pentatonic opera loop for Ch3."""
import math
import random
import struct
import wave
from pathlib import Path

SR = 44100
OUT = Path("d:/Aomen_Paranormal_Records/assets/audio/demo")

def write_wav(path: Path, samples: list[float], sr: int = SR) -> None:
    peak = max((abs(s) for s in samples), default=1.0)
    scale = 0.88 / peak if peak > 0.88 else 1.0
    data = bytearray()
    for s in samples:
        v = max(-1.0, min(1.0, s * scale))
        data += struct.pack("<h", int(v * 32767))
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        wf.writeframes(data)
    print(f"WROTE {path.name} ({len(samples)/sr:.2f}s)")

def lowpass(samples: list[float], cutoff_hz: float, sr: int = SR) -> list[float]:
    rc = 1.0 / (2.0 * math.pi * cutoff_hz)
    dt = 1.0 / sr
    alpha = dt / (rc + dt)
    out = []
    y = 0.0
    for x in samples:
        y = y + alpha * (x - y)
        out.append(y)
    return out

def bandpass(samples: list[float], lo: float, hi: float) -> list[float]:
    lp = lowpass(samples, hi)
    hp_sub = lowpass(lp, lo)
    return [a - b for a, b in zip(lp, hp_sub)]

def build_hall_wail_replacement() -> None:
    # Deep hollow inhuman groan + icy tunnel draft (ZERO female shriek!)
    dur = 2.1
    n = int(SR * dur)
    rng = random.Random(20261121)
    raw = []
    phase1 = 0.0
    phase2 = 0.0
    for i in range(n):
        t = i / SR
        env = math.sin(math.pi * min(1.0, t / dur)) ** 1.3
        f0 = 76.0 - 18.0 * (t / dur) + 3.5 * math.sin(t * 7.5)
        phase1 += 2.0 * math.pi * f0 / SR
        phase2 += 2.0 * math.pi * (f0 * 1.498) / SR
        groan = (math.sin(phase1) * 0.55 + math.sin(phase2) * 0.28 + math.sin(phase1 * 2.02) * 0.16)
        breath = rng.uniform(-1.0, 1.0) * 0.35
        raw.append((groan + breath) * env)
    filtered = lowpass(raw, 420.0)
    # Add gritty sub-bass resonance
    out = [filtered[i] * 0.85 + 0.28 * math.sin(2.0 * math.pi * 46.0 * i / SR) * math.sin(math.pi * i / n) for i in range(n)]
    write_wav(OUT / "hall_wail_026.wav", out)

def build_pickup_oil_can() -> None:
    # Hollow tin clink + brief viscous liquid slosh
    dur = 0.52
    n = int(SR * dur)
    rng = random.Random(77)
    out = []
    for i in range(n):
        t = i / SR
        clink = math.exp(-t * 28.0) * (math.sin(2*math.pi*610*t)*0.45 + math.sin(2*math.pi*1390*t)*0.25)
        slosh_env = math.exp(-((t - 0.22) / 0.11) ** 2) * 0.42
        slosh = rng.uniform(-1.0, 1.0) * slosh_env
        out.append(clink + slosh)
    out = lowpass(out, 2100.0)
    write_wav(OUT / "pickup_oil_can.wav", out)

def build_use_install_snap() -> None:
    # Tactile mechanical brass insertion click + low electrical lock hum
    dur = 0.42
    n = int(SR * dur)
    rng = random.Random(88)
    out = []
    for i in range(n):
        t = i / SR
        click1 = math.exp(-t * 55.0) * (math.sin(2*math.pi*420*t)*0.5 + rng.uniform(-0.4, 0.4))
        click2 = math.exp(-max(0.0, t - 0.11) * 48.0) * (1.0 if t >= 0.11 else 0.0) * (math.sin(2*math.pi*890*t)*0.55 + math.sin(2*math.pi*1650*t)*0.3)
        hum = (1.0 if t >= 0.11 else 0.0) * math.exp(-(t - 0.11) * 7.5) * 0.22 * math.sin(2*math.pi*100*t)
        out.append(click1 + click2 + hum)
    write_wav(OUT / "use_install_snap.wav", lowpass(out, 3200.0))

def build_use_keypad_dead() -> None:
    # Vintage payphone heavy plastic button click + faint dead-line relay thud
    dur = 0.18
    n = int(SR * dur)
    rng = random.Random(99)
    out = []
    for i in range(n):
        t = i / SR
        btn = math.exp(-t * 62.0) * (math.sin(2*math.pi*310*t)*0.5 + math.sin(2*math.pi*1120*t)*0.3 + rng.uniform(-0.35, 0.35))
        rel = math.exp(-max(0.0, t - 0.06) * 52.0) * (1.0 if t >= 0.06 else 0.0) * 0.25 * math.sin(2*math.pi*210*t)
        out.append(btn + rel)
    write_wav(OUT / "use_keypad_dead.wav", lowpass(out, 2400.0))

def build_ghost_taunt_whisper() -> None:
    # Uncanny breathy low ghostly whisper burst
    dur = 1.15
    n = int(SR * dur)
    rng = random.Random(303)
    raw = []
    for i in range(n):
        t = i / SR
        syllables = abs(math.sin(t * 9.2)) * math.sin(math.pi * t / dur)
        noise = rng.uniform(-1.0, 1.0)
        raspy = math.sin(2*math.pi*(118.0 + 18.0*math.sin(t*6.5))*t) * 0.25
        raw.append((noise * 0.72 + raspy) * syllables)
    filt = bandpass(raw, 340.0, 1450.0)
    write_wav(OUT / "ghost_taunt_whisper.wav", filt)

def build_cantonese_opera_radio() -> None:
    # Seamless 8.0s vintage AM-radio Cantonese pentatonic opera loop (gaohu/erhu melody + wooden ban clapper + static)
    dur = 8.0
    n = int(SR * dur)
    rng = random.Random(1985)
    # Cantonese Yiyin / pentatonic mournful phrase (D4, F4, G4, A4, C5, D5, A4, G4, F4, D4, C4, D4)
    notes = [
        (0.0, 0.75, 293.66), (0.75, 0.55, 349.23), (1.30, 0.85, 392.00),
        (2.15, 0.65, 440.00), (2.80, 0.90, 523.25), (3.70, 0.60, 440.00),
        (4.30, 0.80, 392.00), (5.10, 0.70, 349.23), (5.80, 0.95, 293.66),
        (6.75, 0.55, 261.63), (7.30, 0.70, 293.66)
    ]
    raw = [0.0] * n
    for start, length, freq in notes:
        i0 = int(start * SR)
        i1 = min(n, int((start + length) * SR))
        phase = 0.0
        for i in range(i0, i1):
            t = (i - i0) / SR
            env = math.sin(math.pi * min(1.0, t / length)) ** 0.65
            # Expressive Cantonese opera glissando + vibrato
            glide = 1.0 - 0.035 * math.exp(-t * 11.0)
            vib = 1.0 + 0.014 * math.sin(2.0 * math.pi * 5.8 * t)
            phase += 2.0 * math.pi * freq * glide * vib / SR
            # Bowed gaohu harmonic timbre
            bow = (math.sin(phase) * 0.55 + math.sin(phase * 2.0) * 0.32 +
                   math.sin(phase * 3.0) * 0.18 + math.sin(phase * 4.0) * 0.08)
            raw[i] += bow * env * 0.42
    # Traditional wooden clapper (梆子 / 木鱼) beats
    for beat_t in [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0]:
        i0 = int(beat_t * SR)
        for k in range(min(int(0.09 * SR), n - i0)):
            t = k / SR
            clack = math.exp(-t * 48.0) * (math.sin(2*math.pi*980*t)*0.4 + math.sin(2*math.pi*1620*t)*0.25)
            raw[i0 + k] += clack * 0.35
    # Vintage dusty AM radio crackle + gentle static floor
    for i in range(n):
        crackle = rng.uniform(-0.35, 0.35) if rng.random() < 0.002 else 0.0
        raw[i] += rng.uniform(-0.045, 0.045) + crackle
    # AM-radio telephone/tube bandpass (450Hz - 2400Hz)
    radio = bandpass(raw, 420.0, 2400.0)
    # Seamless loop crossfade over 0.12s
    fade = int(0.12 * SR)
    for k in range(fade):
        w = k / fade
        radio[k] = radio[k] * w + radio[n - fade + k] * (1.0 - w)
    write_wav(OUT / "cantonese_opera_radio_v5.wav", radio)

if __name__ == "__main__":
    build_hall_wail_replacement()
    build_pickup_oil_can()
    build_use_install_snap()
    build_use_keypad_dead()
    build_ghost_taunt_whisper()
    build_cantonese_opera_radio()
