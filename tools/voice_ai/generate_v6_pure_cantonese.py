import argparse
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

def _load_qwen_tts_model(model_dir: Path):
    from qwen_tts import Qwen3TTSModel
    return Qwen3TTSModel.from_pretrained(str(model_dir), device_map="cuda:0", dtype=torch.bfloat16, attn_implementation="sdpa")

AUD_ROOT = Path(r"d:\Aomen_Paranormal_Records\docs\overhaul_v6\voice_audition")
V2_REFS = AUD_ROOT / "qwen3_v2"
MODELS_DIR = Path(r"d:\Aomen_Paranormal_Records\tools\voice_ai\qwen3_models")
HK_BASE_DIR = MODELS_DIR / "hk-cantonese-base"
HK_FEMALE_DIR = MODELS_DIR / "hk-cantonese-female"
VD_DIR = MODELS_DIR / "Qwen3-TTS-12Hz-1.7B-VoiceDesign"
RAW_BASE_DIR = MODELS_DIR / "Qwen3-TTS-12Hz-1.7B-Base"

OUT_DIR = Path(r"d:\Aomen_Paranormal_Records\assets\audio\v6\voice")
SMOKE_DIR = AUD_ROOT / "qwen3_v2" / "_smoke_hk"
STAGE_A_DIR = AUD_ROOT / "qwen3_v2" / "_stage_a_hk"
TMP_DIR = AUD_ROOT / "qwen3_v2" / "_final_tmp"

SPEAKER_REFS = {
    "jiamin": (
        V2_REFS / "routeA_jiamin_vd_01_daily.wav",
        "退後兩步啦，將後面個大三巴牌坊都影埋入去嘛！嘩，呢張構圖唔錯喎，陳大師傅今日總算冇手震。獎勵你嘅，安德魯葡撻仲辣手呀，趁熱食！",
    ),
    "dawen": (
        V2_REFS / "routeA_dawen_vd_01_daily.wav",
        "唉，嘉敏，你喺度做咩呀？講好嚟澳門食葡撻同豬扒包，點解又變成鑽呢啲黑麻麻嘅舊樓㗎？快啲影完相落樓啦，陣間我請你食水蟹粥。",
    ),
    "ahhao": (
        V2_REFS / "ref_ahhao_clean.wav",
        "我而家上去二樓半後廊嗰度合埋個備用閘先啦，好快搞掂㗎咋，陣間樓梯口見喎！",
    ),
    "granny": (
        V2_REFS / "routeA_granny_vd_02_female.wav",
        "新鮮出爐呀，拎穩啲，撻皮一掂就碎㗎。唔好咁夜仲入去福榮里啲舊樓啦，小心呀。",
    ),
    "liang": (
        V2_REFS / "ref_uncle_liang_vd.wav",
        "兩位咁夜仲過嚟飲涼茶呀？福榮里嗰邊啲舊唐樓，呢排唔係幾太平喎。",
    ),
    "driver": (
        V2_REFS / "ref_bus_driver_clean.wav",
        "自己投六蚊入箱，行入去坐穩扶手。",
    ),
}

TAPE_BODY_AF = "highpass=f=320,lowpass=f=3600,acompressor=threshold=-22dB:ratio=3:attack=10:release=140,aecho=0.8:0.8:16:0.12"
WALL_BODY_AF = "highpass=f=180,lowpass=f=2400,aecho=0.8:0.75:28:0.18"
STAIR_REVERB_AF = "highpass=f=180,lowpass=f=3400,aecho=0.8:0.86:55|115:0.32|0.18"
DRIVER_MIC_AF = "highpass=f=240,lowpass=f=4200,aecho=0.85:0.70:18:0.12"
BUS_PA_EQ = "highpass=f=320,lowpass=f=3800,acompressor=threshold=-20dB:ratio=3:attack=8:release=120,aecho=0.85:0.75:24:0.16"
BUS_ANOM_EQ = "asetrate=24000*0.92,aresample=24000,highpass=f=260,lowpass=f=3200,aecho=0.8:0.86:48:0.32"


def make_af(speed: float, extra: str = "") -> str:
    parts = [
        "silenceremove=start_periods=1:start_silence=0.03:start_threshold=-48dB",
        "areverse,silenceremove=start_periods=1:start_silence=0.03:start_threshold=-54dB,areverse",
        f"atempo={speed:.2f}",
        "highpass=f=75",
    ]
    if extra:
        parts.append(extra)
    parts.append("loudnorm=I=-16:TP=-1.5:LRA=9")
    return ",".join(parts)


