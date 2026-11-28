import gc
import os
import re
import subprocess
import sys
from pathlib import Path

for _proxy_key in ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy"):
    os.environ.pop(_proxy_key, None)

os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"
os.environ["HF_HUB_DISABLE_SYMLINKS_WARNING"] = "1"
os.environ["HF_HOME"] = r"d:\Aomen_Paranormal_Records\tools\voice_ai\hf_cache"
os.environ["HF_HUB_CACHE"] = r"d:\Aomen_Paranormal_Records\tools\voice_ai\hf_cache"

import numpy as np  # noqa: E402
import soundfile as sf  # noqa: E402
import torch  # noqa: E402
from qwen_tts import Qwen3TTSModel  # noqa: E402

AUD_ROOT = Path(r"d:\Aomen_Paranormal_Records\docs\overhaul_v6\voice_audition")
OUT_DIR = Path(r"d:\Aomen_Paranormal_Records\assets\audio\v6\voice")
TMP_DIR = AUD_ROOT / "qwen3_v2" / "_final_tmp"
BASE_MODEL_PATH = Path(r"d:\Aomen_Paranormal_Records\tools\voice_ai\qwen3_models\Qwen3-TTS-12Hz-1.7B-Base")

SPEAKER_REFS = {
    "jiamin": (
        AUD_ROOT / "qwen3_v2" / "routeA_jiamin_vd_01_daily.wav",
        "退后两步啦，将后面个大三巴牌坊都影埋入去嘛！哗，呢张构图唔错喎，陈大师傅今日总算冇手震。奖励你嘅，安德鲁葡挞仲辣手呀，趁热食！",
    ),
    "dawen": (
        AUD_ROOT / "qwen3_v2" / "routeA_dawen_vd_01_daily.wav",
        "唉，嘉敏，你喺度做咩呀？讲好嚟澳门食葡挞同猪扒包，点解又变成钻呢啲黑麻麻嘅旧楼㗎？快啲影完相落楼啦，阵间我请你食水蟹粥。",
    ),
    "ahhao": (
        AUD_ROOT / "qwen3_v2" / "routeA_zhihao_vd_01_daily.wav",
        "喂，姐夫！我而家上去二楼半后廊嗰度合埋个备用闸先啦，好快搞掂㗎咋，阵间楼梯口见喎！",
    ),
    "granny": (
        AUD_ROOT / "qwen3_v2" / "routeA_granny_vd_02_female.wav",
        "新鲜出炉呀，拿稳啲，挞皮一掂就碎㗎。唔好咁夜仲入去福荣里啲旧楼啦，小心呀。",
    ),
}

# Approved raw/team/bus clips processed cleanly with tempo tightening (11 clips)
DIRECT_PROCESSED = [
    ("bus_handrail_4lang_v6.wav", AUD_ROOT / "bus_fx" / "bus_handrail_4lang_pa_orig.wav", "atempo=1.04,highpass=f=80,loudnorm=I=-16:TP=-1.5:LRA=9"),
    ("bus_normal_pa_v6.wav", AUD_ROOT / "bus_fx" / "bus_normal_pa_orig.wav", "atempo=1.04,highpass=f=80,loudnorm=I=-16:TP=-1.5:LRA=9"),
    ("bus_anomaly_pa_v6.wav", AUD_ROOT / "bus_fx" / "bus_anomaly_pa_orig.wav", "atempo=1.04,highpass=f=80,loudnorm=I=-15:TP=-1.5:LRA=9"),
    ("bus_driver_pa_v6.wav", AUD_ROOT / "mastered" / "bus_driver_pa.wav", "silenceremove=start_periods=1:start_silence=0.04:start_threshold=-48dB,atempo=1.12,highpass=f=75,loudnorm=I=-16:TP=-1.5:LRA=9"),
    ("uncle_liang_01_v6.wav", AUD_ROOT / "mastered" / "uncle_liang_01_clean.wav", "silenceremove=start_periods=1:start_silence=0.04:start_threshold=-48dB,atempo=1.20,highpass=f=75,loudnorm=I=-16:TP=-1.5:LRA=9"),
    ("uncle_liang_02_v6.wav", AUD_ROOT / "mastered" / "uncle_liang_02_clean.wav", "silenceremove=start_periods=1:start_silence=0.04:start_threshold=-48dB,atempo=1.20,highpass=f=75,loudnorm=I=-16:TP=-1.5:LRA=9"),
    ("ahhao_chase_panic_v6.wav", AUD_ROOT / "mastered" / "zhihao_02_chase.wav", "silenceremove=start_periods=1:start_silence=0.03:start_threshold=-48dB,atempo=1.10,highpass=f=75,loudnorm=I=-16:TP=-1.5:LRA=9"),
    ("ahhao_ghost_99_v6.wav", AUD_ROOT / "mastered" / "zhihao_03_ghost_reverb.wav", "silenceremove=start_periods=1:start_silence=0.04:start_threshold=-48dB,atempo=1.10,highpass=f=75,loudnorm=I=-16:TP=-1.5:LRA=9"),
    ("ahhao_dying_v6.wav", AUD_ROOT / "mastered" / "zhihao_04_dying.wav", "silenceremove=start_periods=1:start_silence=0.03:start_threshold=-48dB,atempo=1.10,highpass=f=75,loudnorm=I=-16:TP=-1.5:LRA=9"),
    ("jiamin_304_scared_v6.wav", AUD_ROOT / "qwen3_v2" / "routeA_jiamin_vd_02_scared.wav", "silenceremove=start_periods=1:start_silence=0.03:start_threshold=-48dB,atempo=1.10,highpass=f=75,loudnorm=I=-16:TP=-1.5:LRA=9"),
    ("ahhao_enter_v6.wav", AUD_ROOT / "qwen3_v2" / "routeA_zhihao_vd_01_daily.wav", "silenceremove=start_periods=1:start_silence=0.03:start_threshold=-48dB,atempo=1.14,highpass=f=75,loudnorm=I=-16:TP=-1.5:LRA=9"),
]

