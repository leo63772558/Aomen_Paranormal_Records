"""Defringe white-halo cutouts and build Stage 1B horror BGM, monster roar, and material pickup audio."""
import math
import os
import random
import struct
import wave
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def defringe_sprite(rel_path: str) -> int:
    path = ROOT / rel_path
    if not path.exists():
        return 0
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()
    fixed = 0
    # Pass 1: remove isolated bright near-white fringe pixels next to transparent pixels
    to_clear = []
    to_darken = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            near_trans = False
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] < 24:
                        near_trans = True
                        break
                if near_trans:
                    break
            if not near_trans:
                continue
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            if a < 180 and lum > 155:
                to_clear.append((x, y))
            elif lum > 195 and max(r, g, b) - min(r, g, b) < 35:
                to_clear.append((x, y))
            elif lum > 160 and a < 245:
                to_darken.append((x, y, int(r * 0.45), int(g * 0.45), int(b * 0.42), int(a * 0.55)))
    for x, y in to_clear:
        px[x, y] = (0, 0, 0, 0)
        fixed += 1
    for x, y, r, g, b, a in to_darken:
        px[x, y] = (r, g, b, a)
        fixed += 1
    # Pass 2: clean any newly exposed 1px white halo
    to_clear2 = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 10:
                continue
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            if lum > 205 and max(r, g, b) - min(r, g, b) < 30:
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] < 15:
                            to_clear2.append((x, y))
                            break
                    else:
                        continue
                    break
    for x, y in to_clear2:
        px[x, y] = (0, 0, 0, 0)
        fixed += 1
    im.save(path)
    return fixed


def write_wav(path: Path, samples: list[float], sr: int = 22050) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = max((abs(s) for s in samples), default=1.0)
    scale = 0.92 / max(peak, 1e-6)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        frames = bytearray()
        for s in samples:
            v = max(-32767, min(32767, int(s * scale * 32767.0)))
            frames += struct.pack("<h", v)
        wf.writeframes(frames)


def lowpass(samples: list[float], alpha: float) -> list[float]:
    out = []
    acc = 0.0
    for s in samples:
        acc += alpha * (s - acc)
        out.append(acc)
    return out


def build_monster_roar(path: Path, sr: int = 22050) -> None:
    """Deep distorted demonic roar + sub-bass slam + guttural crunch (ZERO female screech)."""
    rng = random.Random(20261121)
    dur = 1.35
    n = int(sr * dur)
    raw = [0.0] * n
    # Layer 1: heavy chest-punch sub-bass drop (115 Hz -> 34 Hz)
    phase1 = 0.0
    phase2 = 0.0
    for i in range(n):
        t = i / sr
        env = min(1.0, t / 0.025) * math.exp(-t * 2.4)
        f1 = 38.0 + 78.0 * math.exp(-t * 6.5)
        f2 = 71.0 + 35.0 * math.sin(t * 27.0) * math.exp(-t * 2.0)
        phase1 += 2.0 * math.pi * f1 / sr
        phase2 += 2.0 * math.pi * f2 / sr
        growl = math.tanh(2.8 * (math.sin(phase1) + 0.65 * math.sin(phase2) + 0.45 * math.sin(phase2 * 1.49)))
        # Guttural throat rasp (band-shaped noise modulated at ~34 Hz)
        rasp = (rng.random() * 2.0 - 1.0) * (0.55 + 0.45 * math.sin(2.0 * math.pi * 34.0 * t))
        # Bone-crack transient in first 120ms
        crack = (rng.random() * 2.0 - 1.0) * math.exp(-t * 26.0) * 1.4
        raw[i] = (growl * 0.72 + rasp * 0.42) * env + crack * 0.55
    # Lowpass so zero harsh high-frequency female-like screech remains
    lp = lowpass(raw, 0.24)
    # Add back a touch of mid-crunch for impact clarity
    out = [lp[i] * 0.85 + math.tanh(raw[i] * 1.3) * 0.18 * math.exp(-(i / sr) * 4.0) for i in range(n)]
    write_wav(path, out, sr)


