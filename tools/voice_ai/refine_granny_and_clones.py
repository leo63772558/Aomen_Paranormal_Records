import asyncio
import os
import sys
import subprocess
from pathlib import Path

for _proxy_key in ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy"):
    os.environ.pop(_proxy_key, None)

os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"
os.environ["HF_HUB_DISABLE_SYMLINKS_WARNING"] = "1"
os.environ["HF_HOME"] = r"d:\Aomen_Paranormal_Records\tools\voice_ai\hf_cache"
os.environ["HF_HUB_CACHE"] = r"d:\Aomen_Paranormal_Records\tools\voice_ai\hf_cache"

SEED_VC_DIR = Path(r"d:\Aomen_Paranormal_Records\tools\voice_ai\seed-vc")
sys.path.insert(0, str(SEED_VC_DIR))
os.chdir(SEED_VC_DIR)

import torch
import edge_tts
import inference as seed_inf
from run_vc_batch import ModelArgs, convert_one  # noqa: E402

RAW_ROOT = Path(r"d:\Aomen_Paranormal_Records\docs\overhaul_v6\voice_raw")
AUD_ROOT = Path(r"d:\Aomen_Paranormal_Records\docs\overhaul_v6\voice_audition")
RAW_CLEAN = AUD_ROOT / "raw_clean"
REFS_DIR = AUD_ROOT / "refs"
JIAMIN_OUT = AUD_ROOT / "jiamin_vc"
GRANNY_OUT = AUD_ROOT / "granny_vc"
CLONE_OUT = AUD_ROOT / "cloned_demos"


def run_ff(inp: Path, out: Path, af: str) -> None:
    subprocess.run(
        ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(inp), "-ac", "1", "-ar", "24000", "-af", af, "-c:a", "pcm_s16le", str(out)],
        check=True,
    )


async def synth_elder_cantonese_ref() -> Path:
    # Also test a warm, raspy female ref built by slightly lower-pitch HK female + warm elderly formant filter
    tmp = REFS_DIR / "_tmp"
    mp3 = tmp / "granny_hk_slow.mp3"
    wav = REFS_DIR / "ref_granny_hk_elder_eq.wav"
    txt = "后生仔，新鲜出炉嘅葡挞拿稳呀，挞皮一掂就碎㗎。呢条旧街夜晚行路小心啲，听到有声唔好乱回头，快啲返屋企唞啦。"
    await edge_tts.Communicate(txt, voice="zh-HK-HiuGaaiNeural", rate="-20%", pitch="-22Hz").save(str(mp3))
    run_ff(mp3, wav, "highpass=f=100,lowpass=f=4200,equalizer=f=280:t=q:w=1.1:g=3.0,equalizer=f=1400:t=q:w=1.0:g=1.5,vibrato=f=6.2:d=0.14,loudnorm=I=-16:TP=-1.5")
    return wav