TAPE_BODY_AF = "highpass=f=320,lowpass=f=3600,acompressor=threshold=-22dB:ratio=3:attack=10:release=140,aecho=0.8:0.8:16:0.12"
WALL_BODY_AF = "highpass=f=180,lowpass=f=2400,aecho=0.8:0.75:28:0.18"


def make_af(speed: float, extra: str = "") -> str:
    parts = [
        "silenceremove=start_periods=1:start_silence=0.03:start_threshold=-48dB",
        f"atempo={speed:.2f}",
        "highpass=f=75",
    ]
    if extra:
        parts.append(extra)
    parts.append("loudnorm=I=-16:TP=-1.5:LRA=9")
    return ",".join(parts)


# 18 Cloned Clips with strict single-speaker identity + pure colloquial HK/Macau Cantonese
CLONE_ITEMS = [
    # Jiamin (all from unified 女 C ref)
    ("jiamin_photo_invite_v6.wav", "jiamin", 301, ["喂，企后两步啦，将后面个大三巴牌坊都影埋入去嘛！"], make_af(1.18)),
    ("jiamin_photo_done_v6.wav", "jiamin", 312, ["呢张构图唔错喎！陈大师傅今日总算冇手震啦。"], make_af(1.18)),
    ("jiamin_pastry_offer_v6.wav", "jiamin", 313, ["多谢你呀，新鲜出炉嘅安德鲁葡挞仲辣手，快啲趁热食啦！"], make_af(1.18)),
    ("jiamin_pastry_plan_v6.wav", "jiamin", 304, ["睇半个钟咋嘛。有人话三零四床后面道暗门通去大三巴地下。", "影完去食水蟹粥，我请！"], make_af(1.18)),
    ("jiamin_knock_v6.wav", "jiamin", 305, ["旧楼入面冇信号㗎，万一走散咗就照旧规矩。", "敲两下、停一停、再敲一下，记住喎。"], make_af(1.18)),
    ("jiamin_enter_v6.wav", "jiamin", 306, ["我拎支手电先上三零四啦！大文你睇吓一楼个电表，阿豪去二楼半合备用闸。"], make_af(1.18)),
    ("jiamin_bunker_tape_v6.wav", "jiamin", 307, ["大文、阿豪！千祈唔好由正门落嚟！", "呢度有三道红衣人影堵死咗楼梯口，我将录音机留低喺度。", "而家经排风竖井走出去，直接去大关斜巷旧肉铺嗰边搵出路！"], make_af(1.16, TAPE_BODY_AF)),
    ("jiamin_ch6_wall_v6.wav", "jiamin", 318, ["大文，再敲一下，系你！", "我喺右边个隔离舱。", "嗰只嘢仲企喺门外，你先引开佢呀！"], make_af(1.12, WALL_BODY_AF)),
    ("jiamin_ch6_where_ahhao_v6.wav", "jiamin", 329, ["大文，阿豪而家喺边呀？", "佢有冇事㗎？"], make_af(1.10)),
    # Dawen (all from unified Dawen ref)
    ("dawen_pastry_reply_v6.wav", "dawen", 501, ["唉，讲好嚟澳门食葡挞同猪扒包㗎嘛，点解又变成钻呢啲黑麻麻嘅旧楼㗎？"], make_af(1.18)),
    ("dawen_knock_reply_v6.wav", "dawen", 502, ["两下，停一停，再一下，记住啦。楼入面睇唔清，你行慢啲呀。"], make_af(1.18)),
    ("dawen_foyer_v6.wav", "dawen", 503, ["唉，楼梯黑晒添……我先用工具钳拆开墙边个电表箱睇吓先。"], make_af(1.18)),
    ("dawen_meter_v6.wav", "dawen", 504, ["咦，三楼条支路断咗电喎。先拆盖睇吓测试表同埋值班台啲备件先。"], make_af(1.18)),
    ("dawen_stairs_v6.wav", "dawen", 525, ["嘉敏仲喺三楼等紧我呀，", "快啲整着盏楼梯灯，即刻上去！"], make_af(1.18)),
    ("dawen_ch6_answer_ahhao_v6.wav", "dawen", 516, ["佢挡喺唐楼楼梯口，推我入屋叫我先走。", "嘉敏，对唔住，我带唔返阿豪出嚟。"], make_af(1.12)),
    # Ah Hao (from unified Ah Hao ref)
    ("ahhao_street_01_v6.wav", "ahhao", 601, ["喂姐夫，我先调好支补光灯先啦！阵间入去旧楼就算冇灯都照影到㗎！"], make_af(1.18)),
    # Granny Chen (all from unified Granny A ref)
    ("granny_chen_01_v6.wav", "granny", 701, ["啱啱出炉呀，拎稳啲，挞皮一掂就碎㗎。", "你哋去福荣里呀？街坊讲嗰栋旧楼有个着黑袍嘅老人家，见人就问大三巴点行。", "楼梯响足成晚，点知佢行过去居然一点声都冇……"], make_af(1.22)),
    ("granny_chen_02_v6.wav", "granny", 702, ["要趁热食呀，冻咗返去烘一烘，挞皮先至脆㗎。"], make_af(1.22)),
]


