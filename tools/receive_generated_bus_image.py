from __future__ import annotations

import base64
import ctypes
import msvcrt
from pathlib import Path
import sys


handle = msvcrt.get_osfhandle(sys.stdin.fileno())
mode = ctypes.c_uint()
kernel32 = ctypes.windll.kernel32
if kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
    kernel32.SetConsoleMode(handle, mode.value & ~0x0004)  # Disable terminal echo.

parts: list[str] = []
while True:
    line = sys.stdin.readline()
    if not line:
        raise SystemExit("Input ended before the image terminator.")
    line = line.strip()
    if line == "__IMAGE_END__":
        break
    parts.append(line)

payload = base64.b64decode("".join(parts), validate=True)
destination = Path(sys.argv[1])
if len(sys.argv) != 2 or not destination.resolve().is_relative_to(Path.cwd().resolve()):
    raise SystemExit("Provide an output path inside the project.")
destination.write_bytes(payload)
print(f"WROTE {destination.as_posix()} {len(payload)} bytes")
