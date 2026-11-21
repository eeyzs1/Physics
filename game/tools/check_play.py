"""Play through the harbor investigations and the three-island voyage in isolated profiles."""

import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile

from export_windows import PROJECT, editor_from_path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=editor_from_path(), help="Godot 4 editor executable")
    parser.add_argument("--pack", type=Path, help="Check this released Windseed.pck in isolation")
    groups = ["loading", "quay", "harbor", "voyage"]
    parser.add_argument("--only", choices=groups, help="Run a single group of checks")
    args = parser.parse_args()
    if not args.godot:
        parser.error("Pass --godot with the editor executable.")
    if args.pack and not args.pack.is_file():
        parser.error("The specified game data pack does not exist.")
    source = ["--main-pack", str(args.pack.resolve())] if args.pack else ["--path", str(PROJECT)]
    for group in [args.only] if args.only else groups:
        with tempfile.TemporaryDirectory(prefix="windseed-play-") as scratch:
            data_dir = Path(scratch) / "userdata"
            data_dir.mkdir()
            env = dict(os.environ, WINDSEED_TEST_ROOT=scratch, APPDATA=str(data_dir), XDG_DATA_HOME=str(data_dir))
            cmd = [args.godot, "--headless", "--fixed-fps", "60", "--audio-driver", "Dummy",
                   *source, "--script", str(PROJECT / "tools" / f"check_{group}.gd")]
            result = subprocess.run(cmd, env=env, cwd=scratch, capture_output=True,
                                    encoding="utf-8", errors="replace", timeout=75)
            log = result.stdout + result.stderr
            print(log, end="")
            if result.returncode or f"{group.title()} checks passed" not in log or "ERROR:" in log:
                return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
