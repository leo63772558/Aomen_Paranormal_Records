"""Fetch Godot 4.7.2 web_nothreads_release template (via HTTP Range) and build SIL OFL Noto Serif SC subset."""

from pathlib import Path
import struct
import urllib.request
import zipfile
import zlib

from fontTools.subset import Options, Subsetter
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = Path(__file__).resolve().parents[1]
RECOVERY = ROOT / "tools" / "recovery"
FONTS_DIR = ROOT / "assets" / "fonts"

TPZ_URLS = [
    "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz",
    "https://downloads.godotengine.org/?version=4.7.2&flavor=stable&slug=export_templates.tpz&platform=templates",
]
NOTO_TTF_URL = "https://github.com/google/fonts/raw/main/ofl/notoserifsc/NotoSerifSC%5Bwght%5D.ttf"
NOTO_OFL_URL = "https://github.com/google/fonts/raw/main/ofl/notoserifsc/OFL.txt"

WEB_TEMPLATE_OUT = RECOVERY / "web_nothreads_release_4.7.2.zip"
NOTO_VAR_TTF = RECOVERY / "NotoSerifSC_wght.ttf"
NOTO_SUBSET_TTF = FONTS_DIR / "noto_serif_sc_subset.ttf"
NOTO_OFL_OUT = FONTS_DIR / "OFL.txt"


def _req(url: str, method: str = "GET", headers: dict[str, str] | None = None, timeout: int = 30) -> urllib.request.Response:
    h = {"User-Agent": "Mozilla/5.0"}
    if headers:
        h.update(headers)
    return urllib.request.urlopen(urllib.request.Request(url, method=method, headers=h), timeout=timeout)


def download_web_template() -> None:
    if WEB_TEMPLATE_OUT.is_file():
        with zipfile.ZipFile(WEB_TEMPLATE_OUT) as zf:
            if zf.testzip() is None:
                print(f"[web-tpl] already cached: {WEB_TEMPLATE_OUT} ({WEB_TEMPLATE_OUT.stat().st_size} bytes)")
                return

    last_err = None
    for candidate in TPZ_URLS:
        try:
            with _req(candidate, method="HEAD", timeout=20) as r:
                final_url = r.url
                total_size = int(r.headers["Content-Length"])
            print(f"[web-tpl] resolved {final_url} ({total_size} bytes)")
            with _req(final_url, headers={"Range": f"bytes={total_size - 65536}-{total_size - 1}"}, timeout=30) as r:
                tail = r.read()
            eocd = tail.rfind(b"PK\x05\x06")
            if eocd < 0:
                raise RuntimeError("EOCD not found in tpz tail")
            cd_size, cd_off = struct.unpack("<II", tail[eocd + 12 : eocd + 20])
            with _req(final_url, headers={"Range": f"bytes={cd_off}-{cd_off + cd_size - 1}"}, timeout=30) as r:
                cd = r.read()
            pos = 0
            target = None
            while pos < len(cd):
                if cd[pos : pos + 4] != b"PK\x01\x02":
                    break
                comp_method = struct.unpack("<H", cd[pos + 10 : pos + 12])[0]
                comp_sz, uncomp_sz, fn_len, ex_len, cm_len = struct.unpack("<IIHHH", cd[pos + 20 : pos + 34])
                loc_off = struct.unpack("<I", cd[pos + 42 : pos + 46])[0]
                name = cd[pos + 46 : pos + 46 + fn_len].decode("utf-8", "ignore")
                if name == "templates/web_nothreads_release.zip":
                    target = (comp_method, comp_sz, uncomp_sz, loc_off, fn_len, ex_len)
                    break
                pos += 46 + fn_len + ex_len + cm_len
            if target is None:
                raise RuntimeError("templates/web_nothreads_release.zip not found in tpz central directory")
            comp_method, comp_sz, uncomp_sz, loc_off, _fn_len, _ex_len = target
            span = 4096 + comp_sz
            with _req(final_url, headers={"Range": f"bytes={loc_off}-{loc_off + span - 1}"}, timeout=120) as r:
                chunk = r.read()
            loc_fn_len, loc_ex_len = struct.unpack("<HH", chunk[26:30])
            start = 30 + loc_fn_len + loc_ex_len
            payload = chunk[start : start + comp_sz]
            if len(payload) != comp_sz:
                raise RuntimeError(f"Short read for template payload: {len(payload)} != {comp_sz}")
            data = payload if comp_method == 0 else zlib.decompress(payload, -15)
            if len(data) != uncomp_sz:
                raise RuntimeError(f"Uncompressed size mismatch: {len(data)} != {uncomp_sz}")
            WEB_TEMPLATE_OUT.parent.mkdir(parents=True, exist_ok=True)
            WEB_TEMPLATE_OUT.write_bytes(data)
            with zipfile.ZipFile(WEB_TEMPLATE_OUT) as zf:
                if zf.testzip() is not None:
                    raise RuntimeError("Extracted web_nothreads_release zip failed testzip()")
            print(f"[web-tpl] extracted {WEB_TEMPLATE_OUT} ({len(data)} bytes)")
            return
        except Exception as exc:
            last_err = exc
            print(f"[web-tpl] candidate failed ({candidate}): {exc}")
    raise RuntimeError(f"Failed to fetch Godot 4.7.2 Web export template: {last_err}")


def download_file(url: str, dst: Path) -> None:
    if dst.is_file() and dst.stat().st_size > 1000:
        print(f"[dl] cached {dst} ({dst.stat().st_size} bytes)")
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    with _req(url, timeout=120) as r:
        data = r.read()
    dst.write_bytes(data)
    print(f"[dl] saved {dst} ({len(data)} bytes)")


def build_font_subset() -> None:
    FONTS_DIR.mkdir(parents=True, exist_ok=True)
    download_file(NOTO_OFL_URL, NOTO_OFL_OUT)
    download_file(NOTO_TTF_URL, NOTO_VAR_TTF)

    chars: set[str] = set()
    for code in range(0x20, 0x7F):
        chars.add(chr(code))
    extra = (
        "，。、！？：；（）【】「」『』《》“”‘’—…·✦★☆○●▲▼◆◇→←↑↓×÷±°%℃㎡▪▫–＋－＝／＼｜～＆＠＃￥€£•"
        "澳诡实录菜農子弟李丞渊南京大学梁怀智洪鈿琰胡允贤黄俊斌正在加载请稍候并建议开启声音网页试玩版"
    )
    chars.update(extra)

    for folder in ("core", "entities", "levels", "ui"):
        base = ROOT / folder
        if not base.is_dir():
            continue
        for f in base.rglob("*"):
            if f.is_file() and f.suffix in (".gd", ".tscn", ".tres", ".json"):
                chars.update(f.read_text(encoding="utf-8-sig", errors="ignore"))

    var_font = TTFont(str(NOTO_VAR_TTF))
    inst = instantiateVariableFont(var_font, {"wght": 500})
    opts = Options()
    opts.hinting = True
    opts.layout_features = ["*"]
    subsetter = Subsetter(options=opts)
    subsetter.populate(text="".join(sorted(chars)))
    subsetter.subset(inst)
    inst.save(str(NOTO_SUBSET_TTF))
    print(f"[font] subsetted {len(chars)} unique chars -> {NOTO_SUBSET_TTF} ({NOTO_SUBSET_TTF.stat().st_size} bytes)")


def main() -> None:
    download_web_template()
    build_font_subset()


if __name__ == "__main__":
    main()
