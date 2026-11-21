"""Original synthesized pneumatic door cues; no external samples."""
from pathlib import Path
import math
import random
import struct
import wave

root = Path(__file__).resolve().parent.parent
rate = 24000
for filename, opening in [("bus_door_open_036.wav", True), ("bus_door_close_036.wav", False)]:
    rng = random.Random(36 if opening else 37)
    duration = 0.88
    low = 0.0
    pcm = bytearray()
    for index in range(int(rate * duration)):
        t = index / rate
        noise = rng.uniform(-1, 1)
        low += (noise - low) * 0.12
        air = (noise - low) * 0.14 * math.sin(math.pi * min(t / 0.8, 1)) ** 1.4
        latch_time = 0.06 if opening else 0.72
        dt = t - latch_time
        latch = 0.0 if dt < 0 else math.exp(-dt * 72) * (math.sin(dt * 2 * math.pi * 136) * 0.17 + low * 0.2)
        motor = math.sin(t * 2 * math.pi * 51) * 0.012 * math.sin(math.pi * t / duration)
        value = max(-1, min(1, air + latch + motor))
        pcm.extend(struct.pack("<h", round(value * 32767)))
    with wave.open(str(root / "assets/audio/recorded" / filename), "wb") as output:
        output.setparams((1, 2, rate, 0, "NONE", "not compressed"))
        output.writeframes(pcm)
    print(filename)

# The bus repeats the exact old sound, preceded by the recorder's short blank
# lead-in. Comparing the two recordings requires lining up the actual break.
with wave.open(str(root / "assets/audio/demo/recording_fragment_026.wav"), "rb") as source:
    parameters = source.getparams()
    original = source.readframes(source.getnframes())
with wave.open(str(root / "assets/audio/recorded/bus_replayed_fragment_037.wav"), "wb") as output:
    output.setparams(parameters)
    output.writeframes(bytes(round(parameters.framerate * 0.22) * parameters.nchannels * parameters.sampwidth) + original)
print("bus_replayed_fragment_037.wav")
