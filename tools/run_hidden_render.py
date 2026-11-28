"""Run Godot's renderer on an isolated Windows desktop, without a visible game window."""
import argparse
import ctypes
from ctypes import wintypes
from pathlib import Path
import subprocess
import os
import time

parser = argparse.ArgumentParser()
parser.add_argument("scene")
parser.add_argument("--run-id", default="hidden_render_033")
parser.add_argument("--script", action="store_true")
args, extra_args = parser.parse_known_args()
root = Path(__file__).resolve().parent.parent
user32 = ctypes.WinDLL("user32", use_last_error=True)
user32.CreateDesktopW.argtypes = [wintypes.LPCWSTR, wintypes.LPCWSTR, ctypes.c_void_p,
                                wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p]
user32.CreateDesktopW.restype = wintypes.HANDLE
user32.CloseDesktop.argtypes = [wintypes.HANDLE]
user32.CloseDesktop.restype = wintypes.BOOL
hide_callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
user32.EnumWindows.argtypes = [hide_callback_type, wintypes.LPARAM]
user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
user32.ShowWindow.argtypes = [wintypes.HWND, ctypes.c_int]
desktop_name = "AomenRender_" + str(__import__("os").getpid())
desktop = user32.CreateDesktopW(desktop_name, None, None, 0, 0x01FF, None)
startup = subprocess.STARTUPINFO()
if desktop:
    startup.lpDesktop = desktop_name
else:
    # Managed hosts may forbid a new desktop. Only explicitly hidden QA scenes
    # can fall back to an off-screen, non-activating window on the current one.
    hidden_scenes = {
        "res://tests/coastal_playability.tscn",
        "res://tests/phone_visual_083.tscn",
        "res://tests/finale_visual_086.tscn",
        "res://tests/shaft_visual_084.tscn",
        "res://tests/photo_focus_090.tscn",
        "res://tests/coastal_silt_tunnel_059.tscn",
        "res://tests/bus_crash_pause_218.tscn",
        "res://tests/bus_wrong_anomalies_248.tscn",
        "res://tests/balance_focus_visual_248.tscn",
        "res://tests/beach_v5_049.tscn",
        "res://tests/bunker_toolbox_076.tscn",
        "res://tests/drag_focus_250.tscn",
        "res://tests/room304_cover_visual_098.tscn",
        "res://tests/formal_bus_v5_048.tscn",
        "res://tests/player_feedback_251.tscn",
        "res://tests/transition_retry_212.tscn",
        "res://tests/ch3_archive_room_regression.tscn",
        "res://tests/demo_route_026.gd",
        "res://tests/full_route_tail_071.gd",
        "res://tests/ending_retry_068.tscn",
    }
    if args.scene not in hidden_scenes:
        raise ctypes.WinError(ctypes.get_last_error())
    print("Isolated desktop unavailable; using the explicitly hidden off-screen QA viewport.")
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
command = [str(root / "tools/engine/Godot_v4.7.2-stable_win64_console.exe"),
           "--path", str(root), "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
           "--fixed-fps", "60", "--log-file", "docs/build_reports/" + args.run_id + ".godot.log",
           "--position", "-32000,-32000", "--single-window"]
if args.script:
    command.append("--script")
command += [args.scene, "--", "--profile=test", "--run-id=" + args.run_id, *extra_args]
environment = os.environ.copy()
appdata = root / "tools/recovery/qa_appdata"
appdata.mkdir(parents=True, exist_ok=True)
for variable in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
    environment[variable] = str(appdata)
try:
    report = root / "docs/build_reports" / (args.run_id + ".render.log")
    with report.open("w", encoding="utf-8") as output:
        process = subprocess.Popen(command, cwd=root, startupinfo=startup, stdout=output,
                                   stderr=subprocess.STDOUT, env=environment, creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            timeout = 360 if args.script else 120
            deadline = time.monotonic() + timeout
            while process.poll() is None:
                if not desktop:
                    @hide_callback_type
                    def hide_test_window(handle, _parameter):
                        owner = wintypes.DWORD()
                        user32.GetWindowThreadProcessId(handle, ctypes.byref(owner))
                        if owner.value == process.pid:
                            user32.ShowWindow(handle, 0)
                        return True
                    user32.EnumWindows(hide_test_window, 0)
                if time.monotonic() > deadline:
                    raise subprocess.TimeoutExpired(command, timeout)
                time.sleep(0.02)
            code = process.returncode
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            raise
    print(report.read_text(encoding="utf-8"))
    raise SystemExit(code)
finally:
    if desktop:
        user32.CloseDesktop(desktop)
