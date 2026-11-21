"""Build a standalone Windows x64 playtest from an isolated staging copy."""

from datetime import datetime
from pathlib import Path
import shutil
import subprocess
import zipfile
import os
import hashlib
import json
from pathlib import PurePosixPath


ROOT = Path(__file__).resolve().parents[1]
RECOVERY = ROOT / "tools" / "recovery"
ENGINE = ROOT / "tools" / "engine" / "Godot_v4.7.2-stable_win64_console.exe"
TEMPLATE = RECOVERY / "windows_release_4.7.2_x86_64.exe"
EXE_NAME = "AomenParanormalRecords.exe"


def copy_runtime(project: Path) -> None:
    for folder in ("core", "entities", "levels", "ui"):
        shutil.copytree(ROOT / folder, project / folder)

    references = "\n".join(
        path.read_text(encoding="utf-8-sig")
        for path in project.rglob("*")
        if path.suffix in (".gd", ".json", ".tscn", ".tres", ".gdshader")
    )
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


def write_export_preset(project: Path) -> None:
    settings = (ROOT / "project.godot").read_text(encoding="utf-8-sig")
    settings = settings.replace('"AomenParanormalRecords"', '"AomenParanormalRecordsV5Playtest"')
    (project / "project.godot").write_text(settings, encoding="utf-8")
    preset = f'''[preset.0]
name="Windows x64 Playtest"
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
'''
    (project / "export_presets.cfg").write_text(preset, encoding="utf-8")


def run_logged(command: list[str], log, environment: dict[str, str]) -> None:
    subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, env=environment)


