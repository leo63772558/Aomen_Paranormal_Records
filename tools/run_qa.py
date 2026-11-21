"""Run Godot QA with writable, isolated Windows app data and no visible window."""
import argparse
import os
import re
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("target", nargs="?", default="res://ui/main_menu.tscn")
parser.add_argument("--script", action="store_true")
parser.add_argument("--run-id", required=True)
parser.add_argument("--report-id")
parser.add_argument("--checkpoint-qa", action="store_true")
parser.add_argument("--import-only", action="store_true")
parser.add_argument("--quit-after", type=int)
args, extra = parser.parse_known_args()
if not args.run_id.replace("_", "").replace("-", "").isalnum():
    raise SystemExit("Unsafe test run ID")
root = Path(__file__).resolve().parents[1]
userdata = root / "tools/recovery/qa_appdata"
userdata.mkdir(parents=True, exist_ok=True)
environment = os.environ.copy()
for variable in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
    environment[variable] = str(userdata)
report_name = args.report_id or args.run_id
if not report_name.replace("_", "").replace("-", "").isalnum():
    raise SystemExit("Unsafe report ID")
report = root / "docs/build_reports" / f"{report_name}.godot.log"
command = [str(root / "tools/engine/Godot_v4.7.2-stable_win64_console.exe"),
           "--headless", "--audio-driver", "Dummy", "--path", str(root),
           "--fixed-fps", "60", "--log-file", str(report)]
if args.import_only:
    command += ["--editor", "--import", "--quit"]
else:
    if args.script:
        command += ["--script"]
    command += [args.target]
    if args.quit_after:
        command += ["--quit-after", str(args.quit_after)]
    command += ["--", "--profile=test", f"--run-id={args.run_id}"]
    if args.checkpoint_qa:
        command += ["--checkpoint-qa"]
    command += extra
result = subprocess.run(command, cwd=root, env=environment, capture_output=True,
                        text=True, encoding="utf-8", errors="replace", timeout=240,
                        creationflags=subprocess.CREATE_NO_WINDOW)
output = result.stdout + result.stderr
# The engine log records script checks; this file also keeps host diagnostics.
report.with_suffix(".host.log").write_text(output, encoding="utf-8")
lines = output.splitlines()
# Match diagnostic markers, not ordinary words in test names (e.g. FAILURE).
diagnostics = [line for line in lines if re.search(r"\b(?:SCRIPT ERROR|ERROR|WARNING|FAIL)(?=\s|:|$)", line)]
print("\n".join(diagnostics + lines[-8:]))
print(f"EXIT={result.returncode} LOG={report}")
raise SystemExit(result.returncode or (1 if diagnostics else 0))
