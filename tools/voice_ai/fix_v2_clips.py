import gc
import os
import subprocess
from pathlib import Path

for _proxy_key in ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy"):
    os.environ.pop(_proxy_key, None)

os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"
os.environ["HF_HUB_DISABLE_SYMLINKS_WARNING"] = "1"
os.environ["HF_HOME"] = r"d:\Aomen_Paranormal_Records\tools\voice_ai\hf_cache"
os.environ["HF_HUB_CACHE"] = r"d:\Aomen_Paranormal_Records\tools\voice_ai\hf_cache"

import soundfile as sf  # noqa: E402
import torch  # noqa: E402
from qwen_tts import Qwen3TTSModel  # noqa: E402

MODELS_DIR = Path(r"d:\Aomen_Paranormal_Records\tools\voice_ai\qwen3_models")
AUD_ROOT = Path(r"d:\Aomen_Paranormal_Records\docs\overhaul_v6\voice_audition")
RAW_CLEAN = AUD_ROOT / "raw_clean"
OUT_DIR = AUD_ROOT / "qwen3_v2"
TMP_DIR = OUT_DIR / "_tmp"


def save_norm(wav_np, sr: int, name: str) -> Path:
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    raw_p = TMP_DIR / f"{name}.raw.wav"
    out_p = OUT_DIR / f"{name}.wav"
    sf.write(str(raw_p), wav_np, sr)
    subprocess.run(
        [
            "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
            "-i", str(raw_p), "-ac", "1", "-ar", "24000",
            "-af", "highpass=f=75,loudnorm=I=-16:TP=-1.5:LRA=9",
            "-c:a", "pcm_s16le", str(out_p),
        ],
        check=True,
    )
    raw_p.unlink(missing_ok=True)
    print(f"[fix_v2] {out_p.name}")
    return out_p


def pad_ref(src: Path, dst: Path) -> str:
    # Add 0.45s clean trailing silence so the last word of ref_audio never bleeds into frame 0 of generated output
    subprocess.run(
        [
            "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
            "-i", str(src), "-af", "apad=pad_dur=0.45", "-ac", "1", "-ar", "24000", "-c:a", "pcm_s16le", str(dst),
        ],
        check=True,
    )
    return str(dst)


def unload(m) -> None:
    del m
    gc.collect()
    torch.cuda.empty_cache()


