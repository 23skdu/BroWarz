"""Verify every core GDScript module is referenced by a GUT unit test."""

import re
from pathlib import Path


def _names(path: Path) -> set[str]:
    """Return the module/class names a test can reference for *path*."""
    names = {path.stem}
    match = re.search(r"^class_name\s+(\w+)", path.read_text(errors="ignore"), re.M)
    if match:
        names.add(match.group(1))
    return names


def missing_unit_tests(root: Path = Path(".")) -> list[str]:
    scripts = sorted((root / "scripts" / "core").glob("*.gd"))
    if not scripts:
        return ["no core scripts found under scripts/core/"]
    corpus = "\n".join(
        path.read_text(errors="ignore")
        for path in sorted((root / "tests" / "unit").glob("*.gd"))
    )
    missing: list[str] = []
    for path in scripts:
        if not any(
            re.search(rf"\b{re.escape(name)}\b", corpus) for name in _names(path)
        ):
            missing.append(f"{path.as_posix()} has no GUT unit test reference")
    return missing


def main(root: Path = Path(".")) -> int:
    problems = missing_unit_tests(root)
    if problems:
        for problem in problems:
            print(f"FAIL: {problem}")
        return 1
    print("PASS: every core script is referenced by a GUT unit test")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