def sha256(path: Path) -> str:
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def main() -> None:
    if not ENGINE.is_file():
        raise FileNotFoundError(f"Godot console executable not found: {ENGINE}")
    if not TEMPLATE.is_file():
        raise FileNotFoundError(f"Godot 4.7.2 Windows export template not found: {TEMPLATE}")

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    build = RECOVERY / f"playtest_v5_{stamp}"
    project = build / "project"
    payload = build / "playtest"
    temporary = build / "tmp"
    project.mkdir(parents=True)
    payload.mkdir()
    temporary.mkdir()
    copy_runtime(project)
    write_export_preset(project)

    command = [str(ENGINE), "--headless", "--audio-driver", "Dummy", "--path", str(project)]
    environment = os.environ.copy()
    for variable in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
        environment[variable] = str(temporary)
    exe = payload / EXE_NAME
    with (build / "build.log").open("w", encoding="utf-8") as log:
        run_logged([*command, "--import"], log, environment)
        run_logged([*command, "--export-release", "Windows x64 Playtest", str(exe)], log, environment)

        license_script = build / "engine_licenses.gd"
        license_script.write_text(
            """extends SceneTree
func _initialize() -> void:
\tvar output := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
\toutput.store_string(Engine.get_license_text())
\tfor title in Engine.get_license_info():
\t\toutput.store_string("\\n\\n" + title + "\\n" + Engine.get_license_info()[title])
\tquit()
""",
            encoding="utf-8",
        )
        run_logged(
            [*command, "--script", str(license_script), "--", str(payload / "Godot_Licenses.txt")],
            log,
            environment,
        )

    (payload / "试玩须知.txt").write_text(
        "澳诡实录 · V5 Windows x64 试玩版\n\n"
        "解压后双击 AomenParanormalRecords.exe。第一次启动会建立本试玩版独立存档。\n"
        "WASD 移动，鼠标观察，E 调查，Shift 奔跑，Ctrl 蹲行，F 手电，B 背包，M 地图，J 手札，Esc 暂停。\n"
        "部分谜题可按 H 逐条查看调查提示。\n"
        "Q / Tab 查看手机，R 强闪；每章两次，每次消耗 25% 手机电量。缺电仍能查看离线资料。\n"
        "手机声强表显示本处最近响动，也可开启返回现场后的临时声强提示。\n"
        "安全准备点接电不会恢复已经用掉的强闪次数；追逐均保留不用强闪的脱身方式。\n"
        "巴士异象按铃后走后门；无异象从前门下车。\n"
        "防空洞竖井可在东岸拉桶绳诱敌，或绕入右下侧廊关门；白线外可观察，竖井内侧会坠落。\n"
        "这是可试玩构建，未经过完整真人通关和音频听感验收。\n",
        encoding="utf-8-sig",
    )
    for folder in ("demo", "recorded", "qubodup"):
        source = ROOT / "assets" / "audio" / folder / "SOURCE_LICENSE.md"
        shutil.copy2(source, payload / f"音效来源许可_{folder}.md")
    shutil.copy2(ROOT / "assets/audio/SOURCE_LICENSE.md", payload / "音效来源许可_根目录.md")
    shutil.copy2(ROOT / "docs/audio_generation_122.md", payload / "音效替换生成说明_122.md")

    archive = ROOT / f"澳诡实录_V5_Windows试玩_{stamp}.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=5) as bundle:
        for path in sorted(payload.iterdir()):
            bundle.write(path, f"Aomen_Paranormal_Records_V5/{path.name}")
    with zipfile.ZipFile(archive) as bundle:
        assert bundle.testzip() is None
        extraction = build / "independent_extraction"
        extraction.mkdir()
        extraction_root = extraction.resolve()
        expected_prefix = "Aomen_Paranormal_Records_V5"
        for member in bundle.infolist():
            name = PurePosixPath(member.filename)
            if name.is_absolute() or ".." in name.parts or not name.parts or name.parts[0] != expected_prefix:
                raise ValueError(f"Unsafe or unexpected archive member: {member.filename}")
        bundle.extractall(extraction)

    extracted_exe = extraction / expected_prefix / EXE_NAME
    if not extracted_exe.is_file() or sha256(extracted_exe) != sha256(exe):
        raise RuntimeError("Independent extraction did not preserve the exported executable")

    verify_data = build / "verification_userdata"
    verify_data.mkdir()
    verify_environment = os.environ.copy()
    for variable in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
        verify_environment[variable] = str(verify_data)
    launch_log = build / "independent_extracted_launch.log"
    launch_command = [str(extracted_exe), "--headless", "--audio-driver", "Dummy",
                      "--quit-after", "240", "--log-file", str(launch_log), "--",
                      "--profile=test", f"--run-id=package_extract_{stamp}", "--checkpoint-qa"]
    with (build / "independent_extracted_launch.host.log").open("w", encoding="utf-8") as output:
        launch = subprocess.run(launch_command, cwd=extraction_root,
                                stdout=output, stderr=subprocess.STDOUT,
                                env=verify_environment, timeout=120,
                                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    launch_text = launch_log.read_text(encoding="utf-8", errors="replace") if launch_log.exists() else ""
    if launch.returncode != 0 or "SCRIPT ERROR:" in launch_text or "ERROR:" in launch_text:
        raise RuntimeError(f"Extracted executable failed hidden startup; see {launch_log}")

    verification = {"archive": str(archive), "executable": str(exe),
                    "archive_bytes": archive.stat().st_size, "executable_bytes": exe.stat().st_size,
                    "archive_sha256": sha256(archive), "executable_sha256": sha256(exe),
                    "zip_test": "passed", "independent_extract": str(extraction),
                    "extracted_exe_sha256": sha256(extracted_exe),
                    "extracted_hidden_launch": {"exit_code": launch.returncode,
                                                 "log": str(launch_log), "profile": "test", "audio": "Dummy"},
                    "build": str(build)}
    (build / "verification.json").write_text(json.dumps(verification, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"ARCHIVE={archive}")
    print(f"EXECUTABLE={exe}")
    print(f"BYTES={archive.stat().st_size}")
    print(f"BUILD={build}")


if __name__ == "__main__":
    main()
