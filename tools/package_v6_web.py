"""Build single-threaded HTML5/WebGL2 competition package -> submission_20261127/03_公开试玩安装包/澳诡实录_Web网页试玩版.zip."""

from datetime import datetime
from pathlib import Path
from pathlib import PurePosixPath
import hashlib
import json
import os
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
RECOVERY = ROOT / "tools" / "recovery"
ENGINE = ROOT / "tools" / "engine" / "Godot_v4.7.2-stable_win64_console.exe"
WEB_TEMPLATE = RECOVERY / "web_nothreads_release_4.7.2.zip"
MOBILE_OVERLAY = ROOT / "tools" / "web_mobile_overlay.html"
SUBMISSION_ROOT = ROOT / "submission_20261127"


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


def write_web_export_preset(project: Path) -> None:
    settings = (ROOT / "project.godot").read_text(encoding="utf-8-sig")
    (project / "project.godot").write_text(settings, encoding="utf-8")
    preset = f'''[preset.0]
name="Web HTML5 Competition"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter="*.json,*.ttf"
exclude_filter=""
script_export_mode=2

[preset.0.options]
custom_template/release="{WEB_TEMPLATE.as_posix()}"
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
'''
    (project / "export_presets.cfg").write_text(preset, encoding="utf-8")


def run_logged(command: list[str], log, environment: dict[str, str]) -> None:
    subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, env=environment)


def polish_html(html_path: Path) -> None:
    html = html_path.read_text(encoding="utf-8")
    html = html.replace(
        '<meta name="viewport" content="width=device-width, user-scalable=no, initial-scale=1.0">',
        '<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">',
    )
    html = html.replace(
        "<title>澳诡实录 · 试玩篇</title>",
        "<title>《澳诡实录》· 澳门人文悬疑解谜网页试玩版（菜農子弟）</title>",
    )
    html = html.replace(
        "background-color: black;",
        "background-color: #08110d; font-family: 'Noto Serif SC', 'SimSun', serif;",
    )
    custom_style = (
        "<style>\n"
        "  body { background: radial-gradient(circle at 50% 35%, #11221a 0%, #070e0a 100%) !important; }\n"
        "  #status-indeterminate > div { background-color: #8fb894 !important; border-color: #d6c286 !important; }\n"
        "</style>\n</head>"
    )
    if "</head>" in html and "#status-indeterminate" in html:
        html = html.replace("</head>", custom_style, 1)

    file_guard_script = (
        "<script>\n"
        "(function(){\n"
        "  if (window.location.protocol === 'file:') {\n"
        "    window.addEventListener('DOMContentLoaded', function(){\n"
        "      var s = document.getElementById('status');\n"
        "      if (s) s.style.display = 'none';\n"
        "      var card = document.createElement('div');\n"
        "      card.style.cssText = 'position:fixed;inset:0;display:flex;align-items:center;justify-content:center;background:#08110d;color:#ede4c8;font-family:serif;padding:24px;z-index:9999;';\n"
        "      card.innerHTML = '<div style=\"max-width:560px;background:#101f18;border:2px solid #b89c5e;border-radius:8px;padding:26px 28px;line-height:1.8;\">' +\n"
        "        '<h2 style=\"margin:0 0 12px;color:#fff2cc;font-size:20px;\">《澳诡实录》Web/HTML5 网页试玩版运行提示</h2>' +\n"
        "        '<p style=\"margin:0 0 10px;font-size:14px;\">检测到您正在使用本地 <code>file://</code> 方式直接双击打开 <code>index.html</code>。现代浏览器安全策略会拦截本地协议直接加载 WebAssembly 游戏内核。</p>' +\n"
        "        '<ul style=\"margin:8px 0 14px;padding-left:18px;font-size:14px;color:#cfe0d2;\">' +\n"
        "        '<li><b>参赛官网在线游玩：</b>传至雷火大赛官网后，平台自带网页托管服务器，评委与玩家点击即可直接游玩，无需任何额外操作。</li>' +\n"
        "        '<li><b>本地电脑离线试玩：</b>推荐直接双击《评审私有包》中的 <code>AomenParanormalRecords.exe</code>；或在当前目录运行 <code>python -m http.server 8060</code> 后访问 <code>http://127.0.0.1:8060</code>。</li>' +\n"
        "        '</ul></div>';\n"
        "      document.body.appendChild(card);\n"
        "    });\n"
        "  }\n"
        "})();\n"
        "</script>\n"
    )
    if "const GODOT_CONFIG" in html:
        html = html.replace("<script src=\"index.js\"></script>", file_guard_script + "\t\t<script src=\"index.js\"></script>", 1)
    if MOBILE_OVERLAY.is_file() and "</body>" in html:
        overlay_snippet = MOBILE_OVERLAY.read_text(encoding="utf-8")
        html = html.replace("</body>", overlay_snippet + "\n\t</body>", 1)
    html_path.write_text(html, encoding="utf-8")


