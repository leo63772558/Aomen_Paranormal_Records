"""Serve extracted Web HTML5 build over local HTTP and verify desktop + multi-viewport mobile touch UI in Playwright Chromium."""

import functools
import http.server
import socketserver
import sys
import tempfile
import threading
import zipfile
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
WEB_ZIP = ROOT / "submission_20261127" / "03_公开试玩安装包" / "澳诡实录_Web网页试玩版.zip"
REPORT_DIR = ROOT / "docs" / "build_reports"


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        pass


class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True


def _wait_boot(page) -> None:
    page.wait_for_function(
        """() => {
            const st = document.getElementById('status');
            const cv = document.getElementById('canvas');
            if (!cv || cv.width <= 0) return false;
            if (!st) return true;
            const cs = getComputedStyle(st);
            return cs.display === 'none' || cs.visibility === 'hidden';
        }""",
        timeout=60000,
    )
    page.wait_for_timeout(1400)


def _tap_canvas_game_point(page, gx: float, gy: float) -> None:
    rect = page.evaluate("""() => {
        const cv = document.getElementById('canvas');
        const r = cv.getBoundingClientRect();
        const scale = Math.min(r.width / 640, r.height / 360);
        const gw = 640 * scale;
        const gh = 360 * scale;
        const left = r.left + (r.width - gw) * 0.5;
        const top = r.top + (r.height - gh) * 0.5;
        return { left, top, gw, gh };
    }""")
    cx = rect["left"] + rect["gw"] * (gx / 640.0)
    cy = rect["top"] + rect["gh"] * (gy / 360.0)
    page.mouse.click(cx, cy)


def _run_desktop_check(browser, url: str, page_errors: list[str], console_errors: list[str]) -> None:
    ctx = browser.new_context(viewport={"width": 1280, "height": 720}, has_touch=False, is_mobile=False)
    page = ctx.new_page()
    page.on("pageerror", lambda err: page_errors.append(f"[desktop] {err}"))
    page.on("console", lambda msg: console_errors.append(f"[desktop] {msg.text}") if msg.type == "error" else None)
    page.goto(url, wait_until="domcontentloaded")
    _wait_boot(page)
    touch_visible = page.evaluate("() => getComputedStyle(document.getElementById('aomen-mobile-ui')).display !== 'none'")
    if touch_visible:
        raise AssertionError("Desktop non-touch viewport unexpectedly showed mobile touch overlay!")
    page.screenshot(path=str(REPORT_DIR / "web_verify_menu.png"))
    _tap_canvas_game_point(page, 155.0, 200.0)
    page.wait_for_timeout(3200)
    page.screenshot(path=str(REPORT_DIR / "web_verify_street.png"))
    ctx.close()
    print("DESKTOP_OK touch_visible=False")