def main() -> None:
    torch.manual_seed(108)
    TMP_DIR.mkdir(parents=True, exist_ok=True)

    # 1. Inspect second speaker hk_voice_777 & regenerate complete jiamin_hk_01_daily
    m_hk = Qwen3TTSModel.from_pretrained(str(MODELS_DIR / "hk-cantonese-female"), device_map="cuda:0", dtype=torch.bfloat16, attn_implementation="sdpa")
    wavs, sr = m_hk.generate_custom_voice(
        text="退后两步啦，将后面个大三巴牌坊都影埋入去嘛！哗，呢张构图唔错喎，陈大师傅今日总算冇手震，奖励你嘅安德鲁葡挞仲辣手呀，趁热食！",
        speaker="hk_voice_343", language="Chinese", max_new_tokens=2048,
    )
    save_norm(wavs[0], sr, "routeA_jiamin_hk_01_daily")
    wavs777, sr777 = m_hk.generate_custom_voice(
        text="讲真呀，呢栋旧楼咁黑麻麻，点解唔等天光先嚟影相呢？行啦，阵间去食葡挞。",
        speaker="hk_voice_777", language="Chinese", max_new_tokens=1536,
    )
    save_norm(wavs777[0], sr777, "routeA_hk777_sample")
    unload(m_hk)

    # 2. Fix VoiceDesign Zhihao (pure Cantonese, no Mandarin slip) & Granny (unmistakably female grandmother, NOT male)
    m_vd = Qwen3TTSModel.from_pretrained(str(MODELS_DIR / "Qwen3-TTS-12Hz-1.7B-VoiceDesign"), device_map="cuda:0", dtype=torch.bfloat16, attn_implementation="sdpa")
    w_zh, sr_zh = m_vd.generate_voice_design(
        text="喂，姐夫！我而家上去二楼半后廊嗰度合埋个备用闸先啦，好快搞掂㗎咋，阵间楼梯口见喎！",
        instruct="19-year-old Hong Kong young man speaking lively native Hong Kong Cantonese casually to his brother-in-law, bright energetic teen male tone, conversational breathing and natural pauses, strictly Cantonese not Mandarin",
        language="Auto", max_new_tokens=1536,
    )
    save_norm(w_zh[0], sr_zh, "routeA_zhihao_vd_01_daily")

    w_gr1, sr_gr1 = m_vd.generate_voice_design(
        text="新鲜出炉拿稳呀，挞皮一掂就碎㗎。你哋去福荣里呀？街坊讲，嗰栋旧楼有个着黑袍嘅老人家，楼梯响足成晚，佢行过去竟然一点脚步声都冇……",
        instruct="Elderly 72-year-old Cantonese grandmother, distinctly female aged woman voice, gentle warm female grandma pitch with soft elderly rasp and slow relaxed pacing, speaking Hong Kong Cantonese kindly, NOT a male voice",
        language="Auto", max_new_tokens=2048,
    )
    save_norm(w_gr1[0], sr_gr1, "routeA_granny_vd_01_warm")

    w_gr2, sr_gr2 = m_vd.generate_voice_design(
        text="新鲜出炉呀，拿稳啲，挞皮一掂就碎㗎。唔好咁夜仲入去福荣里啲旧楼啦，小心呀。",
        instruct="75岁香港慈祥老婆婆，一听就系女人阿婆声线，略带高龄女声微微沙哑同温和笑意，慢悠悠地道广东话粤语，绝对系女声",
        language="Auto", max_new_tokens=1536,
    )
    save_norm(w_gr2[0], sr_gr2, "routeA_granny_vd_02_female")
    unload(m_vd)

    # 3. Fix Route B prefix word bleed by padding 0.45s silence onto ref wavs before creating clone prompts
    m_base = Qwen3TTSModel.from_pretrained(str(MODELS_DIR / "Qwen3-TTS-12Hz-1.7B-Base"), device_map="cuda:0", dtype=torch.bfloat16, attn_implementation="sdpa")
    p_d1 = pad_ref(RAW_CLEAN / "dawen_01_daily.wav", TMP_DIR / "dawen_01_pad.wav")
    p_d2 = pad_ref(RAW_CLEAN / "dawen_02_tense.wav", TMP_DIR / "dawen_02_pad.wav")
    p_zh = pad_ref(RAW_CLEAN / "zhihao_01.wav", TMP_DIR / "zhihao_01_pad.wav")

    dawen1_txt = "嘉敏，你喺度做咩呀？讲好嚟澳门食蛋挞同埋猪扒包㗎啦。点解又变成钻呢啲黑麻麻嘅旧楼啊？快啲影完相落楼啦，阵间我请你食水蟹粥。"
    dawen2_txt = "嘘，唔好出声。楼梯全部都黑晒，三楼嘅支路都断咗电。阿豪，你去二楼半合备用闸，搞掂即刻落楼梯口会合，千祈唔好乱行。"
    zhihao_txt = "姐夫，前面呢就系大三巴啦。嗱，你同我家姐就企埋少少，嗱我就帮你哋两个影返张。我而家呢就要去二楼后门廊嗰度去合嗰个备用闸。你哋放心啦，我好快就返嚟㗎啦，好快就搞掂㗎啦。等阵呢喺楼梯口嗰度见。"

    pr_d1 = m_base.create_voice_clone_prompt(ref_audio=p_d1, ref_text=dawen1_txt)
    pr_d2 = m_base.create_voice_clone_prompt(ref_audio=p_d2, ref_text=dawen2_txt)
    pr_zh = m_base.create_voice_clone_prompt(ref_audio=p_zh, ref_text=zhihao_txt)

    clone_jobs = [
        ("routeB_dawen_clone_01_foyer", pr_d1, "唉，楼梯全黑晒添……唔紧要，我先用工具钳拆开墙边个电表箱睇睇先。"),
        ("routeB_dawen_clone_02_meter", pr_d2, "咦，三楼支路断咗电喎。先拆盖检查下测试表同埋值班台啲备件。"),
        ("routeB_dawen_clone_03_stairs", pr_d2, "嘉敏仲喺三楼等紧我呀，快啲整返着盏楼梯灯再上去！"),
        ("routeB_zhihao_clone_01_enter", pr_zh, "姐夫，我去二楼半后廊合备用闸啦，好快搞掂，阵间楼梯口见！"),
    ]
    for name, pr, txt in clone_jobs:
        wavs_c, sr_c = m_base.generate_voice_clone(text=txt, language="Auto", voice_clone_prompt=pr, max_new_tokens=1536)
        save_norm(wavs_c[0], sr_c, name)
    unload(m_base)
    print("FIX_V2_DONE")


if __name__ == "__main__":
    main()
