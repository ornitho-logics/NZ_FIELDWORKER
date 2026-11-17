#!/usr/bin/env python3
"""Stamp a release's actual app bytes; never starts Shiny or accesses a database."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "main"
EXTENSIONS = {".R", ".js", ".css", ".html", ".md", ".webmanifest", ".png", ".svg", ".ico", ".qmd"}


def git_value(root, *args):
    result = subprocess.run(["git", "-C", str(root), *args], text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return result.stdout.strip() if result.returncode == 0 else None


def release_identity(root=ROOT):
    app = root / "main"
    revision = git_value(root, "rev-parse", "HEAD")
    status = git_value(root, "status", "--porcelain", "--untracked-files=all", "--", "main")
    files = []
    for path in sorted(app.rglob("*")):
        relative = path.relative_to(app)
        if any(part.startswith(".") for part in relative.parts) or path.suffix not in EXTENSIONS:
            continue
        if path.is_symlink():
            raise ValueError("Release sources must not be symlinks: " + str(relative))
        if path.is_file():
            files.append((relative.as_posix(), hashlib.sha256(path.read_bytes()).hexdigest()))
    if not files:
        raise ValueError("No app sources found")
    payload = json.dumps({"revision": revision, "files": files}, separators=(",", ":"))
    return {"id": hashlib.sha256(payload.encode()).hexdigest(),
            "revision": revision, "dirty": bool(status)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify an existing stamp; write nothing")
    parser.add_argument("--allow-dirty", action="store_true", help="Prepare a modified development checkout")
    args = parser.parse_args()
    output = APP / "www/build.json"
    try:
        build = release_identity()
        if args.check:
            stamped = json.loads(output.read_text())
            if any(stamped.get(key) != value for key, value in build.items()):
                raise ValueError("Build stamp does not match this checkout; prepare it again")
            print("Build stamp matches app sources: " + build["id"][:12])
            return
        if build["dirty"] and not args.allow_dirty:
            raise ValueError("App sources have uncommitted changes; use --allow-dirty only for development")
        build["built_at"] = datetime.now(timezone.utc).isoformat()
        output.parent.mkdir(parents=True, exist_ok=True)
        # Only the public content fingerprint, source revision, and build time are emitted.
        temporary = output.with_suffix(".json.tmp")
        try:
            temporary.write_text(json.dumps(build, indent=2) + "\n")
            temporary.replace(output)
        finally:
            temporary.unlink(missing_ok=True)
        print("Prepared Fieldworker build " + build["id"][:12])
    except (OSError, ValueError) as error:
        parser.exit(1, str(error) + "\n")


if __name__ == "__main__":
    main()
