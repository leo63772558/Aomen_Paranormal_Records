import gc
import os
import subprocess
import sys
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


def save_normalized(wav_np, sr: int, name: str) -> Path:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    raw_p = TMP_DIR / f"{name}.raw.wav"
    out_p = OUT_DIR / f"{name}.wav"
    sf.write(str(raw_p), wav_np, sr)
    subprocess.run(
        [
            "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
            "-i", str(raw_p),
            "-ac", "1", "-ar", "24000",
            "-af", "highpass=f=75,loudnorm=I=-16:TP=-1.5:LRA=9",
            "-c:a", "pcm_s16le",
            str(out_p),
        ],
        check=True,
    )
    raw_p.unlink(missing_ok=True)
    print(f"[qwen3] {out_p.name}")
    return out_p


def unload(model) -> None:
    del model
    gc.collect()
    if torch.cuda.is_available():
        torch.cuda.empty_cache()


def run_pass_hk_female() -> None:
    ckpt = str(MODELS_DIR / "hk-cantonese-female")
    print(f"\n=== PASS 1: Ready-made HK Cantonese Female ({ckpt}) ===")
    model = Qwen3TTSModel.from_pretrained(ckpt, device_map="cuda:0", dtype=torch.bfloat16, attn_implementation="sdpa")
    langs = model.get_supported_languages() if hasattr(model, "get_supported_languages") else None
    spks = model.get_supported_speakers() if hasattr(model, "get_supported_speakers") else None
    print("  supported_languages:", langs)
    print("  supported_speakers:", spks)
    spk = spks[0] if spks else "hk_voice_343"
    lang = "Chinese" if (langs and "chinese" in langs) else "Auto"

    items = [
        ("routeA_jiamin_hk_01_daily", "退后两步啦，将后面个大三巴牌坊都影埋入去嘛！哗，呢张构图唔错喎，陈大师傅今日总算冇手震。奖励你嘅，安德鲁葡挞仲辣手呀，趁热食！"),
        ("routeA_jiamin_hk_02_304", "呢张旧相后面明明仲有道门，点解而家得返幅墙嘅？旧楼入面冇信号，万一走散咗，就按老规矩，敲两下、停一停、再敲一下。"),
        ("routeA_jiamin_hk_03_bunker", "大文、阿豪！千祈唔好由正门落嚟！后面有三道红衣人影堵死咗楼梯口，我将录音机留低喺度，而家经排风竖井走去大关斜巷搵出路！"),
    ]
    for name, text in items:
        wavs, sr = model.generate_custom_voice(text=text, speaker=spk, language=lang, max_new_tokens=1536)
        save_normalized(wavs[0], sr, name)
    unload(model)


def run_pass_voice_design() -> None:
    ckpt = str(MODELS_DIR / "Qwen3-TTS-12Hz-1.7B-VoiceDesign")
    print(f"\n=== PASS 2: VoiceDesign Conversational Cast ({ckpt}) ===")
    model = Qwen3TTSModel.from_pretrained(ckpt, device_map="cuda:0", dtype=torch.bfloat16, attn_implementation="sdpa")
    langs = model.get_supported_languages() if hasattr(model, "get_supported_languages") else None
    print("  supported_languages:", langs)
    lang = "Auto"

    items = [
        (
            "routeA_dawen_vd_01_daily",
            "24岁香港男生，用地道香港粤语（广东话）自然随意同女朋友闲聊吐槽，带轻微叹气同生活化自然停顿，绝对唔好播音腔",
            "唉，嘉敏，你喺度做咩呀？讲好嚟澳门食葡挞同猪扒包，点解又变成钻呢啲黑麻麻嘅旧楼㗎？快啲影完相落楼啦，阵间我请你食水蟹粥。",
        ),
        (
            "routeA_dawen_vd_02_foyer",
            "24岁香港男生，压低声线略带警惕同自然呼吸感，用日常地道香港粤语（广东话）自言自语",
            "唉，楼梯全黑晒添……唔紧要，我先用工具钳拆开墙边个电表箱睇睇先。",
        ),
        (
            "routeA_jiamin_vd_01_daily",
            "23岁香港女生，声音清亮温柔，用自然轻松带笑意嘅地道香港粤语（广东话）同男朋友倾偈，好似真实聊天一样唔好有AI播音腔",
            "退后两步啦，将后面个大三巴牌坊都影埋入去嘛！哗，呢张构图唔错喎，陈大师傅今日总算冇手震。奖励你嘅，安德鲁葡挞仲辣手呀，趁热食！",
        ),
        (
            "routeA_jiamin_vd_02_scared",
            "23岁香港女生，惊恐急促、压低声音带喘气催促快走，用真实地道香港粤语（广东话）",
            "快啲走啦！床后面道铁门自己开咗，走廊出面唔系人嚟㗎！大文，千祈唔好开门，快啲搵地方匿埋！",
        ),
        (
            "routeA_zhihao_vd_01_daily",
            "19岁香港阳光少年男声，语气轻快活泼、自然随意像跟姐夫姐姐去澳门旅行，用地道香港粤语（广东话）",
            "姐夫，我去二楼半后廊合备用闸啦！放心，好快搞掂，阵间楼梯口见！",
        ),
        (
            "routeA_granny_vd_01_warm",
            "72岁澳门慈祥老阿婆，声音苍老略微沙哑、慢悠悠地跟年轻人街边闲聊，讲到鬼故事压低声线，用地道广东话粤语",
            "新鲜出炉，拿稳呀，挞皮一掂就碎㗎。你哋去福荣里呀？街坊讲，嗰栋旧楼有个着黑袍嘅阿伯，楼梯响足成晚，佢行过去竟然一点脚步声都冇……",
        ),
    ]
    for name, instruct, text in items:
        wavs, sr = model.generate_voice_design(text=text, instruct=instruct, language=lang, max_new_tokens=1536)
        save_normalized(wavs[0], sr, name)
    unload(model)