# 25 character voice lines (each chunk <= 45 chars at punctuation, 100% colloquial Traditional HK/Macau Cantonese)
CHARACTER_CLIPS = [
    # Jiamin (10 clips - unified on hk_voice_343)
    ("jiamin_photo_invite_v6.wav", "jiamin", 301, ["喂，企後兩步啦，將後面個大三巴牌坊都影埋入去嘛！"], make_af(1.16)),
    ("jiamin_photo_done_v6.wav", "jiamin", 315, ["呢張構圖唔錯喎！陳大師傅今日總算冇手震啦。"], make_af(1.14)),
    ("jiamin_pastry_offer_v6.wav", "jiamin", 313, ["多謝你呀，新鮮出爐嘅安德魯葡撻仲辣手，快啲趁熱食啦！"], make_af(1.16)),
    ("jiamin_pastry_plan_v6.wav", "jiamin", 304, ["睇半個鐘咋嘛。有人話三零四床後面道暗門通去大三巴地下。", "影完去食水蟹粥，我請！"], make_af(1.16)),
    ("jiamin_knock_v6.wav", "jiamin", 305, ["舊樓入面冇信號㗎，萬一走散咗就照舊規矩。", "敲兩下、停一停、再敲一下，記住喎。"], make_af(1.16)),
    ("jiamin_enter_v6.wav", "jiamin", 316, ["我拎支手電先上三零四啦！大文你睇吓一樓個電表，阿豪去二樓半合後備掣。"], make_af(1.14)),
    ("jiamin_304_scared_v6.wav", "jiamin", 321, ["大文！快啲入嚟三零四閂門呀！", "後面樓梯有隻嘢跟住過嚟，千祈唔好望返轉頭！"], make_af(1.14)),
    ("jiamin_bunker_tape_v6.wav", "jiamin", 307, ["大文、阿豪！千祈唔好由正門落嚟！", "呢度有三道紅衣人影堵死咗樓梯口，我將錄音機留低喺度。", "而家經排風豎井走出去，直接去大關斜巷舊肉舖嗰邊搵出路！"], make_af(1.14, TAPE_BODY_AF)),
    ("jiamin_ch6_wall_v6.wav", "jiamin", 319, ["大文，係你！我喺右邊個隔離房。嗰隻嘢仲企喺門外，快啲拉電掣開聲呐引開佢呀！"], make_af(1.10, WALL_BODY_AF)),
    ("jiamin_ch6_where_ahhao_v6.wav", "jiamin", 333, ["大文，阿豪而家喺邊呀？佢有冇事㗎？"], make_af(1.08)),
    # Dawen (6 clips - native hk-cantonese-base voice clone)
    ("dawen_pastry_reply_v6.wav", "dawen", 511, ["唉，講好嚟澳門食葡撻同豬扒包㗎嘛，點解又變成鑽呢啲黑麻麻嘅舊樓㗎？"], make_af(1.10)),
    ("dawen_knock_reply_v6.wav", "dawen", 512, ["兩下，停一停，再一下，記住啦。樓入面睇唔清，你行慢啲呀。"], make_af(1.10)),
    ("dawen_foyer_v6.wav", "dawen", 513, ["唉，樓梯黑晒添……我先用工具夾拆開牆邊個電表箱睇吓先。"], make_af(1.10)),
    ("dawen_meter_v6.wav", "dawen", 514, ["咦，三樓條支路斷咗電喎。先拆蓋睇吓測試表同埋值班台啲備件先。"], make_af(1.10)),
    ("dawen_stairs_v6.wav", "dawen", 515, ["嘉敏仲喺三樓等緊我呀，快啲整著盞樓梯燈，即刻上去！"], make_af(1.12)),
    ("dawen_ch6_answer_ahhao_v6.wav", "dawen", 516, ["佢頂住唐樓樓梯口，推我入屋叫我先走。嘉敏，對唔住，我帶唔返阿豪出嚟。"], make_af(1.06)),
    # Ah Hao (5 clips - native hk-cantonese-base voice clone)
    ("ahhao_street_01_v6.wav", "ahhao", 611, ["喂，姐夫！我先調好支補光燈啦，陣間入去舊樓就算冇燈都照影到㗎！"], make_af(1.10)),
    ("ahhao_enter_v6.wav", "ahhao", 612, ["喂，姐夫！我而家上去二樓半後廊合埋個後備掣先，好快搞掂㗎咋，陣間樓梯口見喎！"], make_af(1.10)),
    ("ahhao_chase_panic_v6.wav", "ahhao", 613, ["姐夫！後面有嘢追緊過嚟呀！快啲走，唔好望返轉頭！"], make_af(1.12)),
    ("ahhao_ghost_99_v6.wav", "ahhao", 614, ["姐夫……我隻手好痛呀，唔好留低我喺度，返嚟救我呀……"], make_af(1.04, STAIR_REVERB_AF)),
    ("ahhao_dying_v6.wav", "ahhao", 635, ["姐夫，你快啲入屋關實門唔好理我，搵返家姐帶佢走呀。"], make_af(1.04)),
    # Granny Chen (2 clips - Seed-VC from pure HK Stage-A -> Granny ref)
    ("granny_chen_01_v6.wav", "granny", 701, ["啱啱出爐呀，拎穩啲，撻皮一掂就碎㗎。", "你哋去福榮里呀？街坊講嗰棟舊樓有個著黑袍嘅老人家，見人就問大三巴點行。", "成晚都聽到行樓梯嘅腳步聲，點知佢行過嗰陣竟然靜到一啲聲氣都冇……"], make_af(1.06)),
    ("granny_chen_02_v6.wav", "granny", 705, ["要趁熱食呀，凍咗返去焗一焗，個蛋撻皮先至脆㗎。"], make_af(1.06)),
    # Uncle Liang (2 clips - native hk-cantonese-base voice clone)
    ("uncle_liang_01_v6.wav", "liang", 831, ["兩位咁夜仲過嚟飲涼茶呀？福榮里嗰邊啲舊唐樓，呢排唔係幾太平喎。", "上星期有人話三樓半夜仲有燈著住，但係嗰層明明吉咗好耐㗎喇。", "你哋影完相就早啲返去，唔好亂行入後樓梯呀。"], make_af(1.08)),
    ("uncle_liang_02_v6.wav", "liang", 852, ["呢碗廿四味幫你哋下吓火，千祈記住，聽見樓上有人嗌都唔好亂咁應呀。"], make_af(1.08)),
    # Bus Driver (1 clip - native hk-cantonese-base voice clone)
    ("bus_driver_pa_v6.wav", "driver", 911, ["尾班車喇，唔設找錢，自己投六蚊入箱，行入去坐穩扶手。"], make_af(1.08, DRIVER_MIC_AF)),
]


