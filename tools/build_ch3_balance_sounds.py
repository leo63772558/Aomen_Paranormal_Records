from __future__ import annotations

import math
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "audio" / "recorded"
RATE = 44_100


def render(path: Path, duration: float, strikes: list[tuple[float, float]]) -> None:
	frames = int(RATE * duration)
	samples: list[int] = []
	for index in range(frames):
		t = index / RATE
		value = 0.0
		for start, strength in strikes:
			age = t - start
			if age < 0:
				continue
			envelope = math.exp(-age * (12.0 if strength > 0.7 else 18.0))
			value += strength * envelope * (
				0.37 * math.sin(math.tau * 523.0 * age)
				+ 0.29 * math.sin(math.tau * 817.0 * age + 0.13)
				+ 0.20 * math.sin(math.tau * 1_363.0 * age + 0.31)
				+ 0.10 * math.sin(math.tau * 2_217.0 * age + 0.47)
			)
			# A short bright strike makes this read as metal on metal rather than a beep.
			value += strength * 0.13 * math.exp(-age * 78.0) * (
				math.sin(math.tau * 3_780.0 * age) + 0.42 * math.sin(math.tau * 5_110.0 * age + 0.2)
			)
			value += strength * 0.09 * math.exp(-age * 30.0) * math.sin(math.tau * 188.0 * age)
		samples.append(max(-32767, min(32767, int(value * 7_800))))
	with wave.open(str(path), "wb") as output:
		output.setnchannels(1)
		output.setsampwidth(2)
		output.setframerate(RATE)
		output.writeframes(b"".join(struct.pack("<h", sample) for sample in samples))


def main() -> None:
	OUT.mkdir(parents=True, exist_ok=True)
	render(OUT / "ch3_balance_weight.wav", 0.43, [(0.0, 1.0), (0.09, 0.30)])
	render(OUT / "ch3_balance_settle.wav", 0.72, [(0.0, 0.9), (0.11, 0.43), (0.27, 0.27), (0.44, 0.16)])


if __name__ == "__main__":
	main()
