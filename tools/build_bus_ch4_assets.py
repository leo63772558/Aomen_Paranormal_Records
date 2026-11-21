"""
High-fidelity Asset Generator for Chapter 4 Bus 33 Exit 8 Loop.
Builds 005-standard horror RPG textures, props, anomalies and audio stingers.
"""
import math
import random
import struct
import wave
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
AUDIO_DIR = ROOT / "assets" / "audio" / "demo"
TILE_DIR = ROOT / "assets" / "tilesets"
PROP_DIR = ROOT / "assets" / "props"

AUDIO_DIR.mkdir(parents=True, exist_ok=True)
TILE_DIR.mkdir(parents=True, exist_ok=True)
PROP_DIR.mkdir(parents=True, exist_ok=True)

RATE = 24000

def write_wav(path: Path, samples: list[float]):
    with wave.open(str(path), 'w') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        data = bytearray()
        for s in samples:
            val = max(-32767, min(32767, int(s * 32767.0)))
            data.extend(struct.pack('<h', val))
        f.writeframes(data)

def gen_audio():
    # 1. bridge_bus_ambience.wav
    duration = 4.0
    total = int(RATE * duration)
    samples = [0.0] * total
    rnd = random.Random(4433)
    for i in range(total):
        t = i / RATE
        vib = 1.0 + 0.05 * math.sin(2 * math.pi * 3.2 * t)
        eng = 0.24 * math.sin(2 * math.pi * 56.0 * vib * t) + \
              0.16 * math.sin(2 * math.pi * 112.0 * vib * t) + \
              0.09 * math.sin(2 * math.pi * 168.0 * t) + \
              0.05 * math.sin(2 * math.pi * 224.0 * t)
        wind = (rnd.random() * 2.0 - 1.0) * 0.14
        joint_phase = (t % 1.33)
        joint = 0.0
        if joint_phase < 0.09:
            env = math.exp(-joint_phase * 50.0)
            joint = 0.3 * math.sin(2 * math.pi * 140.0 * joint_phase) * env
        samples[i] = eng + wind + joint
    # xfade loop
    xf = int(RATE * 0.25)
    for i in range(xf):
        w = i / xf
        samples[i] = samples[i] * w + samples[total - xf + i] * (1.0 - w)
    write_wav(AUDIO_DIR / "bridge_bus_ambience.wav", samples[:total - xf])

    # 2. bus_bell_chime.wav
    bell_len = int(RATE * 1.6)
    b_samples = [0.0] * bell_len
    for i in range(bell_len):
        t = i / RATE
        v = 0.0
        if t >= 0.0:
            env1 = math.exp(-t * 4.2)
            v += 0.45 * math.sin(2 * math.pi * 880.0 * t) * env1 + \
                 0.22 * math.sin(2 * math.pi * 1760.0 * t) * env1 + \
                 0.08 * math.sin(2 * math.pi * 3520.0 * t) * env1
        if t >= 0.22:
            t2 = t - 0.22
            env2 = math.exp(-t2 * 3.8)
            v += 0.52 * math.sin(2 * math.pi * 659.25 * t2) * env2 + \
                 0.25 * math.sin(2 * math.pi * 1318.5 * t2) * env2 + \
                 0.10 * math.sin(2 * math.pi * 2637.0 * t2) * env2
        b_samples[i] = v
    write_wav(AUDIO_DIR / "bus_bell_chime.wav", b_samples)

    # 3. bus_screamer_glitch.wav
    s_len = int(RATE * 2.2)
    s_samples = [0.0] * s_len
    rnd2 = random.Random(909)
    for i in range(s_len):
        t = i / RATE
        env = math.exp(-t * 1.6)
        c1 = math.sin(2 * math.pi * (720.0 + 90.0 * math.sin(t * 70.0)) * t)
        c2 = math.sin(2 * math.pi * 845.0 * t)
        c3 = math.sin(2 * math.pi * 1190.0 * t)
        noise = (rnd2.random() * 2.0 - 1.0)
        chop = 1.0 if (int(t * 50) % 4 != 0) else 0.05
        sub = 0.65 * math.sin(2 * math.pi * 42.0 * t) * math.exp(-t * 2.5)
        s_samples[i] = ((c1 * 0.35 + c2 * 0.35 + c3 * 0.25) * 0.65 + noise * 0.35) * chop * env + sub
    write_wav(AUDIO_DIR / "bus_screamer_glitch.wav", s_samples)

    # 4. mannequin_snap.wav
    m_len = int(RATE * 0.75)
    m_samples = [0.0] * m_len
    rnd3 = random.Random(321)
    for i in range(m_len):
        t = i / RATE
        env = math.exp(-t * 16.0)
        crack = (rnd3.random() * 2.0 - 1.0) * env * 0.85
        twist = 0.5 * math.sin(2 * math.pi * (280.0 - t * 350.0) * t) * env
        m_samples[i] = crack + twist
    write_wav(AUDIO_DIR / "mannequin_snap.wav", m_samples)

    # 5. window_slap.wav
    w_len = int(RATE * 1.3)
    w_samples = [0.0] * w_len
    hits = [0.0, 0.11, 0.26, 0.42, 0.58]
    rnd4 = random.Random(654)
    for i in range(w_len):
        t = i / RATE
        v = 0.0
        for h in hits:
            if t >= h:
                dt = t - h
                if dt < 0.22:
                    env = math.exp(-dt * 30.0)
                    thud = math.sin(2 * math.pi * 105.0 * dt) * 0.75 * env
                    glass = math.sin(2 * math.pi * 2400.0 * dt) * 0.28 * math.exp(-dt * 50.0)
                    splat = (rnd4.random() * 2.0 - 1.0) * 0.38 * math.exp(-dt * 38.0)
                    v += thud + glass + splat
        w_samples[i] = v
    write_wav(AUDIO_DIR / "window_slap.wav", w_samples)

    # 6. blood_boil.wav
    b_len = int(RATE * 2.0)
    bo_samples = [0.0] * b_len
    rnd5 = random.Random(987)
    for i in range(b_len):
        t = i / RATE
        v = 0.0
        for f in [150, 220, 320, 440]:
            p = (t * 8.5 + f * 0.013) % 1.0
            if p < 0.14:
                benv = math.sin(p / 0.14 * math.pi)
                v += 0.28 * math.sin(2 * math.pi * (f + p * 160.0) * t) * benv
        v += (rnd5.random() * 2.0 - 1.0) * 0.09
        bo_samples[i] = v
    write_wav(AUDIO_DIR / "blood_boil.wav", bo_samples)

    # 7. bus_crash_cinematic.wav
    c_len = int(RATE * 4.6)
    c_samples = [0.0] * c_len
    rnd6 = random.Random(852)
    for i in range(c_len):
        t = i / RATE
        v = 0.0
        if t < 1.3:
            env1 = math.exp(-t * 3.2)
            impact = math.sin(2 * math.pi * (58.0 - t * 18.0) * t) * 0.85 * env1
            metal = (rnd6.random() * 2.0 - 1.0) * 0.75 * env1
            shat = math.sin(2 * math.pi * 3400.0 * t) * 0.35 * math.exp(-t * 7.5)
            v += impact + metal + shat
        if 0.8 <= t < 3.2:
            dt = t - 0.8
            env2 = math.exp(-dt * 1.4)
            sand = (rnd6.random() * 2.0 - 1.0) * 0.48 * env2
            roll = math.sin(2 * math.pi * 32.0 * dt) * 0.52 * env2
            v += sand + roll
        if t >= 1.8:
            dt2 = t - 1.8
            w_env = math.sin(min(1.0, dt2 / 1.6) * math.pi * 0.5) * math.exp(-dt2 * 0.55)
            ocean = (rnd6.random() * 2.0 - 1.0) * 0.4 * w_env
            v += ocean
        c_samples[i] = v
    write_wav(AUDIO_DIR / "bus_crash_cinematic.wav", c_samples)