def main() -> None:
    # 1. Re-clean jiamin_01 gently without trimming quiet ending ("趁热食")
    gentle_clean_af = (
        "highpass=f=75,afftdn=nf=-28,"
        "acompressor=threshold=-22dB:ratio=2.5:attack=15:release=180,"
        "loudnorm=I=-18:TP=-1.5:LRA=11,"
        "silenceremove=start_periods=1:start_duration=0.12:start_threshold=-55dB,"
        "areverse,silenceremove=start_periods=1:start_duration=0.12:start_threshold=-55dB,areverse,"
        "apad=pad_dur=0.20"
    )
    run_ff(RAW_ROOT / "黄嘉敏" / "jiamin1.m4a", RAW_CLEAN / "jiamin_01.wav", gentle_clean_af)
    # Also fix zhihao_01 ending / silence safely with -55dB just in case
    run_ff(RAW_ROOT / "黄梓豪" / "zhihao_01.m4a", RAW_CLEAN / "zhihao_01.wav", gentle_clean_af)

    ref_hk_elder = asyncio.run(synth_elder_cantonese_ref())

    # 2. Pre-condition granny.wav upward by +4.5 semitones preserving speed (brings lowered male F0 near female elder chest range ~155-180Hz)
    granny_lifted = REFS_DIR / "_tmp" / "granny_src_lifted.wav"
    run_ff(RAW_CLEAN / "granny.wav", granny_lifted, "rubberband=pitch=1.297:tempo=0.94,highpass=f=95,loudnorm=I=-18:TP=-1.5")

    with torch.no_grad():
        # Base 22k model pass for updated jiamin_01 & cleaner clones
        bundle_base = seed_inf.load_models(ModelArgs(f0_condition=False, fp16=True))
        convert_one(bundle_base, RAW_CLEAN / "jiamin_01.wav", REFS_DIR / "ref_jiamin_hiumaan.wav", JIAMIN_OUT / "jiamin_01_hiumaan.wav", diffusion_steps=45, inference_cfg_rate=0.75)
        convert_one(bundle_base, RAW_CLEAN / "jiamin_01.wav", REFS_DIR / "ref_jiamin_hiugaai.wav", JIAMIN_OUT / "jiamin_01_hiugaai.wav", diffusion_steps=45, inference_cfg_rate=0.75)

        # Better jiamin_clone_01 using calm clear jiamin_02_hiugaai target
        convert_one(bundle_base, CLONE_OUT / "_tts_src" / "jiamin_bunker.wav", JIAMIN_OUT / "jiamin_02_hiugaai.wav", CLONE_OUT / "jiamin_clone_01_bunker.wav", diffusion_steps=48, inference_cfg_rate=0.78)
        convert_one(bundle_base, CLONE_OUT / "_tts_src" / "zhihao_enter.wav", RAW_CLEAN / "zhihao_01.wav", CLONE_OUT / "zhihao_clone_01_enter.wav", diffusion_steps=48, inference_cfg_rate=0.75)

        # Granny C refined (lifted source -> real Judy elderly ref + warm elderly post-EQ)
        convert_one(
            bundle_base, granny_lifted, REFS_DIR / "ref_granny_real_judy_cc0.wav",
            GRANNY_OUT / "granny_C_lifted_judy.wav",
            diffusion_steps=50, inference_cfg_rate=0.82,
            post_af="highpass=f=110,lowpass=f=4400,equalizer=f=320:t=q:w=1.2:g=2.5,equalizer=f=2200:t=q:w=1.2:g=1.5,vibrato=f=5.8:d=0.10,loudnorm=I=-16:TP=-1.5:LRA=9",
        )
        del bundle_base
        torch.cuda.empty_cache()

        # F0-conditioned 44kHz Seed-VC pass for Granny (preserves pitch expression while auto-shifting pitch contour to real elderly female!)
        bundle_f0 = seed_inf.load_models(ModelArgs(f0_condition=True, fp16=True))
        convert_one(
            bundle_f0, RAW_CLEAN / "granny.wav", REFS_DIR / "ref_granny_real_judy_cc0.wav",
            GRANNY_OUT / "granny_D_f0_judy.wav",
            diffusion_steps=45, inference_cfg_rate=0.80,
            f0_condition=True, auto_f0_adjust=True, pitch_shift=0,
            post_af="highpass=f=110,lowpass=f=4500,equalizer=f=300:t=q:w=1.1:g=2.0,atempo=0.95,loudnorm=I=-16:TP=-1.5:LRA=9",
        )
        convert_one(
            bundle_f0, RAW_CLEAN / "granny.wav", ref_hk_elder,
            GRANNY_OUT / "granny_E_f0_hk_elder.wav",
            diffusion_steps=45, inference_cfg_rate=0.80,
            f0_condition=True, auto_f0_adjust=True, pitch_shift=-2,
            post_af="highpass=f=105,lowpass=f=4300,equalizer=f=280:t=q:w=1.1:g=2.5,atempo=0.95,loudnorm=I=-16:TP=-1.5:LRA=9",
        )
        # Also test Jiamin F0-conditioned 44kHz so user can compare crispness!
        convert_one(
            bundle_f0, RAW_CLEAN / "jiamin_01.wav", REFS_DIR / "ref_jiamin_hiugaai.wav",
            JIAMIN_OUT / "jiamin_01_f0_44k.wav",
            diffusion_steps=45, inference_cfg_rate=0.78,
            f0_condition=True, auto_f0_adjust=True, pitch_shift=0,
        )

    print("REFINEMENT_COMPLETE")


if __name__ == "__main__":
    main()
