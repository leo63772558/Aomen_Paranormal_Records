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

from huggingface_hub import snapshot_download  # noqa: E402

MODELS_DIR = Path(r"d:\Aomen_Paranormal_Records\tools\voice_ai\qwen3_models")
MODELS_DIR.mkdir(parents=True, exist_ok=True)


def main() -> None:
    targets = [
        ("Qwen/Qwen3-TTS-12Hz-1.7B-Base", MODELS_DIR / "Qwen3-TTS-12Hz-1.7B-Base"),
        ("jmtl/hk-cantonese-cc0-qwen3-tts", MODELS_DIR / "hk-cantonese-lora"),
        ("Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign", MODELS_DIR / "Qwen3-TTS-12Hz-1.7B-VoiceDesign"),
    ]
    for repo_id, local_dir in targets:
        print(f"Downloading {repo_id} -> {local_dir}")
        snapshot_download(
            repo_id=repo_id,
            local_dir=str(local_dir),
            local_dir_use_symlinks=False,
        )
        print(f"OK: {repo_id}")

    # Build merged HK-Cantonese custom_voice female checkpoint
    apply_script = MODELS_DIR / "hk-cantonese-lora" / "scripts" / "apply_adapter.py"
    out_hk_female = MODELS_DIR / "hk-cantonese-female"
    if not (out_hk_female / "model.safetensors").exists():
        print(f"Merging HK-Cantonese LoRA -> {out_hk_female}")
        subprocess.run(
            [
                sys.executable,
                str(apply_script),
                "--base",
                str(MODELS_DIR / "Qwen3-TTS-12Hz-1.7B-Base"),
                "--adapter",
                str(MODELS_DIR / "hk-cantonese-lora"),
                "--out",
                str(out_hk_female),
            ],
            check=True,
        )
    print("ALL_QWEN3_MODELS_READY")


if __name__ == "__main__":
    main()
