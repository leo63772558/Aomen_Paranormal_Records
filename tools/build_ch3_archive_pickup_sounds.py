from __future__ import annotations

import math
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "audio" / "recorded"
RATE = 44_100


def write_pcm(path: Path, samples: list[float]) -> None:
	with wave.open(str(path), "wb") as output:
		output.setnchannels(1)
		output.setsampwidth(2)
		output.setframerate(RATE)
		output.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(sample * 32767)))) for sample in samples))


def render_key_pickup() -> list[float]:
	samples: list[float] = []
	for index in range(int(RATE * 0.34)):
		t = index / RATE
		value = 0.0
		for start, strength in [(0.0, 0.8), (0.075, 0.46)]:
			age = t - start
			if age < 0:
				continue
			envelope = math.exp(-age * 21.0)
			value += strength * envelope * (
				0.52 * math.sin(math.tau * 1_490.0 * age)
				+ 0.31 * math.sin(math.tau * 2_380.0 * age + 0.17)
				+ 0.17 * math.sin(math.tau * 3_670.0 * age + 0.43)
			)
			value += strength * 0.16 * math.exp(-age * 85.0) * math.sin(math.tau * 5_250.0 * age)
		samples.append(value * 0.18)
	return samples


def render_ticket_pickup() -> list[float]:
	samples: list[float] = []
	state = 0x17A0
	previous = 0.0
	for index in range(int(RATE * 0.29)):
		t = index / RATE
		state = (1664525 * state + 1013904223) & 0xFFFFFFFF
		noise = ((state >> 16) / 32767.5) - 1.0
		swish = 0.0
		for start, end, strength in [(0.015, 0.12, 0.44), (0.145, 0.255, 0.34)]:
			if start <= t <= end:
				phase = (t - start) / (end - start)
				swish += strength * math.sin(math.pi * phase) ** 1.5
		filtered = noise - previous * 0.78
		previous = noise
		samples.append((filtered * swish * 0.30) + 0.008 * noise)
	return samples


def main() -> None:
	OUT.mkdir(parents=True, exist_ok=True)
	write_pcm(OUT / "archive_key_pickup.wav", render_key_pickup())
	write_pcm(OUT / "archive_ticket_pickup.wav", render_ticket_pickup())


if __name__ == "__main__":
	main()