def unload(model) -> None:
    del model
    gc.collect()
    if torch.cuda.is_available():
        torch.cuda.empty_cache()


def norm_to_out(raw_path: Path, out_path: Path, af: str) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
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


def pad_ref(src: Path, dst: Path) -> str:
    dst.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
            "-i", str(src), "-af", "apad=pad_dur=0.45", "-ac", "1", "-ar", "24000", "-c:a", "pcm_s16le", str(dst),
        ],
        check=True,
    )
    return str(dst)


def generate_missing_refs() -> None:
    print("\n=== Generating studio AI refs for Uncle Liang & Bus Driver ===")
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    model = _load_qwen_tts_model(VD_DIR)
    jobs = [
        (
            "ref_uncle_liang_vd.wav",
            811,
            "62歲香港澳門男涼茶舖老細，聲音溫暖帶少少沙啞，用地道香港粵語慢聲細語咁同街坊傾偈，親切自然",
            "兩位咁夜仲過嚟飲涼茶呀？福榮里嗰邊啲舊唐樓，呢排唔係幾太平喎。",
        ),
        (
            "ref_bus_driver_vd.wav",
            911,
            "48歲澳門夜班巴士男司機，沉實略顯疲倦但講嘢爽快，用純熟地道香港澳門粵語對住乘客提醒上車",
            "尾班車喇，唔設找贖，自己投六蚊入箱，行入去坐穩扶手。",
        ),
    ]
    for fname, seed, instruct, text in jobs:
        torch.manual_seed(seed)
        wavs, sr = model.generate_voice_design(text=text, instruct=instruct, language="Chinese", max_new_tokens=1536)
        raw_p = TMP_DIR / f"{fname}.raw.wav"
        sf.write(str(raw_p), wavs[0], sr)
        norm_to_out(raw_p, V2_REFS / fname, "silenceremove=start_periods=1:start_silence=0.03:start_threshold=-48dB,highpass=f=75,loudnorm=I=-16:TP=-1.5:LRA=9")
        raw_p.unlink(missing_ok=True)
        print(f"[ref-vd] {V2_REFS / fname}")
    unload(model)


