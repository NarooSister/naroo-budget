"""Summarize Flutter LCOV without removing files or changing its denominator."""

import argparse
from pathlib import Path


def read_lcov(path):
    records = {}
    current = None
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("SF:"):
            name = line[3:].replace("\\", "/")
            if "/lib/" in name:
                name = "lib/" + name.split("/lib/", 1)[1]
            current = records.setdefault(name, {"lines": {}, "branches": {}})
        elif current is not None and line.startswith("DA:"):
            number, hits, *_ = line[3:].split(",")
            current["lines"][number] = current["lines"].get(number, 0) + int(hits)
        elif current is not None and line.startswith("BRDA:"):
            number, block, branch, hits = line[5:].split(",")
            key = (number, block, branch)
            current["branches"][key] = current["branches"].get(key, 0) + (0 if hits == "-" else int(hits))
        elif line == "end_of_record":
            current = None
    return records


def counts(records, kind):
    hits = [hit for record in records for hit in record[kind].values()]
    return sum(hit > 0 for hit in hits), len(hits)


def percent(count):
    hit, total = count
    return 100 * hit / total if total else 0.0


def critical(name):
    return (name.startswith(("lib/core/", "lib/data/"))
            or name.endswith(("_controller.dart", "/home_summary.dart")))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lcov", nargs="?", default="coverage/lcov.info")
    parser.add_argument("--check", action="store_true", help="Fail if any coverage target is unmet")
    parser.add_argument("--min-line", type=float, default=90)
    parser.add_argument("--min-branch", type=float, default=85)
    parser.add_argument("--min-core", type=float, default=95)
    args = parser.parse_args()
    records = read_lcov(Path(args.lcov))
    if not records:
        parser.error("LCOV has no source records")
    lines = counts(records.values(), "lines")
    branches = counts(records.values(), "branches")
    core = counts((record for name, record in records.items() if critical(name)), "lines")
    for title, count in [("All lines", lines), ("All VM branches", branches), ("Core/state/data lines", core)]:
        print(f"{title}: {count[0]}/{count[1]} ({percent(count):.2f}%)")
    print("\nFiles below 100% lines (uncovered line numbers):")
    for name, record in sorted(records.items()):
        missing = [number for number, hit in record["lines"].items() if not hit]
        if missing:
            count = counts([record], "lines")
            print(f"  {name}: {percent(count):.2f}% [{', '.join(missing)}]")
    root = Path(__file__).resolve().parents[1]
    absent = sorted(path.relative_to(root).as_posix() for path in (root / "lib").rglob("*.dart")
                    if path.relative_to(root).as_posix() not in records)
    print("\nSource files absent from LCOV (not counted in the percentages):")
    for name in absent:
        print(f"  {name}")
    if not absent:
        print("  none")
    if args.check:
        passed = (percent(lines) >= args.min_line and percent(branches) >= args.min_branch
                  and percent(core) >= args.min_core)
        print("\nCoverage targets: " + ("PASS" if passed else "FAIL"))
        return 0 if passed else 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
