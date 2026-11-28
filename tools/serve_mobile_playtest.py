"""Serve the built Web/HTML5 package on LAN with a scannable QR code entry page for mobile playtesting."""

from __future__ import annotations

import argparse
import functools
import http.server
import html
import ipaddress
import mimetypes
import socket
import socketserver
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB_ZIP = ROOT / "submission_20261127" / "03_公开试玩安装包" / "澳诡实录_Web网页试玩版.zip"
EXTRACT_DIR = ROOT / "tools" / "recovery" / "mobile_live_preview"


# --- Minimal ISO/IEC 18004 QR Code SVG Generator (Byte mode, EC Level M, Versions 1-4) ---
_QR_SPECS = [
    # (version, size, data_cap_bytes, data_cw, ec_cw_per_block, blocks, align_pos, remainder_bits)
    (1, 21, 14, 16, 10, 1, [], 0),
    (2, 25, 26, 28, 16, 1, [6, 18], 7),
    (3, 29, 42, 44, 26, 1, [6, 22], 7),
    (4, 33, 62, 64, 18, 2, [6, 26], 7),
]


def _gf_tables():
    exp = [0] * 512
    log = [0] * 256
    x = 1
    for i in range(255):
        exp[i] = x
        log[x] = i
        x <<= 1
        if x & 0x100:
            x ^= 0x11D
    for i in range(255, 512):
        exp[i] = exp[i - 255]
    return exp, log


_GF_EXP, _GF_LOG = _gf_tables()


def _gf_mul(a: int, b: int) -> int:
    if a == 0 or b == 0:
        return 0
    return _GF_EXP[_GF_LOG[a] + _GF_LOG[b]]


def _rs_gen_poly(degree: int) -> list[int]:
    poly = [1]
    for i in range(degree):
        root = _GF_EXP[i]
        nxt = [0] * (len(poly) + 1)
        for j, coef in enumerate(poly):
            nxt[j] ^= coef
            nxt[j + 1] ^= _gf_mul(coef, root)
        poly = nxt
    return poly


def _rs_encode(data: list[int], ec_len: int) -> list[int]:
    gen = _rs_gen_poly(ec_len)
    msg = list(data) + [0] * ec_len
    for i in range(len(data)):
        coef = msg[i]
        if coef != 0:
            for j in range(1, len(gen)):
                msg[i + j] ^= _gf_mul(gen[j], coef)
    return msg[len(data):]


