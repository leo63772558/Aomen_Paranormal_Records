"""Export a standalone Windows playtest from a separate staging directory."""

from datetime import datetime
from pathlib import Path
import shutil
import subprocess
import zipfile


ROOT = Path(__file__).resolve().parents[1]
RECOVERY = ROOT / "tools/recovery"
ENGINE = ROOT / "tools/engine/Godot_v4.7.2-stable_win64_console.exe"
TEMPLATE = RECOVERY / "windows_release_4.7.2_x86_64.exe"
EXE_NAME = "AomenParanormalRecords.exe"


def copy_runtime(project):
    for folder in ("core", "entities", "levels", "ui"):
        shutil.copytree(ROOT / folder, project / folder)
    references = "\n".join(
        path.read_text(encoding="utf-8-sig")
        for path in project.rglob("*")
        if path.suffix in (".gd", ".json", ".tscn", ".tres", ".gdshader")
    )
    # The three evidence pages are loaded from a formatted filename.
    evidence_art = {f"crypt_{kind}_013" for kind in ("photo", "plan", "doodle")}
    for source in (ROOT / "assets").rglob("*"):
        if not source.is_file() or source.suffix in (".import", ".md"):
            continue
        relative = source.relative_to(ROOT)
        if source.suffix == ".png" and source.stem not in references and source.stem not in evidence_art:
            continue
        target = project / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        import_settings = source.with_suffix(source.suffix + ".import")
        if import_settings.is_file():
            shutil.copy2(import_settings, target.with_suffix(target.suffix + ".import"))


def main():
    if not TEMPLATE.is_file():
        raise FileNotFoundError("The Windows release template for Godot 4.7.2 is required.")
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    build = RECOVERY / f"friend_026_{stamp}"
    project = build / "project"
    payload = build / "playtest"
    project.mkdir(parents=True)
    payload.mkdir()
    copy_runtime(project)
    settings = (ROOT / "project.godot").read_text(encoding="utf-8-sig")
    settings = settings.replace('"AomenParanormalRecords"', '"AomenParanormalRecordsFriend026"')
    (project / "project.godot").write_text(settings, encoding="utf-8")
    (project / "export_presets.cfg").write_text(f'''[preset.0]
name="Windows Playtest"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter="*.json"
exclude_filter=""
script_export_mode=2

[preset.0.options]
custom_template/release="{TEMPLATE.as_posix()}"
binary_format/architecture="x86_64"
binary_format/embed_pck=true
debug/export_console_wrapper=0
application/modify_resources=false
''', encoding="utf-8")
    command = [str(ENGINE), "--headless", "--audio-driver", "Dummy", "--path", str(project)]
    with (build / "build.log").open("w", encoding="utf-8") as log:
        subprocess.run([*command, "--import"], stdout=log, stderr=subprocess.STDOUT, check=True)
        exe = payload / EXE_NAME
        subprocess.run([*command, "--export-release", "Windows Playtest", str(exe)], stdout=log,
                       stderr=subprocess.STDOUT, check=True)
        dump = build / "engine_licenses.gd"
        dump.write_text('''extends SceneTree
func _initialize() -> void:
\tvar output := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
\toutput.store_string(Engine.get_license_text())
\tfor title in Engine.get_license_info():
\t\toutput.store_string("\\n\\n" + title + "\\n" + Engine.get_license_info()[title])
\tquit()
''', encoding="utf-8")
        subprocess.run([*command, "--script", str(dump), "--", str(payload / "Godot_Licenses.txt")],
                       stdout=log, stderr=subprocess.STDOUT, check=True)

    (payload / "先看这里.txt").write_text(
        "澳诡实录 · 好友试玩 026\n\n"
        "适用 Windows 64 位。把压缩包解压到一个文件夹，再双击 AomenParanormalRecords.exe。\n"
        "第一次进入从香港开场。之后从同一个入口打开，会接续自己的进度。\n"
        "WASD 移动，鼠标转向，E 调查，Shift 跑步，F 手电，B 背包，M 路线，Q 手机。\n"
        "试玩到松山防空洞外复听录音结束。故事取材于澳门都市传说。\n"
        "画面包含为本项目生成和编辑的美术。音效来源和引擎许可附在文件夹中。\n",
        encoding="utf-8-sig",
    )
    for folder in ("recorded", "qubodup"):
        shutil.copy2(ROOT / f"assets/audio/{folder}/SOURCE_LICENSE.md", payload / f"音效来源_{folder}.md")
    archive = ROOT / f"澳诡实录_好友试玩_026_{stamp}.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=5) as bundle:
        for path in sorted(payload.iterdir()):
            bundle.write(path, f"Aomen_Paranormal_Records_026/{path.name}")
    with zipfile.ZipFile(archive) as bundle:
        assert bundle.testzip() is None
    print(f"ARCHIVE={archive}\nBYTES={archive.stat().st_size}\nBUILD={build}", flush=True)


if __name__ == "__main__":
    main()
