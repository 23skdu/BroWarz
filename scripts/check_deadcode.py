"""Find duplicate class names and unreferenced GDScript files in the project."""

import re
from pathlib import Path

SKIP_DIRS = {".git", ".godot", "addons", "build", "venv"}
TEXT_SUFFIXES = {".gd", ".godot", ".md", ".sh", ".tscn", ".yml"}
# Standalone generators and the GUT orphan guard are invoked by path, not class.
SELF_DOCUMENTED = ("scripts/tools/", "scripts/testing/")


def _text_files(root: Path) -> dict[Path, str]:
    files: dict[Path, str] = {}
    for path in root.rglob("*"):
        relative = path.relative_to(root)
        if not path.is_file() or set(relative.parts) & SKIP_DIRS:
            continue
        if path.suffix not in TEXT_SUFFIXES and path.name != "Makefile":
            continue
        files[path] = path.read_text(errors="ignore")
    return files


def _class_name(text: str) -> str:
    match = re.search(r"^class_name\s+(\w+)", text, re.M)
    return match.group(1) if match else ""


def scan(root: Path = Path(".")) -> list[str]:
    files = _text_files(root)
    scripts = sorted(
        path for path in files
        if path.suffix == ".gd" and "scripts" in relative_parts(path, root)
    )
    if not scripts:
        return ["no GDScript files found under scripts/"]
    problems: list[str] = []
    seen: dict[str, str] = {}
    for path in scripts:
        name = _class_name(files[path])
        if not name:
            continue
        if name in seen:
            problems.append(f"duplicate class_name {name}: {seen[name]} and {path}")
        seen[name] = str(path)
    for path in scripts:
        relative = path.relative_to(root).as_posix()
        if relative.startswith(SELF_DOCUMENTED):
            continue
        names = {path.stem}
        class_name = _class_name(files[path])
        if class_name:
            names.add(class_name)
        corpus = "\n".join(text for other, text in files.items() if other != path)
        if not any(
            re.search(rf"\b{re.escape(name)}\b", corpus) for name in names
        ):
            problems.append(f"{relative} is not referenced outside its own file")
    return problems


def relative_parts(path: Path, root: Path) -> tuple[str, ...]:
    return path.relative_to(root).parts


def main(root: Path = Path(".")) -> int:
    problems = scan(root)
    if problems:
        for problem in problems:
            print(f"FAIL: {problem}")
        return 1
    print("PASS: no duplicate class names or unreferenced scripts")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