def build_horror_bgm(path: Path, base_freq: float, mood_seed: int, sr: int = 22050) -> None:
    """Loopable dark ambient horror drone with slow bowed dissonance & distant room resonance."""
    rng = random.Random(mood_seed)
    dur = 12.0
    n = int(sr * dur)
    # Use integer cycles over 12 seconds for seamless zero-click looping!
    f_root = round(base_freq * dur) / dur
    f_minor2 = round((base_freq * 1.0595) * dur) / dur
    f_tritone = round((base_freq * 1.4142) * dur) / dur
    f_sub = round((base_freq * 0.5) * dur) / dur
    noise_buf = [rng.random() * 2.0 - 1.0 for _ in range(n)]
    room_air = lowpass(lowpass(noise_buf, 0.05), 0.08)
    out = [0.0] * n
    for i in range(n):
        t = i / sr
        swell1 = 0.5 + 0.5 * math.sin(2.0 * math.pi * (1.0 / dur) * t)
        swell2 = 0.5 + 0.5 * math.sin(2.0 * math.pi * (2.0 / dur) * t + 1.1)
        swell3 = 0.5 + 0.5 * math.sin(2.0 * math.pi * (3.0 / dur) * t + 2.4)
        sub = math.sin(2.0 * math.pi * f_sub * t) * 0.36
        root = math.sin(2.0 * math.pi * f_root * t) * (0.24 + 0.14 * swell1)
        # Eerie bowed dissonance that swells softly and recedes
        dissonance = math.sin(2.0 * math.pi * f_minor2 * t) * 0.11 * swell2
        tritone = math.sin(2.0 * math.pi * f_tritone * t) * 0.12 * swell3
        # Soft dark harmonic warmth
        harm = math.sin(2.0 * math.pi * (f_root * 2.0) * t) * 0.05 * swell1
        out[i] = sub + root + dissonance + tritone + harm + room_air[i] * 0.42
    # Gentle smoothing + loop edge cross-safety
    out = lowpass(out, 0.18)
    write_wav(path, out, sr)


def build_pickup_sfx(sr: int = 22050) -> None:
    rng = random.Random(7788)
    # 1. Coin clink (MOP 1 pataca coin)
    n = int(sr * 0.38)
    coin = []
    for i in range(n):
        t = i / sr
        env = math.exp(-t * 14.0)
        sig = (math.sin(2 * math.pi * 2420 * t) * 0.5 +
               math.sin(2 * math.pi * 3870 * t) * 0.35 +
               math.sin(2 * math.pi * 6120 * t) * 0.25) * env
        if t > 0.065:
            t2 = t - 0.065
            sig += (math.sin(2 * math.pi * 2460 * t2) * 0.35 + math.sin(2 * math.pi * 3910 * t2) * 0.25) * math.exp(-t2 * 18.0)
        coin.append(sig)
    write_wav(ROOT / "assets/audio/demo/pickup_coin.wav", coin, sr)

    # 2. Ceramic fuse clink
    n = int(sr * 0.26)
    cer = []
    for i in range(n):
        t = i / sr
        env = math.exp(-t * 28.0)
        sig = (math.sin(2 * math.pi * 1680 * t) * 0.55 + math.sin(2 * math.pi * 2940 * t) * 0.4 + (rng.random() * 2 - 1) * 0.25) * env
        cer.append(sig)
    write_wav(ROOT / "assets/audio/demo/pickup_ceramic.wav", cer, sr)

    # 3. Stone pickup (gritty thud)
    n = int(sr * 0.24)
    st = [(rng.random() * 2 - 1) * math.exp(-(i / sr) * 24.0) for i in range(n)]
    st = lowpass(st, 0.28)
    write_wav(ROOT / "assets/audio/demo/pickup_stone.wav", st, sr)

    # 4. Camera / plastic click pickup
    n = int(sr * 0.28)
    cam = []
    for i in range(n):
        t = i / sr
        click1 = (rng.random() * 2 - 1) * math.exp(-t * 85.0)
        click2 = (rng.random() * 2 - 1) * math.exp(-max(0.0, t - 0.055) * 70.0) if t >= 0.055 else 0.0
        cam.append(click1 * 0.8 + click2 * 0.65)
    cam = lowpass(cam, 0.45)
    write_wav(ROOT / "assets/audio/demo/pickup_camera.wav", cam, sr)


if __name__ == "__main__":
    f1 = defringe_sprite("assets/props/annex_hardware_046.png")
    f2 = defringe_sprite("assets/props/bus_window_hands.png")
    print(f"Defringed annex_hardware_046.png: {f1} px, bus_window_hands.png: {f2} px")
    build_monster_roar(ROOT / "assets/audio/demo/jumpscare_shriek_122.wav")
    build_horror_bgm(ROOT / "assets/audio/demo/bgm_tenement_horror.wav", 65.4, 101)
    build_horror_bgm(ROOT / "assets/audio/demo/bgm_crypt_drone.wav", 55.0, 202)
    build_horror_bgm(ROOT / "assets/audio/demo/bgm_bunker_dread.wav", 49.0, 303)
    build_pickup_sfx()
    print("Built monster roar, 3 horror exploration BGMs, and 4 pickup foley WAVs.")
