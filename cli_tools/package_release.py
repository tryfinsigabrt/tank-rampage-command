import sys
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile


ARTIFACTS = {
    "web": "tank_rampage_command.zip",
    "win": "tank_rampage_command_win.zip",
}


def build_archive(source_dir: Path, output_path: Path) -> None:
    if output_path.exists():
        output_path.unlink()

    with ZipFile(output_path, "w", compression=ZIP_DEFLATED) as archive:
        for file_path in sorted(path for path in source_dir.rglob("*") if path.is_file()):
            archive.write(file_path, arcname=file_path.relative_to(source_dir))


def package_release(build_dir: Path) -> list[Path]:
    if not build_dir.is_dir():
        raise FileNotFoundError(f"Build directory not found: {build_dir}")

    created_archives = []

    for folder_name, archive_name in ARTIFACTS.items():
        source_dir = build_dir / folder_name
        if not source_dir.is_dir():
            raise FileNotFoundError(f"Source directory not found: {source_dir}")

        output_path = build_dir / archive_name
        print(f"Creating {folder_name} archive...", flush=True)
        build_archive(source_dir, output_path)
        created_archives.append(output_path)
        print(f"Created {output_path}", flush=True)

    return created_archives


def main() -> int:
    build_arg = sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parents[1] / "project" / "build"
    build_dir = Path(build_arg).resolve()

    try:
        package_release(build_dir)
    except OSError as error:
        print(error, file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())