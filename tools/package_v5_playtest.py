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
    dynamic_audio = {
        "click", "scrape", "step",
        "step_sand_0", "step_sand_1",
        "step_water_0", "step_water_1",
        "step_metal_0", "step_metal_1",
        "step_wood_0", "step_wood_1",
        "step_stone_0", "step_stone_1", "step_stone_2", "step_stone_3",
    }
    webp_dirs = {"tilesets", "props", "map_landmarks", "portraits", "evidence"}
    for source in (ROOT / "assets").rglob("*"):
        if not source.is_file() or source.suffix in (".import", ".md"):
            continue
        relative = source.relative_to(ROOT)
        if source.suffix == ".png" and source.stem not in references and source.stem not in evidence_art:
            continue
        if "audio" in relative.parts and source.suffix in (".wav", ".ogg"):
            if source.name not in references and source.stem not in references and source.stem not in dynamic_audio:
                continue
        target = project / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        import_settings = source.with_suffix(source.suffix + ".import")
        if import_settings.is_file():
            dst_import = target.with_suffix(target.suffix + ".import")
            if (
                source.suffix == ".png"
                and source.stat().st_size >= 350 * 1024
                and not webp_dirs.isdisjoint(relative.parts)
                and "characters" not in relative.parts
            ):
                txt = import_settings.read_text(encoding="utf-8")
                txt = txt.replace("compress/mode=0", "compress/mode=1")
                lines = [
                    "compress/lossy_quality=0.88" if line.startswith("compress/lossy_quality=") else line
                    for line in txt.splitlines()
                ]
                dst_import.write_text("\n".join(lines) + "\n", encoding="utf-8")
            else:
                shutil.copy2(import_settings, dst_import)


def write_export_preset(project: Path) -> None:
    settings = (ROOT / "project.godot").read_text(encoding="utf-8-sig")
    settings = settings.replace('"AomenParanormalRecords"', '"AomenParanormalRecordsV6Playtest"')
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
    licenses_dir = payload / "licenses"
    licenses_dir.mkdir(exist_ok=True)
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
            [*command, "--script", str(license_script), "--", str(licenses_dir / "Godot_Licenses.txt")],
            log,
            environment,
        )

    build_report = (build / "build.log").read_text(encoding="utf-8", errors="replace")
    if "SCRIPT ERROR:" in build_report or "Parse Error:" in build_report:
        raise RuntimeError(f"Godot reported script errors during export; see {build / 'build.log'}")

    (payload / "给朋友的游玩说明.txt").write_text(
        "《澳诡实录》V6 轻量试玩版 — 给朋友的游玩说明\n\n"
        "1. 解压本压缩包后，直接双击 AomenParanormalRecords.exe 即可开始游玩（建议佩戴耳机体验纯正港澳粤语配音与惊悚音效）。\n"
        "2. 首次启动会自动建立独立试玩存档，无需任何额外配置。\n"
        "3. 基本操作：\n"
        "   - WASD 移动 / Shift 奔跑 / Ctrl 蹲行 / 鼠标 转向观察 / E 调查交互\n"
        "   - F 开关手电 / B 背包 / M 澳门路线图 / Esc 暂停\n"
        "   - Q / Tab 打开手机（内含照片、声强表与「澳门见闻成就图鉴」），R 强闪驱鬼（每章 2 次，每次耗电 25%，缺电也能翻阅资料）\n"
        "   - 卡关或想看推理方向可按 H 键查看调查提示\n"
        "4. 重点关卡小贴士：\n"
        "   - 33 路末班车：出现异象先拉车铃再走后门；一切正常则从前门下车，连续 5 次正确即可到达。\n"
        "   - 防空洞竖井：可在东岸拉桶绳引怪，或绕右下侧廊关门甩脱；远离竖井白线内侧以免坠落。\n"
        "   - 终章救援：敲出两短一长暗号后，合上高压电弧主闸用声呐引怪电击破门，切勿轻信左侧渗血暗门幻象。\n",
        encoding="utf-8-sig",
    )
    for folder in ("demo", "recorded", "qubodup"):
        source = ROOT / "assets" / "audio" / folder / "SOURCE_LICENSE.md"
        shutil.copy2(source, licenses_dir / f"音效来源许可_{folder}.md")
    shutil.copy2(ROOT / "assets/audio/SOURCE_LICENSE.md", licenses_dir / "音效来源许可_根目录.md")
    shutil.copy2(ROOT / "docs/audio_generation_122.md", licenses_dir / "音效替换生成说明_122.md")
    v6_credits = ROOT / "docs/overhaul_v6/audio_credits_v6.md"
    if v6_credits.is_file():
        shutil.copy2(v6_credits, licenses_dir / "音效与粤语配音来源许可_V6.md")
    shutil.copy2(ROOT / "assets/fonts/SOURCE_LICENSE.md", licenses_dir / "中文字体许可_NotoSerifSC.md")
    shutil.copy2(ROOT / "assets/fonts/OFL.txt", licenses_dir / "OFL.txt")

    expected_prefix = "澳诡实录_V6试玩"
    archive = ROOT / f"澳诡实录_V6_轻量试玩版_{stamp}.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
        for path in sorted(payload.rglob("*")):
            if path.is_file():
                bundle.write(path, f"{expected_prefix}/{path.relative_to(payload).as_posix()}")
    with zipfile.ZipFile(archive) as bundle:
        assert bundle.testzip() is None
        extraction = build / "independent_extraction"
        extraction.mkdir()
        extraction_root = extraction.resolve()
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
