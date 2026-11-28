from pathlib import Path
import re
import subprocess
import sys

AUD_ROOT = Path(r"d:\Aomen_Paranormal_Records\docs\overhaul_v6\voice_audition")

EXPECTED_FOLDERS = ["raw_clean", "mastered", "jiamin_vc", "granny_vc", "bus_fx", "cloned_demos"]


def inspect_wav(p: Path) -> tuple[float, float, float]:
    dur_out = subprocess.check_output(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", str(p)]
    ).decode().strip()
    dur = float(dur_out)
    vol_out = subprocess.check_output(
        ["ffmpeg", "-hide_banner", "-i", str(p), "-af", "volumedetect", "-f", "null", "NUL"],
        stderr=subprocess.STDOUT,
    ).decode("utf-8", errors="ignore")
    mean_m = re.search(r"mean_volume:\s*([-\d.]+)\s*dB", vol_out)
    max_m = re.search(r"max_volume:\s*([-\d.]+)\s*dB", vol_out)
    mean_db = float(mean_m.group(1)) if mean_m else -99.0
    max_db = float(max_m.group(1)) if max_m else -99.0
    return dur, mean_db, max_db


def main() -> int:
    failures = 0
    total = 0
    for folder in EXPECTED_FOLDERS:
        d = AUD_ROOT / folder
        wavs = sorted(d.glob("*.wav"))
        print(f"=== {folder} ({len(wavs)} files) ===")
        for w in wavs:
            total += 1
            dur, mean_db, max_db = inspect_wav(w)
            ok = dur > 1.0 and mean_db > -45.0 and max_db <= -0.3
            status = "PASS" if ok else "FAIL"
            if not ok:
                failures += 1
            print(f"  {status} {w.name:36s} dur={dur:5.2f}s mean={mean_db:6.1f}dB max={max_db:5.1f}dB")
    print(f"AUDIT_RESULT total={total} failures={failures}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