def pad_ref(src: Path, dst: Path) -> str:
    subprocess.run(
        [
            "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
            "-i", str(src), "-af", "apad=pad_dur=0.45", "-ac", "1", "-ar", "24000", "-c:a", "pcm_s16le", str(dst),
        ],
        check=True,
    )
    return str(dst)


def norm_to_out(raw_path: Path, out_path: Path, af: str) -> None:
    subprocess.run(
        [
            "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
            "-i", str(raw_path),
            "-ac", "1", "-ar", "24000",
            "-af", af,
            "-c:a", "pcm_s16le",
            str(out_path),
        ],
        check=True,
    )


def audit_dir() -> int:
    wavs = sorted(OUT_DIR.glob("*.wav"))
    fails = 0
    for w in wavs:
        dur = float(
            subprocess.check_output(
                ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", str(w)]
            ).decode().strip()
        )
        vol = subprocess.check_output(
            ["ffmpeg", "-hide_banner", "-i", str(w), "-af", "volumedetect", "-f", "null", "NUL"],
            stderr=subprocess.STDOUT,
        ).decode("utf-8", errors="ignore")
        mean_db = float(re.search(r"mean_volume:\s*([-\d.]+)\s*dB", vol).group(1))
        max_db = float(re.search(r"max_volume:\s*([-\d.]+)\s*dB", vol).group(1))
        ok = dur >= 0.8 and mean_db > -42.0 and max_db <= -0.3
        if not ok:
            fails += 1
        print(f"  {'PASS' if ok else 'FAIL'} {w.name:34s} dur={dur:5.2f}s mean={mean_db:6.1f}dB max={max_db:5.1f}dB")
    print(f"FINAL_VOICE_PACK total={len(wavs)} failures={fails}")
    return 1 if fails else 0


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    TMP_DIR.mkdir(parents=True, exist_ok=True)

    only_filter = set(sys.argv[1:])

    for dst_name, src, af in DIRECT_PROCESSED:
        if only_filter and dst_name not in only_filter:
            continue
        if not src.exists():
            raise FileNotFoundError(f"Missing approved source wav: {src}")
        norm_to_out(src, OUT_DIR / dst_name, af)
        print(f"[proc] {dst_name}")

    pending = [it for it in CLONE_ITEMS if (not only_filter or it[0] in only_filter)]
    if pending:
        model = Qwen3TTSModel.from_pretrained(str(BASE_MODEL_PATH), device_map="cuda:0", dtype=torch.bfloat16, attn_implementation="sdpa")
        prompts = {}
        needed_speakers = {it[1] for it in pending}
        for spk_id in sorted(needed_speakers):
            src_wav, ref_text = SPEAKER_REFS[spk_id]
            if not src_wav.exists():
                raise FileNotFoundError(f"Missing speaker ref wav: {src_wav}")
            padded = pad_ref(src_wav, TMP_DIR / f"ref_{spk_id}_pad.wav")
            prompts[spk_id] = model.create_voice_clone_prompt(ref_audio=padded, ref_text=ref_text)
            print(f"[ref] built prompt for {spk_id}")

        for fname, spk_id, seed, chunks, af in pending:
            torch.manual_seed(seed)
            joined = []
            out_sr = 24000
            for idx, txt in enumerate(chunks):
                wavs, sr = model.generate_voice_clone(
                    text=txt,
                    language="Auto",
                    voice_clone_prompt=prompts[spk_id],
                    max_new_tokens=1536,
                )
                out_sr = sr
                joined.append(np.asarray(wavs[0], dtype=np.float32))
                if idx < len(chunks) - 1:
                    joined.append(np.zeros(int(sr * 0.14), dtype=np.float32))
            merged = np.concatenate(joined) if len(joined) > 1 else joined[0]
            raw_p = TMP_DIR / f"{fname}.raw.wav"
            sf.write(str(raw_p), merged, out_sr)
            norm_to_out(raw_p, OUT_DIR / fname, af)
            raw_p.unlink(missing_ok=True)
            print(f"[clone:{spk_id}] {fname}")
        del model
        gc.collect()
        torch.cuda.empty_cache()

    return audit_dir()


if __name__ == "__main__":
    sys.exit(main())
