"""
Convert Stage-A 100%-pure HK Cantonese carrier speech (hk_voice_343)
onto the six fixed V2 character voices via local Seed-VC, guaranteeing:
  1. Zero Mandarin pronunciation or drift on any character or line.
  2. Consistent vocal identity & pitch per character across the entire game.
  3. Zero human team recordings (except approved 4-language bus handrail PA).
"""
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

ROOT = Path(r"d:\Aomen_Paranormal_Records")
sys.path.insert(0, str(ROOT / "tools" / "voice_ai"))
import run_vc_batch as vc  # noqa: E402
import generate_v6_pure_cantonese as gen  # noqa: E402
import torch  # noqa: E402

STAGE_A_DIR = gen.STAGE_A_DIR
OUT_DIR = gen.OUT_DIR


def apply_fx_copy(src: Path, dst: Path, af: str) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(src), "-ac", "1", "-ar", "24000", "-af", af, "-c:a", "pcm_s16le", str(dst)],
        check=True,
    )
    print(f"[stageA->jiamin] {dst.name}")


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # Jiamin uses pure hk_voice_343 directly (zero conversion needed, crisp & consistent)
    for fname, spk_id, _seed, _chunks, af in gen.CHARACTER_CLIPS:
        if spk_id != "jiamin":
            continue
        src = STAGE_A_DIR / fname
        if not src.exists():
            raise FileNotFoundError(f"Missing Stage-A wav: {src}")
        apply_fx_copy(src, OUT_DIR / fname, af)

    # All other 5 roles use Seed-VC from pure HK Stage-A carrier -> fixed V2 character reference
    print("Loading Seed-VC bundle on CUDA...")
    vc.AUD_ROOT = ROOT
    with torch.no_grad():
        bundle = vc.seed_inf.load_models(vc.ModelArgs(f0_condition=False, fp16=True))
        for fname, spk_id, _seed, _chunks, af in gen.CHARACTER_CLIPS:
            if spk_id == "jiamin":
                continue
            src = STAGE_A_DIR / fname
            if not src.exists():
                raise FileNotFoundError(f"Missing Stage-A wav: {src}")
            ref_wav, _ref_txt = gen.SPEAKER_REFS[spk_id]
            vc.convert_one(
                bundle,
                src,
                ref_wav,
                OUT_DIR / fname,
                diffusion_steps=44,
                inference_cfg_rate=0.75,
                f0_condition=False,
                post_af=af,
            )
    return gen.audit_dir()


if __name__ == "__main__":
    sys.exit(main())
