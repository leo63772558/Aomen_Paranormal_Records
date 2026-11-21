"""Build short scene cues from credited Foley and original synthesis."""
from array import array
from math import exp, pi, sin
from pathlib import Path
from random import Random
import subprocess
from urllib.request import urlretrieve
import wave

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tools" / "audio_sources"
OUT = ROOT / "assets" / "audio" / "demo"
RECORDED = ROOT / "assets" / "audio" / "recorded"
RATE = 24000
SOURCES = {
    "screams_026.ogg": "https://opengameart.org/sites/default/files/screams_0.ogg",
    "fall_of_stone_026.ogg": "https://bigsoundbank.com/UPLOAD/ogg/1022.ogg?v=d",
}


def decode(path):
    raw = subprocess.check_output(
        ["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1",
         "-ar", str(RATE), "-f", "s16le", "-"]
    )
    samples = array("h", raw)
    return [sample / 32768.0 for sample in samples]


def excerpt(samples, length, first=0):
    duration = int(length * RATE)
    search = samples[first:first + RATE * 6]
    start = first + max(0, next((i for i, x in enumerate(search)
                                  if abs(x) > 0.07), 0) - 96)
    return samples[start:start + duration]


def stretch(samples, factor):
    return [samples[min(int(i / factor), len(samples) - 1)]
            for i in range(int(len(samples) * factor))]


def filter_band(samples, lower, upper):
    fast = slow = 0.0
    fast_a = 1.0 - exp(-2 * pi * upper / RATE)
    slow_a = 1.0 - exp(-2 * pi * lower / RATE)
    output = []
    for sample in samples:
        fast += fast_a * (sample - fast)
        slow += slow_a * (fast - slow)
        output.append(fast - slow)
    return output


def mix(output, clip, start, gain):
    offset = round(start * RATE)
    fade = max(1, round(RATE * 0.018))
    for i, value in enumerate(clip[:len(output) - offset]):
        envelope = min(1.0, (i + 1) / fade, (len(clip) - i) / fade)
        output[offset + i] += value * gain * envelope


def save(name, output):
    peak = max(abs(x) for x in output)
    gain = min(1.0, 0.78 / max(peak, 0.01))
    with wave.open(str(OUT / f"{name}_026.wav"), "wb") as cue:
        cue.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        cue.writeframes(array("h", (round(x * gain * 32760) for x in output)).tobytes())


def empty(seconds):
    return [0.0] * round(seconds * RATE)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    SOURCE.mkdir(parents=True, exist_ok=True)
    for name, url in SOURCES.items():
        if not (SOURCE / name).exists():
            urlretrieve(url, SOURCE / name)
    voice = excerpt(decode(SOURCE / "screams_026.ogg"), 0.85)
    rock = excerpt(decode(SOURCE / "fall_of_stone_026.ogg"), 0.42)
    knock = excerpt(decode(SOURCE / "wood_metal" / "wood_hit_01.ogg"), 0.12)
    step = excerpt(decode(RECORDED / "shadow_step.ogg"), 0.32)
    switch = excerpt(decode(RECORDED / "power_switch.wav"), 0.22)

    tape = empty(1.78)
    rng = Random(26)
    for i in range(len(tape)):
        tape[i] = 0.007 * (rng.random() * 2 - 1)
    for mark, gain in [(0.12, 0.42), (0.29, 0.36), (0.66, 0.46)]:
        mix(tape, filter_band(knock, 340, 1900), mark, gain)
    mix(tape, filter_band(stretch(voice[:int(RATE * 0.32)], 1.51), 380, 1560), 0.88, 0.46)
    save("recording_fragment", tape)

    outage = [0.22 * sin(2*pi * (116*i/RATE - 63*(i/RATE)**2)) * exp(-7*i/RATE)
              for i in range(round(RATE * 0.58))]
    mix(outage, switch, 0.04, 0.45)
    save("power_failure", outage)

    approach = empty(1.52)
    for start, gain in [(0.0, 0.32), (0.41, 0.49), (0.85, 0.7)]:
        mix(approach, filter_band(stretch(step, 1.19), 70, 980), start, gain)
    save("door_approach", approach)

    cry = empty(2.08)
    dull = filter_band(stretch(voice, 1.38), 230, 1680)
    for delay, gain in [(0.0, 0.58), (0.16, 0.17), (0.34, 0.1), (0.51, 0.055)]:
        mix(cry, dull, delay, gain)
    save("hall_wail", cry)

    pit = empty(2.65)
    for start, gain in [(0.24, 0.51), (1.15, 0.32), (1.43, 0.18), (1.79, 0.12), (2.15, 0.058)]:
        mix(pit, filter_band(stretch(rock, 1.23), 90, 1700 - 300*start), start, gain)
    save("pit_drop", pit)

    drops = empty(0.73)
    drop = [0.13 * sin(2*pi * (477*i/RATE + 1900*(i/RATE)**2)) * exp(-48*i/RATE)
            for i in range(round(RATE * 0.095))]
    for time, gain in [(0.18, 0.8), (0.32, 0.7), (0.52, 0.47)]:
        mix(drops, drop, time, gain)
    save("oil_drops", drops)

    impact = [0.43 * sin(2*pi * (107*i/RATE - 48*(i/RATE)**2)) * exp(-8*i/RATE)
              for i in range(round(RATE * 0.78))]
    mix(impact, filter_band(voice[:int(RATE * 0.43)], 310, 2200), 0.045, 0.55)
    mix(impact, switch, 0.015, 0.42)
    save("capture_hit", impact)

    rush = empty(0.47)
    wind = filter_band([rng.uniform(-1.0, 1.0) for _ in rush], 190, 950)
    for i in range(len(rush)):
        at = i / len(rush)
        rush[i] = 0.62 * wind[i] * min(1.0, at ** 1.6 * 1.7) * min(1.0, (1.0 - at) * 12)
    mix(rush, filter_band(stretch(step, 0.76), 100, 1100), 0.10, 0.32)
    save("capture_rush", rush)


if __name__ == "__main__":
    main()
