#!/usr/bin/env python3
"""
Protobuf Generation Script
Features:
- Downloads Hedera protobufs for a given HAPI version from GitHub.
- Compiles the same proto sets as the original bash script, plus auxiliary dirs:
  * services/*.proto
  * services/auxiliary/tss/*.proto
  * services/auxiliary/hints/*.proto
  * services/auxiliary/history/*.proto
  * platform/event/*.proto
  * mirror/*.proto
- Preserves directory structure in generated Dart gRPC files.
- Cleans output directories safely (deduplicated) before regeneration.
- Logging:
  * INFO for stage summaries and rewrite totals.
  * DEBUG for useful counts.
  * TRACE (custom) for verbose details such as per-file rewrites and protoc args.
Run: python generate_proto.py
"""
import logging
import subprocess
import shutil
import tarfile
from urllib.parse import urlparse
import urllib.request
import re
from dataclasses import dataclass, field
from pathlib import Path

VERSION="v0.72.0-rc.2"
SOURCES = [
    {
        "name": "hedera-protobufs",
        "url": "https://github.com/hashgraph/hedera-protobufs",
        "version": VERSION,
        "strip_count": 1,
        "modules": ("mirror",)
    },
    {
        "name": "hiero-consensus-node",
        "url": "https://github.com/hiero-ledger/hiero-consensus-node",
        "version": VERSION,
        "strip_count": 6,   
        "modules": ("services", "platform", "fee", "sdk", "block", "streams", "blocks")
    }
]

OUTPUT_DIR="lib/src/hapi"
CACHE_DIR=".protos"

# Map common broken imports in mirror/platform proto
REPLACEMENTS = {
    'import "basic_types.proto";': 'import "services/basic_types.proto";',
    'import "timestamp.proto";': 'import "services/timestamp.proto";',
    'import "consensus_submit_message.proto";': 'import "services/consensus_submit_message.proto";',
    'import "response_code.proto";': 'import "services/response_code.proto";',
    'import "query.proto";': 'import "services/query.proto";',
    'import "transaction.proto";': 'import "services/transaction.proto";',
    'import "transaction_response.proto";': 'import "services/transaction_response.proto";',
    # platform/event specific err
    'import "event/state_signature_transaction.proto";': 'import "platform/event/state_signature_transaction.proto";',
}


@dataclass
class Config:
    name: str
    url: str
    version: str
    strip_count: int 
    modules: tuple = field(default_factory=tuple)


def setup_logging(verbosity: int) -> None:
    level = logging.WARNING
    if verbosity == 1: level = logging.INFO
    elif verbosity == 2: level = logging.DEBUG
    elif verbosity >= 3: level = logging.TRACE_LEVEL
    
    logging.basicConfig(level=level, format="%(levelname)s: %(message)s")


def download_protos(config: Config, cache_path: Path) -> None:
    logging.info(f"Downloading {config.name} {config.version}...")
    url = f"{config.url}/archive/refs/tags/{config.version}.tar.gz"

    parsed = urlparse(url)
    if parsed.scheme != "https" or parsed.netloc != "github.com":
        raise RuntimeError(f"Refusing to download from non-https or unexpected host: {url}")

    try:
        # URL scheme and host validated above
        with urllib.request.urlopen(url, timeout=30) as resp: # nosec B310
            safe_extract_tar_stream(resp, config, cache_path)
    except Exception as e:
        raise RuntimeError(f"Download failed for {config.name}: {e}")
    

def is_safe_tar_member(member: tarfile.TarInfo, base: Path) -> bool:
    name = member.name
    if not name or name.startswith("/"):
        return False
    # Prevent traversal like ../../etc/passwd
    if ".." in Path(name).parts:
        return False
    dest = (base / name).resolve()
    try:
        dest.relative_to(base.resolve())
    except ValueError:
        return False
    
    return (member.isdir() or member.isreg())


def safe_extract_tar_stream(resp, config: Config, cache_path: Path):
    with tarfile.open(fileobj=resp, mode="r|gz") as tar:
        for member in tar:
            parts = Path(member.name).parts

            if len(parts) <= config.strip_count: continue
            member.name = "/".join(parts[config.strip_count:])
            
            if not any(member.name.startswith(p) for p in config.modules):
                continue

            if not is_safe_tar_member(member, cache_path):
                continue

            if member.isdir():
                (cache_path / member.name).mkdir(parents=True, exist_ok=True)
                continue
            
            target = cache_path / member.name
            target.parent.mkdir(parents=True, exist_ok=True)
            with tar.extractfile(member) as src, target.open("wb") as dst:
                shutil.copyfileobj(src, dst)



def patch_proto_imports(proto_root: Path):
    logging.info("Patching proto files for consistent import paths...")

    for proto_file in proto_root.rglob("*.proto"):
        content = proto_file.read_text(encoding="utf-8")
        new_content = content
        
        for broken, fixed in REPLACEMENTS.items():
            new_content = new_content.replace(broken, fixed)
        
        if "platform" in proto_file.parts:
            new_content = re.sub(r'import "event/', 'import "platform/event/', new_content)

        if new_content != content:
            proto_file.write_text(new_content, encoding="utf-8")


def run_protoc(proto_root: Path, output_root: Path) -> None:
    all_protos = [p.as_posix() for p in proto_root.rglob("*.proto")]
    if not all_protos:
        raise RuntimeError("No .proto files found to compile")

    cmd = [
        "protoc",
        f"-I{proto_root.as_posix()}",
        f"--dart_out=grpc:{output_root.as_posix()}",
        *all_protos,
    ]

    result = shutil.which("protoc")
    if result is None:
        raise RuntimeError("protoc is required but was not found in PATH")

    dart_plugin = shutil.which("protoc-gen-dart")
    if dart_plugin is None:
        raise RuntimeError(
            "protoc-gen-dart is required but was not found in PATH. "
            "Install it with: dart pub global activate protoc_plugin"
        )

    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(
            "protoc failed to generate Dart proto files\n"
            f"stdout:\n{proc.stdout}\n"
            f"stderr:\n{proc.stderr}"
        )


def main():
    setup_logging(1)
    cache_path = Path(CACHE_DIR)
    out_path = Path(OUTPUT_DIR)

    if cache_path.exists(): shutil.rmtree(cache_path)
    if out_path.exists(): shutil.rmtree(out_path)

    cache_path.mkdir(parents=True)
    out_path.mkdir(parents=True)

    for src_data in SOURCES:
        src = Config(**src_data)
        download_protos(src, cache_path)

    patch_proto_imports(cache_path)
    
    logging.info("Running protoc...")
    run_protoc(cache_path, out_path)

    print(f"Successfully merged and generated Dart HAPI at {out_path}")


if __name__ == "__main__":
    main()