def _make_qr_matrix(text: str) -> list[list[int]]:
    raw = text.encode("utf-8")
    spec = None
    for row in _QR_SPECS:
        if len(raw) <= row[2]:
            spec = row
            break
    if spec is None:
        raise ValueError(f"URL too long for V1-V4 QR: {len(raw)} bytes")

    _ver, n, _cap, data_cw, ec_cw, blocks, align, rem_bits = spec

    bits: list[int] = []

    def push_bits(val: int, width: int) -> None:
        for shift in range(width - 1, -1, -1):
            bits.append((val >> shift) & 1)

    push_bits(0b0100, 4)  # Byte mode
    push_bits(len(raw), 8)
    for b in raw:
        push_bits(b, 8)

    max_bits = data_cw * 8
    term = min(4, max_bits - len(bits))
    push_bits(0, term)
    while len(bits) % 8 != 0:
        bits.append(0)

    cw: list[int] = []
    for i in range(0, len(bits), 8):
        byte = 0
        for j in range(8):
            byte = (byte << 1) | bits[i + j]
        cw.append(byte)

    pad_bytes = [0xEC, 0x11]
    idx = 0
    while len(cw) < data_cw:
        cw.append(pad_bytes[idx % 2])
        idx += 1

    per_block = data_cw // blocks
    data_blocks: list[list[int]] = []
    ec_blocks: list[list[int]] = []
    for b in range(blocks):
        blk = cw[b * per_block:(b + 1) * per_block]
        data_blocks.append(blk)
        ec_blocks.append(_rs_encode(blk, ec_cw))

    stream_cw: list[int] = []
    for i in range(per_block):
        for blk in data_blocks:
            stream_cw.append(blk[i])
    for i in range(ec_cw):
        for blk in ec_blocks:
            stream_cw.append(blk[i])

    stream_bits: list[int] = []
    for byte in stream_cw:
        for s in range(7, -1, -1):
            stream_bits.append((byte >> s) & 1)
    stream_bits.extend([0] * rem_bits)

    mat = [[-1] * n for _ in range(n)]
    func = [[False] * n for _ in range(n)]

    def set_fn(r: int, c: int, val: int) -> None:
        mat[r][c] = val
        func[r][c] = True

    def place_finder(top: int, left: int) -> None:
        for dr in range(-1, 8):
            for dc in range(-1, 8):
                r, c = top + dr, left + dc
                if 0 <= r < n and 0 <= c < n:
                    if dr in (-1, 7) or dc in (-1, 7):
                        set_fn(r, c, 0)
                    elif dr in (0, 6) or dc in (0, 6) or (2 <= dr <= 4 and 2 <= dc <= 4):
                        set_fn(r, c, 1)
                    else:
                        set_fn(r, c, 0)

    place_finder(0, 0)
    place_finder(0, n - 7)
    place_finder(n - 7, 0)

    for i in range(8, n - 8):
        set_fn(6, i, 1 if i % 2 == 0 else 0)
        set_fn(i, 6, 1 if i % 2 == 0 else 0)

    set_fn(n - 8, 8, 1)

    for r_c in align:
        for c_c in align:
            if func[r_c][c_c]:
                continue
            for dr in range(-2, 3):
                for dc in range(-2, 3):
                    val = 1 if (abs(dr) == 2 or abs(dc) == 2 or (dr == 0 and dc == 0)) else 0
                    set_fn(r_c + dr, c_c + dc, val)

    # Reserve format info cells
    for i in range(9):
        if not func[8][i]:
            func[8][i] = True
        if not func[i][8]:
            func[i][8] = True
    for i in range(n - 8, n):
        func[8][i] = True
    for i in range(n - 7, n):
        func[i][8] = True

    # Place data bits
    b_idx = 0
    col = n - 1
    up = True
    while col > 0:
        if col == 6:
            col -= 1
        rows = range(n - 1, -1, -1) if up else range(n)
        for r in rows:
            for dc in (0, -1):
                c = col + dc
                if not func[r][c]:
                    mat[r][c] = stream_bits[b_idx] if b_idx < len(stream_bits) else 0
                    b_idx += 1
        up = not up
        col -= 2

    def mask_fn(m: int, r: int, c: int) -> bool:
        if m == 0:
            return (r + c) % 2 == 0
        if m == 1:
            return r % 2 == 0
        if m == 2:
            return c % 3 == 0
        if m == 3:
            return (r + c) % 3 == 0
        if m == 4:
            return (r // 2 + c // 3) % 2 == 0
        if m == 5:
            return (r * c) % 2 + (r * c) % 3 == 0
        if m == 6:
            return ((r * c) % 2 + (r * c) % 3) % 2 == 0
        return ((r + c) % 2 + (r * c) % 3) % 2 == 0

    def apply_format(grid: list[list[int]], mask_id: int) -> None:
        d = (0b00 << 3) | mask_id  # EC Level M = 00
        v = d << 10
        for bit in range(14, 9, -1):
            if (v >> bit) & 1:
                v ^= 0x537 << (bit - 10)
        fmt = ((d << 10) | v) ^ 0x5412
        for i in range(6):
            bit = (fmt >> i) & 1
            grid[8][i] = bit
            grid[n - 1 - i][8] = bit
        grid[8][7] = (fmt >> 6) & 1
        grid[n - 7][8] = (fmt >> 6) & 1
        grid[8][8] = (fmt >> 7) & 1
        grid[8][n - 8] = (fmt >> 7) & 1
        grid[7][8] = (fmt >> 8) & 1
        grid[8][n - 7] = (fmt >> 8) & 1
        for i in range(9, 15):
            bit = (fmt >> i) & 1
            grid[14 - i][8] = bit
            grid[8][n - 15 + i] = bit

    def penalty(grid: list[list[int]]) -> int:
        score = 0
        for r in range(n):
            run = 1
            for c in range(1, n):
                if grid[r][c] == grid[r][c - 1]:
                    run += 1
                else:
                    if run >= 5:
                        score += 3 + (run - 5)
                    run = 1
            if run >= 5:
                score += 3 + (run - 5)
        for c in range(n):
            run = 1
            for r in range(1, n):
                if grid[r][c] == grid[r - 1][c]:
                    run += 1
                else:
                    if run >= 5:
                        score += 3 + (run - 5)
                    run = 1
            if run >= 5:
                score += 3 + (run - 5)
        for r in range(n - 1):
            for c in range(n - 1):
                s = grid[r][c] + grid[r][c + 1] + grid[r + 1][c] + grid[r + 1][c + 1]
                if s in (0, 4):
                    score += 3
        dark = sum(sum(row) for row in grid)
        pct = abs((dark * 100) / (n * n) - 50)
        score += int(pct // 5) * 10
        return score

    best_grid = None
    best_score = 10**9
    for m in range(8):
        cand = [list(row) for row in mat]
        for r in range(n):
            for c in range(n):
                if not func[r][c] and mask_fn(m, r, c):
                    cand[r][c] ^= 1
        apply_format(cand, m)
        sc = penalty(cand)
        if sc < best_score:
            best_score = sc
            best_grid = cand
    return best_grid  # type: ignore[return-value]


def qr_svg(url: str, size_px: int = 232) -> str:
    grid = _make_qr_matrix(url)
    n = len(grid)
    quiet = 4
    total = n + quiet * 2
    rects = []
    for r in range(n):
        for c in range(n):
            if grid[r][c] == 1:
                rects.append(f'<rect x="{c + quiet}" y="{r + quiet}" width="1" height="1"/>')
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {total} {total}" '
        f'width="{size_px}" height="{size_px}" shape-rendering="crispEdges">'
        f'<rect width="{total}" height="{total}" fill="#f5eedc"/>'
        f'<g fill="#0c1914">{"".join(rects)}</g></svg>'
    )


def detect_lan_ips() -> list[tuple[str, str]]:
    candidates: list[tuple[int, str, str]] = []
    try:
        out = subprocess.check_output(
            [
                "powershell",
                "-NoProfile",
                "-Command",
                "Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } | ForEach-Object { $_.InterfaceAlias + '|' + $_.IPAddress }",
            ],
            text=True,
            timeout=5,
        )
        for line in out.splitlines():
            if "|" not in line:
                continue
            alias, ip = [p.strip() for p in line.split("|", 1)]
            try:
                addr = ipaddress.IPv4Address(ip)
            except ValueError:
                continue
            if addr.is_loopback or addr.is_link_local:
                continue
            low = alias.lower()
            prio = 2
            if any(k in low for k in ("wlan", "wi-fi", "wifi", "ethernet", "以太网")):
                prio = 0
            elif any(k in low for k in ("vmware", "virtual", "vbox", "hyper-v", "vethernet", "loopback")):
                prio = 4
            candidates.append((prio, alias, ip))
    except Exception:
        pass

    if not candidates:
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.connect(("8.8.8.8", 80))
            ip = sock.getsockname()[0]
            sock.close()
            candidates.append((1, "Default", ip))
        except Exception:
            pass

    candidates.sort(key=lambda item: item[0])
    seen = set()
    result: list[tuple[str, str]] = []
    for _prio, alias, ip in candidates:
        if ip not in seen:
            seen.add(ip)
            result.append((alias, ip))
    return result


def ensure_extracted() -> None:
    if not WEB_ZIP.is_file():
        raise FileNotFoundError(f"Missing Web ZIP: {WEB_ZIP}")
    stamp_file = EXTRACT_DIR / ".zip_mtime"
    zip_mtime = str(WEB_ZIP.stat().st_mtime_ns)
    if EXTRACT_DIR.is_dir() and stamp_file.is_file() and stamp_file.read_text(encoding="utf-8").strip() == zip_mtime:
        if (EXTRACT_DIR / "index.html").is_file():
            return
    if EXTRACT_DIR.exists():
        for p in sorted(EXTRACT_DIR.rglob("*"), reverse=True):
            if p.is_file() or p.is_symlink():
                p.unlink()
            elif p.is_dir():
                p.rmdir()
    EXTRACT_DIR.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(WEB_ZIP) as zf:
        zf.extractall(EXTRACT_DIR)
    stamp_file.write_text(zip_mtime, encoding="utf-8")


class MobilePlaytestHandler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".js": "application/javascript; charset=utf-8",
        ".pck": "application/octet-stream",
        ".html": "text/html; charset=utf-8",
        ".json": "application/json; charset=utf-8",
        ".png": "image/png",
        ".svg": "image/svg+xml",
    }

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        super().end_headers()

    def log_message(self, format: str, *args) -> None:
        pass

    def do_GET(self) -> None:
        path = self.path.split("?", 1)[0]
        if path in ("/qr", "/qr/"):
            self._serve_qr_page()
            return
        super().do_GET()

    def _serve_qr_page(self) -> None:
        port = self.server.server_address[1]
        ips = detect_lan_ips()
        primary_ip = ips[0][1] if ips else "127.0.0.1"
        mobile_url = f"http://{primary_ip}:{port}/"
        pc_touch_url = f"http://127.0.0.1:{port}/?touch=1"
        pc_url = f"http://127.0.0.1:{port}/"
        try:
            svg_markup = qr_svg(mobile_url)
        except Exception as exc:
            svg_markup = f"<p>QR生成失败: {html.escape(str(exc))}</p>"

        alt_links = "".join(
            f'<li><code>http://{html.escape(ip)}:{port}/</code>（{html.escape(alias)}）</li>'
            for alias, ip in ips
        )

        body = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>《澳诡实录》手机局域网试玩入口</title>