def gen_art():
    rnd = random.Random(332026)

    # -------------------------------------------------------------------------
    # 1. Bus Interior Base (1400 x 360)
    # -------------------------------------------------------------------------
    bus = Image.new("RGBA", (1400, 360), "#080c0e")
    d = ImageDraw.Draw(bus)

    # Ceiling area (Y: 0..112)
    d.rectangle((0, 0, 1400, 112), fill="#1a2225")
    # Curved ceiling panels
    for py in [24, 48, 72, 96]:
        d.line((0, py, 1400, py), fill="#12181b", width=2)
        d.line((0, py + 1, 1400, py + 1), fill="#29373c", width=1)
    
    # AC vents along ceiling
    for vx in range(180, 1220, 90):
        d.rectangle((vx, 16, vx + 54, 22), fill="#0d1316", outline="#344349")
        for lx in range(vx + 4, vx + 52, 6):
            d.line((lx, 17, lx, 21), fill="#222b2f")

    # Fluorescent lights with soft glow
    for lx in range(210, 1180, 150):
        d.rectangle((lx, 36, lx + 76, 44), fill="#dcf0e8")
        d.rectangle((lx - 2, 34, lx + 78, 46), outline="#435e58", width=1)
        d.line((lx + 4, 40, lx + 72, 40), fill="#ffffff")

    # Yellow ceiling handrail poles (horizontal)
    d.line((140, 78, 1240, 78), fill="#c99222", width=4)
    d.line((140, 77, 1240, 77), fill="#e4ae3b", width=1)
    d.line((140, 80, 1240, 80), fill="#946510", width=1)

    # Overhead hanging grab straps & rings
    for rx in range(180, 1220, 48):
        d.line((rx, 79, rx, 94), fill="#1b1c1d", width=2)
        d.ellipse((rx - 5, 94, rx + 5, 108), outline="#c99222", width=2)
        d.point((rx, 94), fill="#946510")

    # Red emergency stop pull-cord
    d.line((140, 64, 1240, 64), fill="#a81919", width=2)
    for bx in [360, 560, 760, 960]:
        d.rectangle((bx - 4, 62, bx + 4, 74), fill="#c92020", outline="#6e1010")

    # Upper Panoramic Windows (Y: 108..156)
    # Outside is midnight Friendship Bridge fog (covered in-game by parallax background or textured glass)
    for wx in range(180, 1100, 130):
        # Window frame
        d.rectangle((wx, 108, wx + 122, 156), fill="#0e171b", outline="#2b3a40", width=2)
        # Deep blue-black night fog glass
        d.rectangle((wx + 3, 111, wx + 119, 153), fill="#09141a")
        # Glass reflections
        d.line((wx + 10, 152, wx + 54, 112), fill="#1b303b")
        d.line((wx + 35, 152, wx + 78, 112), fill="#14252e")

    # Floor (Y: 156..248) - Non-slip ribbed slate rubber
    d.rectangle((0, 156, 1400, 248), fill="#13171a")
    for fy in range(158, 248, 3):
        d.line((0, fy, 1400, fy), fill="#181e21")
        if fy % 6 == 0:
            d.line((0, fy, 1400, fy), fill="#0f1315")

    # Authentic Yellow Safety Lines (澳门巴士乘车安全警示线)
    d.line((150, 166, 1240, 166), fill="#bfa026", width=2)
    d.line((150, 238, 1240, 238), fill="#bfa026", width=2)
    for x in range(160, 1240, 40):
        d.line((x, 164, x + 8, 168), fill="#876f13")
        d.line((x, 236, x + 8, 240), fill="#876f13")

    # Metal floor inspection hatch / engine access hatches
    for hx in [420, 820]:
        d.rectangle((hx, 188, hx + 58, 218), outline="#384347", fill="#15191c")
        d.line((hx, 188, hx + 58, 188), fill="#4a575d")
        d.line((hx + 29, 198, hx + 29, 208), fill="#384347", width=2)

    # Upper Seats (Y: 122..164)
    for sx in range(220, 1040, 84):
        # Seat shell
        d.rounded_rectangle((sx, 122, sx + 60, 164), radius=4, fill="#19282e", outline="#293e47")
        # Transmac blue fabric pattern
        d.rounded_rectangle((sx + 3, 126, sx + 29, 160), radius=3, fill="#1c3e4e", outline="#28566b")
        d.rounded_rectangle((sx + 31, 126, sx + 57, 160), radius=3, fill="#1c3e4e", outline="#28566b")
        # Texture lines on fabric
        for ty in range(130, 158, 4):
            d.line((sx + 6, ty, sx + 26, ty), fill="#244d61")
            d.line((sx + 34, ty, sx + 54, ty), fill="#244d61")
        # Yellow headrest grab handle
        d.line((sx + 6, 123, sx + 54, 123), fill="#c79728", width=2)

    # Lower Seats (Y: 242..340)
    d.rectangle((0, 248, 1400, 360), fill="#0f1416")
    for sx in range(220, 1040, 84):
        d.rounded_rectangle((sx, 244, sx + 60, 312), radius=5, fill="#18272d", outline="#293e47")
        d.rounded_rectangle((sx + 3, 248, sx + 29, 296), radius=3, fill="#1c3e4e", outline="#28566b")
        d.rounded_rectangle((sx + 31, 248, sx + 57, 296), radius=3, fill="#1c3e4e", outline="#28566b")
        for ty in range(252, 292, 4):
            d.line((sx + 6, ty, sx + 26, ty), fill="#244d61")
            d.line((sx + 34, ty, sx + 54, ty), fill="#244d61")
        d.line((sx + 6, 245, sx + 54, 245), fill="#c79728", width=2)
        # Steel seat legs bolted to floor
        d.line((sx + 10, 312, sx + 10, 334), fill="#3a454a", width=3)
        d.line((sx + 50, 312, sx + 50, 334), fill="#3a454a", width=3)
        d.rectangle((sx + 7, 332, sx + 13, 336), fill="#505e66")
        d.rectangle((sx + 47, 332, sx + 53, 336), fill="#505e66")

    # Stanchion Poles (vertical yellow poles)
    for px in [300, 480, 660, 840, 1020]:
        d.line((px, 78, px, 248), fill="#c99222", width=4)
        d.line((px - 1, 78, px - 1, 248), fill="#e4ae3b", width=1)
        # Red stop bell unit
        d.rounded_rectangle((px - 5, 172, px + 5, 194), radius=2, fill="#1f2324", outline="#3a4042")
        d.ellipse((px - 3, 178, px + 3, 188), fill="#c92020", outline="#821414")
        d.point((px, 182), fill="#ff7070") # bell light

    # Driver Cabin Partition (X: 1080..1240, Y: 70..160)
    d.rectangle((1080, 68, 1235, 160), fill="#11191d", outline="#293940", width=2)
    # Acrylic security screen
    d.rectangle((1090, 74, 1225, 140), fill="#0d1a21", outline="#3e535c", width=2)
    # Driver dashboard, steering wheel
    d.rectangle((1175, 102, 1230, 150), fill="#172024", outline="#2b383e")
    d.ellipse((1188, 108, 1216, 136), outline="#48555c", width=4)
    d.line((1202, 110, 1202, 134), fill="#343d42", width=2)

    # Front Windshield (X: 1235..1360)
    d.rectangle((1235, 60, 1360, 245), fill="#071117", outline="#25353d", width=3)
    d.line((1245, 68, 1345, 230), fill="#122530", width=2)
    d.line((1285, 68, 1355, 180), fill="#10202a", width=1)
    # Windshield wipers
    d.line((1270, 215, 1315, 130), fill="#2b3236", width=3)
    d.line((1310, 220, 1350, 145), fill="#2b3236", width=3)

    # Rear End (X: 0..170)
    # Rear back bench seats
    d.rectangle((30, 115, 140, 260), fill="#152227", outline="#283a42", width=2)
    d.rectangle((36, 125, 134, 250), fill="#1c3b4a")
    for y in range(130, 245, 6):
        d.line((40, y, 130, y), fill="#244d61")
    d.line((140, 115, 140, 260), fill="#c99222", width=3)

    # Rear door area (X: 160..230, Y: 246..295)
    d.rectangle((160, 246, 230, 295), fill="#0b1215", outline="#3f535c", width=2)
    d.line((195, 246, 195, 295), fill="#26353b", width=2)
    # Door rubber edges and warning sign
    d.line((160, 246, 160, 295), fill="#1a2022", width=3)
    d.line((230, 246, 230, 295), fill="#1a2022", width=3)
    d.rectangle((172, 252, 218, 258), fill="#c79728")

    # Front door area (X: 1140..1220, Y: 246..295)
    d.rectangle((1140, 246, 1220, 295), fill="#0b1215", outline="#3f535c", width=2)
    d.line((1180, 246, 1180, 295), fill="#26353b", width=2)
    d.rectangle((1152, 252, 1208, 258), fill="#c79728")

    # Route 33 Transmac route diagram banner (上横楣路线图)
    d.rectangle((440, 50, 680, 70), fill="#e0ce26", outline="#9c8e16")
    d.rectangle((444, 53, 676, 67), fill="#151d18")
    d.line((450, 60, 670, 60), fill="#4a7356", width=2)
    for stx in range(460, 665, 18):
        d.ellipse((stx - 2, 58, stx + 2, 62), fill="#ffffff")

    # Add realistic pixel grit and grain
    noise = Image.new("RGBA", (1400, 360), (0, 0, 0, 0))
    nd = ImageDraw.Draw(noise)
    for _ in range(1200):
        nx = rnd.randint(0, 1399)
        ny = rnd.randint(0, 359)
        nd.point((nx, ny), fill=(rnd.randint(0, 30), rnd.randint(0, 30), rnd.randint(0, 30), rnd.randint(20, 50)))
    bus.alpha_composite(noise)

    bus.save(TILE_DIR / "bus_interior_base.png")
    print("Saved bus_interior_base.png")

    # -------------------------------------------------------------------------
    # 2. Moving Bridge & Sea Fog Parallax Background (800 x 180)
    # -------------------------------------------------------------------------
    fog_bg = Image.new("RGBA", (800, 180), "#04080b")
    fd = ImageDraw.Draw(fog_bg)
    # Midnight ocean waves
    for y in range(80, 180):
        shade = int((y - 80) * 0.22)
        fd.line((0, y, 800, y), fill=(6 + shade, 14 + shade, 22 + shade, 255))
    for y in range(95, 180, 5):
        for wx in range(0, 800, 32):
            offset = (wx + y * 7) % 800
            fd.line((offset, y, offset + 14, y), fill=(18, 38, 52, 140))
    # Friendship Bridge (友谊大桥) superstructure
    for bx in range(0, 800, 200):
        # Massive concrete piers
        fd.rectangle((bx + 70, 95, bx + 130, 180), fill="#131b20", outline="#202b33")
        fd.line((bx + 70, 95, bx + 130, 95), fill="#2d3b45")
        # Bridge deck and guardrails
        fd.rectangle((bx, 102, bx + 200, 114), fill="#1c252a", outline="#2f3d45")
        for rx in range(bx, bx + 200, 16):
            fd.line((rx, 96, rx, 102), fill="#2b3840", width=2)
        # Main suspension cable towers
        fd.polygon([(bx + 90, 10), (bx + 110, 10), (bx + 120, 102), (bx + 80, 102)], fill="#162026", outline="#26343d")
        # Diagonal suspension stay cables
        for s in range(5):
            h = 20 + s * 16
            fd.line((bx + 95, h, bx + 10 + s * 14, 102), fill="#202d35", width=1)
            fd.line((bx + 105, h, bx + 190 - s * 14, 102), fill="#202d35", width=1)
        # Amber bridge highway lamp (halo glow)
        lamp_layer = Image.new("RGBA", (800, 180), (0, 0, 0, 0))
        ld = ImageDraw.Draw(lamp_layer)
        ld.ellipse((bx + 92, 16, bx + 108, 32), fill=(255, 190, 70, 180))
        ld.ellipse((bx + 80, 4, bx + 120, 44), fill=(255, 170, 40, 60))
        lamp_layer = lamp_layer.filter(ImageFilter.GaussianBlur(6))
        fog_bg.alpha_composite(lamp_layer)

    # Swirling Sea Mist Fog layers
    fog_layer = Image.new("RGBA", (800, 180), (0, 0, 0, 0))
    fld = ImageDraw.Draw(fog_layer)
    for _ in range(80):
        fx = rnd.randint(0, 800)
        fy = rnd.randint(10, 170)
        rw = rnd.randint(40, 110)
        rh = rnd.randint(20, 50)
        fld.ellipse((fx - rw, fy - rh, fx + rw, fy + rh), fill=(160, 190, 205, 30))
    fog_layer = fog_layer.filter(ImageFilter.GaussianBlur(14))
    fog_bg.alpha_composite(fog_layer)
    fog_bg.save(TILE_DIR / "bus_bridge_fog_bg.png")
    print("Saved bus_bridge_fog_bg.png")

    # -------------------------------------------------------------------------
    # 3. Rearview Mirror: Driver Normal vs Faceless/Upside-Down
    # -------------------------------------------------------------------------
    # Normal (96 x 64)
    m_norm = Image.new("RGBA", (96, 64), (0, 0, 0, 0))
    md = ImageDraw.Draw(m_norm)
    md.line((48, 0, 48, 12), fill="#282a2b", width=4)
    md.rounded_rectangle((4, 10, 92, 60), radius=6, fill="#0f181e", outline="#445863", width=3)
    md.rectangle((8, 14, 88, 56), fill="#12232c")
    # Cap
    md.polygon([(32, 28), (64, 28), (68, 22), (28, 22)], fill="#1a2e24")
    md.line((26, 28, 70, 28), fill="#c79728", width=2)
    # Head & neck
    md.ellipse((36, 26, 60, 46), fill="#a89279", outline="#5e4f3f")
    # Eyes
    md.ellipse((41, 33, 46, 36), fill="#1c1916")
    md.ellipse((50, 33, 55, 36), fill="#1c1916")
    # Uniform shoulders
    md.polygon([(20, 46), (76, 46), (82, 58), (14, 58)], fill="#1c3026", outline="#2b4739")
    m_norm.save(PROP_DIR / "bus_mirror_driver_normal.png")

    # Anomaly: Driver is completely FACELESS void and hanging upside down!
    m_anom = Image.new("RGBA", (96, 64), (0, 0, 0, 0))
    mad = ImageDraw.Draw(m_anom)
    mad.line((48, 0, 48, 12), fill="#282a2b", width=4)
    mad.rounded_rectangle((4, 10, 92, 60), radius=6, fill="#1c0a0a", outline="#7a1818", width=3)
    mad.rectangle((8, 14, 88, 56), fill="#240c0c")
    # Hanging rope from top of mirror
    mad.line((48, 10, 48, 20), fill="#54432c", width=3)
    mad.ellipse((44, 18, 52, 24), fill="#3d301f")
    # Inverted head dangling downwards
    mad.ellipse((36, 20, 60, 42), fill="#d1ccc7", outline="#82776d") # pale dead flesh
    # COMPLETELY SMOOTH, FEATURELESS VOID - NO EYES, NO NOSE, NO MOUTH
    # Dark shadow cleft where face should be
    mad.ellipse((42, 27, 54, 36), fill="#b0aba4")
    # Blood drip trickling down inverted forehead
    mad.line((48, 22, 48, 38), fill="#730a0a", width=2)
    mad.line((52, 22, 52, 32), fill="#871212", width=1)
    # Inverted shoulders below
    mad.polygon([(22, 42), (74, 42), (80, 56), (16, 56)], fill="#171e19")
    m_anom.save(PROP_DIR / "bus_mirror_driver_anomaly.png")
    print("Saved mirror props")

    # -------------------------------------------------------------------------
    # 4. Coin Box: Normal vs Boiling Blood
    # -------------------------------------------------------------------------
    # Normal (64 x 64)
    cb_norm = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    cbd = ImageDraw.Draw(cb_norm)
    cbd.rounded_rectangle((10, 8, 54, 58), radius=4, fill="#2a3338", outline="#4d5c63", width=2)
    cbd.line((12, 10, 52, 10), fill="#667780")
    # Macau Pass reader pad
    cbd.rounded_rectangle((16, 14, 48, 26), radius=2, fill="#14422e", outline="#2da86e")
    cbd.line((20, 20, 44, 20), fill="#63d19b", width=1) # text simulation
    # Coin funnel
    cbd.polygon([(22, 30), (42, 30), (37, 38), (27, 38)], fill="#1a1e21", outline="#586870")
    # Transparent coin box window
    cbd.rectangle((18, 42, 46, 54), fill="#111c21", outline="#3f5057")
    cbd.ellipse((22, 45, 28, 51), fill="#b89a2e")
    cbd.rectangle((30, 46, 42, 52), fill="#527d62")
    cb_norm.save(PROP_DIR / "bus_coinbox_normal.png")

    # Anomaly: Boiling & overflowing thick blood
    cb_blood = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    cbad = ImageDraw.Draw(cb_blood)
    cbad.rounded_rectangle((10, 8, 54, 58), radius=4, fill="#241a1a", outline="#821414", width=2)
    # Glitched red screen
    cbad.rounded_rectangle((16, 14, 48, 26), radius=2, fill="#520a0a", outline="#ab1515")
    # Blood erupting from coin slot
    cbad.ellipse((20, 26, 44, 38), fill="#8f0808")
    # Foaming bubbles
    for bx, by, r in [(25, 28, 4), (35, 27, 5), (30, 32, 4), (40, 33, 3)]:
        cbad.ellipse((bx - r, by - r, bx + r, by + r), fill="#bd1313", outline="#f03737")
        cbad.point((bx - 1, by - 1), fill="#ffffff")
    # Thick blood cascading down
    cbad.rectangle((12, 32, 18, 62), fill="#6e0707")
    cbad.rectangle((46, 32, 52, 62), fill="#6e0707")
    cbad.polygon([(18, 36), (46, 36), (48, 56), (16, 56)], fill="#7a0a0a")
    for ly in [40, 48, 54]:
        cbad.line((18, ly, 46, ly), fill="#9c1010")
    # Massive blood puddle on floor
    cbad.ellipse((4, 52, 60, 62), fill="#4d0404")
    cbad.ellipse((12, 54, 52, 60), fill="#750808")
    cb_blood.save(PROP_DIR / "bus_coinbox_anomaly.png")
    print("Saved coinbox props")

    # -------------------------------------------------------------------------
    # 5. Seated Mannequin Passenger (48 x 64)
    # -------------------------------------------------------------------------
    # Normal: Sitting still facing forward
    man_norm = Image.new("RGBA", (48, 64), (0, 0, 0, 0))
    mand = ImageDraw.Draw(man_norm)
    # Trenchcoat & scarf
    mand.rounded_rectangle((8, 22, 40, 60), radius=5, fill="#1c242b", outline="#303d47")
    mand.line((24, 26, 24, 58), fill="#12181d", width=2)
    # Back of head / hair facing forward
    mand.ellipse((14, 6, 34, 24), fill="#2b2824", outline="#1c1a17")
    mand.ellipse((16, 8, 32, 18), fill="#38342f")
    man_norm.save(PROP_DIR / "bus_mannequin_normal.png")

    # Anomaly: Head snapped 180 degrees backward facing player!
    man_turn = Image.new("RGBA", (48, 64), (0, 0, 0, 0))
    matd = ImageDraw.Draw(man_turn)
    matd.rounded_rectangle((8, 22, 40, 60), radius=5, fill="#1c242b", outline="#303d47")
    # Ruptured neck joint with dried blood
    matd.line((16, 23, 32, 23), fill="#690909", width=3)
    # Lifeless glossy porcelain mannequin face staring straight at player
    matd.ellipse((12, 5, 36, 25), fill="#d4cec7", outline="#6e665d")
    # Hollow black doll eye sockets
    matd.ellipse((16, 11, 22, 17), fill="#070708", outline="#5e1212")
    matd.ellipse((26, 11, 32, 17), fill="#070708", outline="#5e1212")
    # Shiny plastic highlight dots
    matd.point((18, 13), fill="#ffffff")
    matd.point((28, 13), fill="#ffffff")
    # Carved smile / seam line
    matd.line((20, 20, 28, 20), fill="#3b2d2d", width=1)
    matd.line((24, 15, 24, 18), fill="#827b73") # nose ridge
    man_turn.save(PROP_DIR / "bus_mannequin_turned.png")
    print("Saved mannequin props")

    # -------------------------------------------------------------------------
    # 6. Pale Waterlogged Hands on Window (320 x 80)
    # -------------------------------------------------------------------------
    hands = Image.new("RGBA", (320, 80), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hands)
    hand_positions = [(48, 42), (115, 36), (198, 45), (268, 38)]
    for hx, hy in hand_positions:
        # Seawater condensation runoff trail
        hd.line((hx - 8, hy, hx - 8, hy + 34), fill=(100, 140, 160, 90), width=3)
        hd.line((hx + 6, hy, hx + 6, hy + 38), fill=(110, 40, 40, 110), width=2)
        # Palm of waterlogged drowned hand (bluish grey-white cold flesh)
        hd.ellipse((hx - 12, hy - 9, hx + 12, hy + 13), fill=(190, 205, 210, 220), outline=(130, 155, 165, 240))
        # 5 splayed fingers pressed against wet glass
        angles = [-0.55, -0.28, 0.0, 0.28, 0.58]
        lengths = [18, 23, 25, 22, 17]
        for fi, (ang, leng) in enumerate(zip(angles, lengths)):
            fx = hx + math.sin(ang) * leng + (fi - 2) * 3
            fy = hy - math.cos(ang) * leng
            hd.line((hx + (fi - 2) * 3, hy - 5, fx, fy), fill=(200, 215, 220, 235), width=4)
            # Flattened pale fingertip suction marks
            hd.ellipse((fx - 3, fy - 3, fx + 3, fy + 3), fill=(230, 240, 245, 250))
            # Blackened fingernails / blood scraping
            hd.line((fx - 1, fy - 2, fx + 1, fy - 2), fill=(60, 15, 15, 220), width=2)
    hands.save(PROP_DIR / "bus_window_hands.png")
    print("Saved bus_window_hands.png")

    # -------------------------------------------------------------------------
    # 7. Cinematic: Bus Crash on Hac Sa Beach (480 x 270)
    # -------------------------------------------------------------------------
    crash_img = Image.new("RGBA", (480, 270), "#04070a")
    cd = ImageDraw.Draw(crash_img)

    # Midnight tempest sky & fog
    for y in range(0, 145):
        s = int(y * 0.16)
        cd.line((0, y, 480, y), fill=(5 + s, 8 + s, 14 + s, 255))
    
    # Roaring sea surf breaking on the shore
    for wy in range(115, 155, 4):
        cd.line((0, wy, 480, wy), fill=(24, 48, 62, 255), width=2)
        for fx in range(0, 480, 16):
            if rnd.random() < 0.7:
                cd.ellipse((fx + rnd.randint(-4, 4), wy - 2, fx + 14, wy + 3), fill=(170, 205, 220, 160))

    # Wet black sand of Hac Sa Beach (路环黑沙海滩)
    for y in range(145, 270):
        shade = int((y - 145) * 0.1)
        cd.line((0, y, 480, y), fill=(8 + shade, 10 + shade, 12 + shade, 255))
    for _ in range(300):
        sx = rnd.randint(0, 479)
        sy = rnd.randint(150, 269)
        cd.point((sx, sy), fill=(35, 50, 60, rnd.randint(60, 200)))

    # Wrecked Transmac Bus 33, crumpled against sand berm
    # Chassis & yellow body tilted at ~18 degrees
    chassis = [(120, 195), (330, 145), (350, 215), (140, 260)]
    cd.polygon(chassis, fill="#b5941b", outline="#403207")
    # Shadow underneath bus on wet sand
    cd.polygon([(115, 240), (360, 195), (370, 225), (125, 268)], fill=(3, 5, 6, 210))
    # Cream-white roof
    roof = [(118, 195), (328, 145), (332, 130), (122, 178)]
    cd.polygon(roof, fill="#cad4cf", outline="#6e7d78")
    # Shattered window strip with internal eerie emergency green lighting
    cd.polygon([(142, 196), (318, 154), (322, 178), (146, 218)], fill="#102e38", outline="#3b6370")
    # Route board: [33 黑沙海滩]
    cd.rectangle((160, 178, 208, 190), fill="#0d1410", outline="#c7a424")
    cd.rectangle((162, 180, 206, 188), fill="#083818")

    # Front headlight beam blazing into the dark wet black sand
    beam = Image.new("RGBA", (480, 270), (0, 0, 0, 0))
    bmd = ImageDraw.Draw(beam)
    bmd.polygon([(125, 230), (10, 255), (45, 270), (135, 250)], fill=(255, 240, 170, 110))
    beam = beam.filter(ImageFilter.GaussianBlur(10))
    crash_img.alpha_composite(beam)

    # Shattered tempered glass crystals scattered across black sand
    for _ in range(120):
        gx = rnd.randint(130, 320)
        gy = rnd.randint(220, 265)
        cd.point((gx, gy), fill=(160, 230, 240, 220))

    # Steam / sea fog rising from the cracked engine radiator
    steam = Image.new("RGBA", (480, 270), (0, 0, 0, 0))
    smd = ImageDraw.Draw(steam)
    for _ in range(25):
        stx = rnd.randint(110, 150)
        sty = rnd.randint(180, 230)
        strad = rnd.randint(15, 35)
        smd.ellipse((stx - strad, sty - strad, stx + strad, sty + strad), fill=(200, 215, 220, 35))
    steam = steam.filter(ImageFilter.GaussianBlur(12))
    crash_img.alpha_composite(steam)

    crash_img.save(PROP_DIR / "bus_crash_beach.png")
    print("Saved bus_crash_beach.png")

if __name__ == "__main__":
    print("Building high-fidelity Chapter 4 assets...")
    gen_audio()
    gen_art()
    print("All assets successfully built!")
