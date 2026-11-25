"""Verify that faction banners keep their anti-aliased alpha background."""

from pathlib import Path

from PIL import Image


def check_banner_alpha(directory: Path) -> list[str]:
    """Return actionable problems for every banner PNG in *directory*."""
    paths = sorted(directory.glob("*.png")) if directory.is_dir() else []
    if not paths:
        return [f"no banner PNGs found in {directory}"]
    problems: list[str] = []
    for path in paths:
        with Image.open(path) as image:
            if image.mode != "RGBA":
                problems.append(f"{path.name}: expected RGBA, got {image.mode}")
                continue
            low, high = image.getchannel("A").getextrema()
            if low == high == 255:
                problems.append(f"{path.name}: background alpha is fully opaque")
    return problems


def main(directory: Path = Path("assets/banners")) -> int:
    problems = check_banner_alpha(directory)
    if problems:
        for problem in problems:
            print(f"FAIL: {problem}")
        return 1
    print("PASS: banner backgrounds use alpha transparency")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