def run_smoke_base() -> None:
    print("\n=== Smoke testing hk-cantonese-base voice clone (language='Chinese') ===")
    SMOKE_DIR.mkdir(parents=True, exist_ok=True)
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    model = _load_qwen_tts_model(HK_BASE_DIR)
    tests = [
        ("smoke_jiamin.wav", "jiamin", 313, "多謝你呀，新鮮出爐嘅安德魯葡撻仲辣手，快啲趁熱食啦！"),
        ("smoke_dawen.wav", "dawen", 503, "唉，樓梯黑晒添……我先用工具鉗拆開牆邊個電錶箱睇吓先。"),
        ("smoke_ahhao.wav", "ahhao", 603, "姐夫！後面有嘢追緊過嚟呀！快啲走，唔好望返轉頭！"),
        ("smoke_granny.wav", "granny", 701, "啱啱出爐呀，拎穩啲，撻皮一掂就碎㗎。"),
        ("smoke_liang.wav", "liang", 801, "兩位咁夜仲過嚟飲涼茶呀？福榮里嗰邊啲舊唐樓，呢排唔係幾太平喎。"),
    ]
    for fname, spk_id, seed, text in tests:
        src_wav, ref_text = SPEAKER_REFS[spk_id]
        padded = pad_ref(src_wav, TMP_DIR / f"ref_{spk_id}_pad.wav")
        prompt = model.create_voice_clone_prompt(ref_audio=padded, ref_text=ref_text)
        torch.manual_seed(seed)
        wavs, sr = model.generate_voice_clone(
            text=text,
            language="Chinese",
            voice_clone_prompt=prompt,
            max_new_tokens=1536,
        )
        raw_p = TMP_DIR / f"{fname}.raw.wav"
        sf.write(str(raw_p), wavs[0], sr)
        norm_to_out(raw_p, SMOKE_DIR / fname, make_af(1.16))
        raw_p.unlink(missing_ok=True)
        print(f"[smoke] {SMOKE_DIR / fname}")
    unload(model)


def run_stage_a_hk_female(filter_names: set[str] | None = None) -> None:
    print("\n=== Stage A: Generating 100% pure HK Cantonese via hk-cantonese-female (hk_voice_343) ===")
    STAGE_A_DIR.mkdir(parents=True, exist_ok=True)
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    model = _load_qwen_tts_model(HK_FEMALE_DIR)
    for fname, _spk_id, seed, chunks, _af in CHARACTER_CLIPS:
        if filter_names and fname not in filter_names:
            continue
        torch.manual_seed(seed)
        joined = []
        out_sr = 24000
        for idx, txt in enumerate(chunks):
            wavs, sr = model.generate_custom_voice(
                text=txt,
                speaker="hk_voice_343",
                language="Chinese",
                max_new_tokens=1536,
            )
            out_sr = sr
            joined.append(np.asarray(wavs[0], dtype=np.float32))
            if idx < len(chunks) - 1:
                joined.append(np.zeros(int(sr * 0.12), dtype=np.float32))
        merged = np.concatenate(joined) if len(joined) > 1 else joined[0]
        raw_p = TMP_DIR / f"stage_a_{fname}.raw.wav"
        sf.write(str(raw_p), merged, out_sr)
        norm_to_out(raw_p, STAGE_A_DIR / fname, "silenceremove=start_periods=1:start_silence=0.03:start_threshold=-48dB,highpass=f=75,loudnorm=I=-16:TP=-1.5:LRA=9")
        raw_p.unlink(missing_ok=True)
        print(f"[stageA] {STAGE_A_DIR / fname}")
    unload(model)