def sha256(path: Path) -> str:
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def main() -> None:
    if not ENGINE.is_file():
        raise FileNotFoundError(f"Godot console executable not found: {ENGINE}")
    if not WEB_TEMPLATE.is_file():
        raise FileNotFoundError(f"Web export template not found: {WEB_TEMPLATE}")

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    build = RECOVERY / f"web_v6_{stamp}"
    project = build / "project"
    payload = build / "web_payload"
    temporary = build / "tmp"
    project.mkdir(parents=True)
    payload.mkdir()
    temporary.mkdir()

    copy_runtime(project)
    write_web_export_preset(project)

    command = [str(ENGINE), "--headless", "--audio-driver", "Dummy", "--path", str(project)]
    environment = os.environ.copy()
    for variable in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
        environment[variable] = str(temporary)

    index_html = payload / "index.html"
    licenses_dir = payload / "licenses"
    licenses_dir.mkdir(exist_ok=True)

    with (build / "build.log").open("w", encoding="utf-8") as log:
        run_logged([*command, "--import"], log, environment)
        run_logged([*command, "--export-release", "Web HTML5 Competition", str(index_html)], log, environment)

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
        raise RuntimeError(f"Godot reported script errors during Web export; see {build / 'build.log'}")
    if not index_html.is_file():
        raise RuntimeError(f"Web export did not produce {index_html}")

    polish_html(index_html)

    (payload / "游玩说明.txt").write_text(
        "《澳诡实录》Web/HTML5 网页试玩版（团队：菜農子弟）\n\n"
        "【在线与本地运行说明】\n"
        "- 大赛官网/网页托管平台：上传后点击即可直接在浏览器游玩（单线程 WebGL2，无需特殊服务器请求头）。\n"
        "- 若需本地运行本网页目录：因浏览器禁止 file:// 直接加载 Wasm，请在当前目录运行 python -m http.server 8060 后访问 http://127.0.0.1:8060（离线也可直接用评审私有包内的 AomenParanormalRecords.exe）。\n\n"
        "【基础操作（PC 键鼠）】\n"
        "- WASD 移动 | Shift 冲刺 | Ctrl 蹲行 | 鼠标 观察与手电 | E 调查交互\n"
        "- F 手电 | B 背包 | M 地图 | Q/Tab 手机（含16枚澳门图鉴） | R 强闪 | H 提示 | Esc 暂停\n\n"
        "【手机/平板触屏操作（自动适配横屏与竖屏）】\n"
        "- 左半区摇杆：360° 移动（推到外圈自动冲刺，可在暂停页设置关闭）\n"
        "- 右半区空白处划动：独立转动手电照向\n"
        "- 右下角主按键：情境交互 / 躲藏按住屏息 / 拍照快门\n"
        "- 右手弧线副键：手电开关 / 蹲行 / 强闪驱鬼\n"
        "- 顶部快捷条：手机图鉴 / 背包 / 地图 / 笔记 / 提示 / 全屏 / 暂停\n",
        encoding="utf-8-sig",
    )

    credit_parts = []
    for label, src in [
        ("Godot Engine Licenses", licenses_dir / "Godot_Licenses.txt"),
        ("中文字体许可（Noto Serif SC / SIL OFL 1.1）", ROOT / "assets/fonts/SOURCE_LICENSE.md"),
        ("SIL OFL 1.1 全文", ROOT / "assets/fonts/OFL.txt"),
        ("V6 音效与纯粤语配音来源许可", ROOT / "docs/overhaul_v6/audio_credits_v6.md"),
        ("基础音效许可汇总", ROOT / "assets/audio/SOURCE_LICENSE.md"),
        ("Demo 音效许可", ROOT / "assets/audio/demo/SOURCE_LICENSE.md"),
        ("Recorded 音效许可", ROOT / "assets/audio/recorded/SOURCE_LICENSE.md"),
        ("Qubodup 音效许可", ROOT / "assets/audio/qubodup/SOURCE_LICENSE.md"),
        ("音效生成说明", ROOT / "docs/audio_generation_122.md"),
    ]:
        if src.is_file():
            credit_parts.append(f"================ {label} ================\n{src.read_text(encoding='utf-8', errors='replace').strip()}\n")
    godot_lic = licenses_dir / "Godot_Licenses.txt"
    if godot_lic.is_file():
        godot_lic.unlink()
    (licenses_dir / "LICENSE_AND_CREDITS.txt").write_text("\n\n".join(credit_parts), encoding="utf-8-sig")

    out_dir = SUBMISSION_ROOT / "03_公开试玩安装包"
    out_dir.mkdir(parents=True, exist_ok=True)
    archive = out_dir / "澳诡实录_Web网页试玩版.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
        for path in sorted(payload.rglob("*")):
            if path.is_file():
                bundle.write(path, path.relative_to(payload).as_posix())

    with zipfile.ZipFile(archive) as bundle:
        assert bundle.testzip() is None
        names = [PurePosixPath(m.filename).as_posix() for m in bundle.infolist()]
        if "index.html" not in names:
            raise RuntimeError("index.html missing from root of Web zip!")

    info = {
        "archive": str(archive),
        "archive_bytes": archive.stat().st_size,
        "archive_sha256": sha256(archive),
        "payload_dir": str(payload),
        "build": str(build),
    }
    (build / "web_verification.json").write_text(json.dumps(info, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"WEB_ARCHIVE={archive}")
    print(f"WEB_BYTES={archive.stat().st_size}")
    print(f"WEB_PAYLOAD={payload}")
    print(f"WEB_BUILD={build}")


if __name__ == "__main__":
    main()