def run_pass_voice_clone() -> None:
    ckpt = str(MODELS_DIR / "Qwen3-TTS-12Hz-1.7B-Base")
    print(f"\n=== PASS 3: Route B Direct LLM Voice Cloning ({ckpt}) ===")
    model = Qwen3TTSModel.from_pretrained(ckpt, device_map="cuda:0", dtype=torch.bfloat16, attn_implementation="sdpa")
    langs = model.get_supported_languages() if hasattr(model, "get_supported_languages") else None
    print("  supported_languages:", langs)

    dawen_daily_ref_text = "嘉敏，你喺度做咩呀？讲好嚟澳门食蛋挞同埋猪扒包㗎啦。点解又变成钻呢啲黑麻麻嘅旧楼啊？快啲影完相落楼啦，阵间我请你食水蟹粥。"
    dawen_tense_ref_text = "嘘，唔好出声。楼梯全部都黑晒，三楼嘅支路都断咗电。阿豪，你去二楼半合备用闸，搞掂即刻落楼梯口会合，千祈唔好乱行。"
    zhihao_ref_text = "姐夫，前面呢就系大三巴啦。嗱，你同我家姐就企埋少少，嗱我就帮你哋两个影返张。我而家呢就要去二楼后门廊嗰度去合嗰个备用闸。你哋放心啦，我好快就返嚟㗎啦，好快就搞掂㗎啦。等阵呢喺楼梯口嗰度见。"

    dawen_daily_prompt = model.create_voice_clone_prompt(ref_audio=str(RAW_CLEAN / "dawen_01_daily.wav"), ref_text=dawen_daily_ref_text)
    dawen_tense_prompt = model.create_voice_clone_prompt(ref_audio=str(RAW_CLEAN / "dawen_02_tense.wav"), ref_text=dawen_tense_ref_text)
    zhihao_prompt = model.create_voice_clone_prompt(ref_audio=str(RAW_CLEAN / "zhihao_01.wav"), ref_text=zhihao_ref_text)

    jobs = [
        ("routeB_dawen_clone_01_foyer", dawen_daily_prompt, "唉，楼梯全黑晒添……唔紧要，我先用工具钳拆开墙边个电表箱睇睇先。"),
        ("routeB_dawen_clone_02_meter", dawen_tense_prompt, "咦，三楼支路断咗电喎。先拆盖检查下测试表同埋值班台啲备件。"),
        ("routeB_dawen_clone_03_stairs", dawen_tense_prompt, "嘉敏仲喺三楼等紧我呀，快啲整返着盏楼梯灯再上去！"),
        ("routeB_zhihao_clone_01_enter", zhihao_prompt, "姐夫，我去二楼半后廊合备用闸啦，好快搞掂，阵间楼梯口见！"),
    ]
    for name, prompt_items, text in jobs:
        wavs, sr = model.generate_voice_clone(text=text, language="Auto", voice_clone_prompt=prompt_items, max_new_tokens=1536)
        save_normalized(wavs[0], sr, name)
    unload(model)


def main() -> None:
    torch.manual_seed(42)
    run_pass_hk_female()
    run_pass_voice_design()
    run_pass_voice_clone()
    print("ALL_QWEN3_GENERATION_DONE")


if __name__ == "__main__":
    main()