<style>
  body {{
    margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center;
    background: radial-gradient(circle at 50% 25%, #13281f 0%, #070e0a 100%);
    color: #ebe3c8; font-family: 'Noto Serif SC', 'Microsoft YaHei', sans-serif; padding: 20px; box-sizing: border-box;
  }}
  .card {{
    max-width: 680px; width: 100%; background: rgba(11, 24, 19, 0.94);
    border: 1.5px solid #b89c5e; border-radius: 10px; padding: 24px 28px;
    box-shadow: 0 18px 48px rgba(0, 0, 0, 0.65);
  }}
  h1 {{ margin: 0 0 6px; font-size: 22px; color: #f6e4aa; }}
  .sub {{ margin: 0 0 18px; color: #b7c8b8; font-size: 13px; }}
  .row {{ display: flex; flex-wrap: wrap; gap: 24px; align-items: center; }}
  .qr-box {{
    background: #f5eedc; padding: 10px; border-radius: 8px; border: 2px solid #c9ad6a;
    flex-shrink: 0;
  }}
  .info {{ flex: 1; min-width: 240px; line-height: 1.75; font-size: 14px; }}
  code {{
    background: rgba(255,255,255,0.08); padding: 2px 7px; border-radius: 4px;
    color: #ffe79e; font-size: 13px; word-break: break-all;
  }}
  .btns {{ display: flex; flex-wrap: wrap; gap: 10px; margin-top: 14px; }}
  a.btn {{
    display: inline-block; padding: 8px 14px; border-radius: 6px; text-decoration: none;
    background: #1b3b2d; color: #f6e4aa; border: 1px solid #c9ad6a; font-size: 13px;
  }}
  a.btn:hover {{ background: #26523e; }}
  ul {{ margin: 8px 0 0; padding-left: 18px; color: #c7d6c8; font-size: 13px; }}
</style>
</head>
<body>
  <div class="card">
    <h1>《澳诡实录》手机网页试玩入口</h1>
    <p class="sub">手机与电脑连接同一 Wi-Fi 后，用手机浏览器或相机扫码即可直接游玩（横屏/竖屏全尺寸自适应）。</p>
    <div class="row">
      <div class="qr-box">{svg_markup}</div>
      <div class="info">
        <div><b>手机访问地址：</b><br><code>{html.escape(mobile_url)}</code></div>
        <div class="btns">
          <a class="btn" href="{html.escape(pc_touch_url)}" target="_blank">电脑模拟手机触屏预览</a>
          <a class="btn" href="{html.escape(pc_url)}" target="_blank">电脑原版键鼠打开</a>
        </div>
        <ul>
          <li>如手机打不开：请确认手机与本机在同一局域网，或临时放行 Windows 防火墙端口 <code>{port}</code>。</li>
          <li>本机可用网卡列表：<ul>{alt_links}</ul></li>
        </ul>
      </div>
    </div>
  </div>
</body>
</html>"""
        raw = body.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)


class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main() -> int:
    parser = argparse.ArgumentParser(description="Serve Aomen Web build for mobile LAN playtesting.")
    parser.add_argument("--port", type=int, default=8068)
    args = parser.parse_args()

    ensure_extracted()
    mimetypes.init()
    handler = functools.partial(MobilePlaytestHandler, directory=str(EXTRACT_DIR))
    httpd = ThreadedHTTPServer(("0.0.0.0", args.port), handler)
    ips = detect_lan_ips()
    primary_ip = ips[0][1] if ips else "127.0.0.1"
    print(f"MOBILE_URL=http://{primary_ip}:{args.port}/", flush=True)
    print(f"QR_URL=http://127.0.0.1:{args.port}/qr", flush=True)
    print(f"PC_TOUCH_URL=http://127.0.0.1:{args.port}/?touch=1", flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.shutdown()
        httpd.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
