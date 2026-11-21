"""Export the Windows playtest with an installed Godot 4 editor."""

import argparse
import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile


PROJECT = Path(__file__).resolve().parents[1]


def editor_from_path():
    for name in ("godot4", "godot"):
        found = shutil.which(name)
        if found:
            return found
    if os.name == "nt":
        for directory in os.get_exec_path():
            matches = sorted(Path(directory).glob("Godot*_console.exe"), reverse=True)
            if matches:
                return str(matches[0])
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=editor_from_path(), help="Godot 4 executable")
    parser.add_argument("--template", type=Path, help="Matching Windows x86_64 release template")
    parser.add_argument("--output", type=Path, default=PROJECT / "build" / "windows")
    parser.add_argument("--archive", type=Path, help="Also create a ZIP with the two Windows runtime files")
    args = parser.parse_args()
    if not args.godot:
        parser.error("Pass the editor executable with --godot.")
    if args.template and not args.template.is_file():
        parser.error("The specified Windows export template does not exist.")

    # Isolate the importer and any machine-specific template override from the editable project.
    with tempfile.TemporaryDirectory(prefix="windseed-export-") as temporary:
        staging = Path(temporary) / "game"
        shutil.copytree(PROJECT, staging, ignore=shutil.ignore_patterns(
            ".godot", "build", "source", "tools", "__pycache__", "*.py", "*.blend1"
        ))
        if args.template:
            preset = staging / "export_presets.cfg"
            text = preset.read_text(encoding="utf-8")
            custom = args.template.resolve().as_posix()
            text = text.replace('custom_template/release=""', f'custom_template/release="{custom}"')
            preset.write_text(text, encoding="utf-8")
        executable = Path(temporary) / "Windseed.exe"
        command = [args.godot, "--headless", "--audio-driver", "Dummy", "--path", str(staging)]
        subprocess.run(command + ["--editor", "--import"], check=True)
        subprocess.run(command + ["--export-release", "Windows Desktop", str(executable)], check=True)
        files = [executable, executable.with_suffix(".pck")]
        if not all(path.is_file() and path.stat().st_size > 1000 for path in files):
            raise RuntimeError("The executable or its game data pack was not produced.")
        args.output.mkdir(parents=True, exist_ok=True)
        for path in files:
            pending = args.output / (path.name + ".new")
            shutil.copy2(path, pending)
            pending.replace(args.output / path.name)
        if args.archive:
            args.archive.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.TemporaryDirectory(dir=args.archive.parent) as archive_dir:
                pending_archive = Path(archive_dir) / args.archive.name
                with ZipFile(pending_archive, "w", ZIP_DEFLATED, compresslevel=6) as archive:
                    for path in files:
                        archive.write(path, path.name)
                pending_archive.replace(args.archive)
        print(args.output.resolve() / executable.name)


if __name__ == "__main__":
    main()