def _run_mobile_viewport(browser, url: str, name: str, width: int, height: int, page_errors: list[str], console_errors: list[str], interactive_test: bool = False) -> None:
    ctx = browser.new_context(
        viewport={"width": width, "height": height},
        has_touch=True,
        is_mobile=True,
        device_scale_factor=2,
    )
    page = ctx.new_page()
    page.on("pageerror", lambda err: page_errors.append(f"[{name}] {err}"))
    page.on("console", lambda msg: console_errors.append(f"[{name}] {msg.text}") if msg.type == "error" else None)
    page.goto(url, wait_until="domcontentloaded")
    _wait_boot(page)

    state = page.evaluate("() => window.__AOMEN_BRIDGE__ && window.__AOMEN_BRIDGE__.getState()")
    assert state and state.get("touchActive") is True, f"{name}: touchActive not True: {state}"
    if height > width * 1.12:
        assert state.get("portrait") is True, f"{name}: expected portrait layout"

    # Start New Game (on menu, touch controls are hidden so tap canvas button)
    _tap_canvas_game_point(page, 155.0, 200.0)
    page.wait_for_timeout(3200)

    # Advance opening dialogue if open by tapping canvas dialogue panel
    for _ in range(4):
        st = page.evaluate("() => window.__AOMEN_BRIDGE__.getState()")
        if st.get("mode") in ("dialogue", "cutscene"):
            _tap_canvas_game_point(page, 320.0, 100.0)
            page.wait_for_timeout(450)
        else:
            break

    page.wait_for_timeout(600)
    st_explore = page.evaluate("() => window.__AOMEN_BRIDGE__.getState()")
    shot_path = REPORT_DIR / f"web_mobile_{name}.png"
    page.screenshot(path=str(shot_path))
    print(f"MOBILE_{name.upper()} mode={st_explore.get('mode')} portrait={st_explore.get('portrait')} shot={shot_path.name}")

    # Verify controls do not overflow viewport
    bounds_ok = page.evaluate("""() => {
        const vw = window.innerWidth;
        const vh = window.innerHeight;
        const ids = ['ao-btn-primary', 'ao-btn-crouch', 'ao-pill-pause', 'ao-joy-base'];
        for (const id of ids) {
            const el = document.getElementById(id);
            if (!el || getComputedStyle(el).display === 'none') continue;
            const r = el.getBoundingClientRect();
            if (r.width === 0 || r.height === 0) continue;
            if (r.left < -2 || r.top < -2 || r.right > vw + 2 || r.bottom > vh + 2) {
                return { ok: false, id, rect: { l: r.left, t: r.top, r: r.right, b: r.bottom }, vw, vh };
            }
        }
        return { ok: true };
    }""")
    assert bounds_ok.get("ok"), f"{name}: UI element out of bounds: {bounds_ok}"

    if interactive_test:
        # Test joystick drag + pause menu open
        joy_rect = page.evaluate("""() => {
            const r = document.getElementById('ao-joy-zone').getBoundingClientRect();
            return { cx: r.left + r.width * 0.45, cy: r.top + r.height * 0.55 };
        }""")
        page.mouse.move(joy_rect["cx"], joy_rect["cy"])
        page.mouse.down()
        page.mouse.move(joy_rect["cx"] + 54, joy_rect["cy"] - 10, steps=5)
        page.wait_for_timeout(250)
        page.mouse.up()

        # Open pause menu via touch pause pill
        pause_rect = page.evaluate("""() => {
            const r = document.getElementById('ao-pill-pause').getBoundingClientRect();
            return { cx: r.left + r.width * 0.5, cy: r.top + r.height * 0.5 };
        }""")
        page.mouse.click(pause_rect["cx"], pause_rect["cy"])
        page.wait_for_timeout(500)
        st_pause = page.evaluate("() => window.__AOMEN_BRIDGE__.getState()")
        assert st_pause.get("mode") in ("dialogue", "modal"), f"Expected pause panel after tapping pause, got {st_pause}"
        pause_shot = REPORT_DIR / f"web_mobile_{name}_pause.png"
        page.screenshot(path=str(pause_shot))
        print(f"MOBILE_{name.upper()}_PAUSE mode={st_pause.get('mode')} shot={pause_shot.name}")

    ctx.close()


def main() -> int:
    if not WEB_ZIP.is_file():
        print(f"MISSING WEB ZIP: {WEB_ZIP}")
        return 1

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="aomen_web_verify_") as tmp:
        with zipfile.ZipFile(WEB_ZIP) as zf:
            zf.extractall(tmp)

        handler = functools.partial(QuietHandler, directory=tmp)
        httpd = ThreadedHTTPServer(("127.0.0.1", 0), handler)
        port = httpd.server_address[1]
        t = threading.Thread(target=httpd.serve_forever, daemon=True)
        t.start()
        url = f"http://127.0.0.1:{port}/index.html"
        print(f"SERVING {url}")

        page_errors: list[str] = []
        console_errors: list[str] = []
        try:
            with sync_playwright() as p:
                browser = p.chromium.launch(
                    headless=True,
                    args=[
                        "--use-gl=angle",
                        "--use-angle=swiftshader",
                        "--enable-webgl",
                        "--ignore-gpu-blocklist",
                    ],
                )
                _run_desktop_check(browser, url, page_errors, console_errors)
                _run_mobile_viewport(browser, url, "se_landscape", 667, 375, page_errors, console_errors)
                _run_mobile_viewport(browser, url, "max_landscape", 932, 430, page_errors, console_errors, interactive_test=True)
                _run_mobile_viewport(browser, url, "phone_portrait", 390, 844, page_errors, console_errors, interactive_test=True)
                _run_mobile_viewport(browser, url, "ipad_4_3", 1024, 768, page_errors, console_errors)
                _run_mobile_viewport(browser, url, "fold_square", 717, 512, page_errors, console_errors)
                browser.close()
        finally:
            httpd.shutdown()
            httpd.server_close()

    print(f"PAGE_ERRORS={len(page_errors)} CONSOLE_ERRORS={len(console_errors)}")
    for e in page_errors:
        print("  PAGEERROR:", e)
    for c in console_errors:
        print("  CONSOLE_ERR:", c)
    return 1 if page_errors or any("SCRIPT ERROR" in c or "WebGL" in c or "Aborted" in c for c in console_errors) else 0


if __name__ == "__main__":
    sys.exit(main())
