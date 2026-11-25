"""Verify the high-risk pure core modules are exercised by GUT fuzz tests."""

import re
from pathlib import Path

FUZZ_REQUIRED = ("Damage", "Economy", "MapData", "Production", "Vision")


def missing_fuzz_tests(root: Path = Path(".")) -> list[str]:
    corpus = "\n".join(
        path.read_text(errors="ignore")
        for path in sorted((root / "tests" / "fuzz").glob("*.gd"))
    )
    return [
        f"{name} has no GUT fuzz test reference"
        for name in FUZZ_REQUIRED
        if not re.search(rf"\b{name}\b", corpus)
    ]


def main(root: Path = Path(".")) -> int:
    problems = missing_fuzz_tests(root)
    if problems:
        for problem in problems:
            print(f"FAIL: {problem}")
        return 1
    print("PASS: high-risk core modules are covered by GUT fuzz tests")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