def generate_bus_pa_clips() -> None:
    print("\n=== Generating 2 AI Bus PA clips + preserving approved human 4-language handrail PA ===")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    TMP_DIR.mkdir(parents=True, exist_ok=True)

    hk_model = _load_qwen_tts_model(HK_FEMALE_DIR)
    torch.manual_seed(951)
    wavs, sr = hk_model.generate_custom_voice(text="下一站，黑沙海灘，請準備落車。", speaker="hk_voice_343", language="Chinese", max_new_tokens=1024)
    raw_norm = TMP_DIR / "bus_normal_raw.wav"
    sf.write(str(raw_norm), wavs[0], sr)
    norm_to_out(raw_norm, OUT_DIR / "bus_normal_pa_v6.wav", make_af(1.04, BUS_PA_EQ))
    raw_norm.unlink(missing_ok=True)
    print("[bus] bus_normal_pa_v6.wav")

    torch.manual_seed(952)
    wavs, sr = hk_model.generate_custom_voice(text="下一站，枉死坡，千祈唔好落車……", speaker="hk_voice_343", language="Chinese", max_new_tokens=1024)
    raw_anom = TMP_DIR / "bus_anom_raw.wav"
    sf.write(str(raw_anom), wavs[0], sr)
    norm_to_out(raw_anom, OUT_DIR / "bus_anomaly_pa_v6.wav", f"silenceremove=start_periods=1:start_silence=0.03:start_threshold=-48dB,{BUS_ANOM_EQ},loudnorm=I=-15:TP=-1.5:LRA=9")
    raw_anom.unlink(missing_ok=True)
    print("[bus] bus_anomaly_pa_v6.wav")
    unload(hk_model)

    orig_4lang = AUD_ROOT / "bus_fx" / "bus_handrail_4lang_pa_orig.wav"
    if orig_4lang.exists():
        norm_to_out(orig_4lang, OUT_DIR / "bus_handrail_4lang_v6.wav", "atempo=1.04,highpass=f=80,loudnorm=I=-16:TP=-1.5:LRA=9")
        print("[bus-keep-human] bus_handrail_4lang_v6.wav")
    else:
        print("[bus] kept existing bus_handrail_4lang_v6.wav")


def run_hk_base_for_speakers(speakers: set[str], filter_names: set[str] | None = None) -> None:
    pending = [it for it in CHARACTER_CLIPS if it[1] in speakers and (not filter_names or it[0] in filter_names)]
    if not pending:
        return
    print(f"\n=== Generating via hk-cantonese-base for speakers={sorted(speakers)} ({len(pending)} clips) ===")
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    model = _load_qwen_tts_model(HK_BASE_DIR)
    prompts = {}
    for spk_id in sorted({it[1] for it in pending}):
        src_wav, ref_text = SPEAKER_REFS[spk_id]
        padded = pad_ref(src_wav, TMP_DIR / f"ref_{spk_id}_pad.wav")
        prompts[spk_id] = model.create_voice_clone_prompt(ref_audio=padded, ref_text=ref_text)
    for fname, spk_id, seed, chunks, af in pending:
        joined = []
        out_sr = 24000
        for idx, txt in enumerate(chunks):
            min_dur = max(2.2, len(txt) * 0.16)
            best_arr = None
            best_sr = 24000
            for attempt in range(5):
                torch.manual_seed(seed + idx * 17 + attempt * 101)
                wavs, sr = model.generate_voice_clone(text=txt, language="Chinese", voice_clone_prompt=prompts[spk_id], max_new_tokens=1536)
                arr = np.asarray(wavs[0], dtype=np.float32)
                if best_arr is None or len(arr) > len(best_arr):
                    best_arr = arr
                    best_sr = sr
                if len(arr) / float(sr) >= min_dur:
                    break
            print(f"  [chunk {idx}] {fname} dur={len(best_arr)/float(best_sr):.2f}s (min={min_dur:.2f}s)")
            out_sr = best_sr
            joined.append(best_arr)
            if idx < len(chunks) - 1:
                joined.append(np.zeros(int(out_sr * 0.12), dtype=np.float32))
        merged = np.concatenate(joined) if len(joined) > 1 else joined[0]
        raw_p = TMP_DIR / f"{fname}.raw.wav"
        sf.write(str(raw_p), merged, out_sr)
        norm_to_out(raw_p, OUT_DIR / fname, af)
        raw_p.unlink(missing_ok=True)
        print(f"[hk-base:{spk_id}] {fname}")
    unload(model)


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
    ap = argparse.ArgumentParser()
    ap.add_argument("--gen-refs", action="store_true")
    ap.add_argument("--smoke-base", action="store_true")
    ap.add_argument("--stage-a", action="store_true")
    ap.add_argument("--gen-bus", action="store_true")
    ap.add_argument("--hk-base-speakers", default="")
    ap.add_argument("--files", nargs="*", default=[])
    ap.add_argument("--audit", action="store_true")
    args = ap.parse_args()
    fset = set(args.files) if args.files else None

    if args.gen_refs:
        generate_missing_refs()
    if args.smoke_base:
        run_smoke_base()
    if args.stage_a:
        run_stage_a_hk_female(fset)
    if args.gen_bus:
        generate_bus_pa_clips()
    if args.hk_base_speakers:
        spks = {s.strip() for s in args.hk_base_speakers.split(",") if s.strip()}
        run_hk_base_for_speakers(spks, fset)
    if args.audit:
        return audit_dir()
    return 0


if __name__ == "__main__":
    sys.exit(main())
