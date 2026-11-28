from pathlib import Path
import re
import subprocess
import sys

OUT_DIR = Path(r"d:\Aomen_Paranormal_Records\docs\overhaul_v6\voice_audition\qwen3_v2")


def inspect_wav(p: Path) -> tuple[float, float, float]:
    dur = float(
        subprocess.check_output(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", str(p)]
        ).decode().strip()
    )
    vol = subprocess.check_output(
        ["ffmpeg", "-hide_banner", "-i", str(p), "-af", "volumedetect", "-f", "null", "NUL"],
        stderr=subprocess.STDOUT,
    ).decode("utf-8", errors="ignore")
    mean_db = float(re.search(r"mean_volume:\s*([-\d.]+)\s*dB", vol).group(1))
    max_db = float(re.search(r"max_volume:\s*([-\d.]+)\s*dB", vol).group(1))
    return dur, mean_db, max_db


def main() -> int:
    wavs = sorted(OUT_DIR.glob("*.wav"))
    failures = 0
    for w in wavs:
        dur, mean_db, max_db = inspect_wav(w)
        ok = dur > 1.2 and mean_db > -40.0 and max_db <= -0.3
        if not ok:
            failures += 1
        print(f"{'PASS' if ok else 'FAIL'} {w.name:34s} dur={dur:5.2f}s mean={mean_db:6.1f}dB max={max_db:5.1f}dB")
    print(f"V2_AUDIT total={len(wavs)} failures={failures}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
