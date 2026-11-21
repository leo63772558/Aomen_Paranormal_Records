"""Back up recoverable project source and assets, excluding caches and old builds."""
import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
EXCLUDED_FOLDERS = {".godot", ".git", "__pycache__", "export_templates"}
EXCLUDED_TOOLS = {"engine", "recovery", "audio_sources"}

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--label", default="progress")
    args = parser.parse_args()
    if not args.label.replace("_", "").replace("-", "").isalnum():
        raise SystemExit("Unsafe snapshot label")
    outdir = ROOT / "tools" / "recovery"
    outdir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    archive = outdir / f"{args.label}_{stamp}.zip"
    manifest = []
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=3) as bundle:
        for directory, names, files in os.walk(ROOT):
            relative_dir = Path(directory).relative_to(ROOT)
            names[:] = [name for name in names if name not in EXCLUDED_FOLDERS
                        and not (relative_dir == Path(".") and name.startswith("澳诡实录_"))
                        and not (relative_dir == Path("tools") and name in EXCLUDED_TOOLS)
                        and not (relative_dir == Path("docs") and name in ("build_reports", "review_sources", "user_references"))]
            for name in sorted(files):
                path = Path(directory) / name
                relative = path.relative_to(ROOT)
                if path.suffix.lower() in (".zip", ".pck", ".exe", ".tmp"):
                    continue
                bundle.write(path, relative.as_posix())
                manifest.append({"path": relative.as_posix(), "bytes": path.stat().st_size})
        bundle.writestr("SNAPSHOT_MANIFEST.json", json.dumps(manifest, ensure_ascii=False, indent=2))
    with zipfile.ZipFile(archive) as bundle:
        bad = bundle.testzip()
        if bad is not None:
            raise RuntimeError(f"Snapshot failed CRC verification: {bad}")
    with archive.open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    report = {
        "archive": str(archive), "files": len(manifest), "bytes": archive.stat().st_size,
        "sha256": digest, "zip_test": "passed", "created_local": datetime.now().isoformat(),
        "excludes": ["engine/export templates", "generated caches", "previous builds/archives",
                     "test saves/recovery", "reproducible build reports", "research references"],
        "restore": "Extract into the existing project; engine binaries remain in tools/engine. Player saves are outside this snapshot."
    }
    archive.with_suffix(".verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
