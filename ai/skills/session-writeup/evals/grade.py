#!/usr/bin/env python3
"""
Grade a session-writeup output against the assertions in evals.json.

Usage:
    python3 grade.py <eval_id_or_name> <path/to/writeup.md>

Reads banned_meta_phrases and structural_requirements (shared across all
evals) plus the per-eval facts_to_recover list from evals.json, and prints
a pass/fail breakdown plus an overall pass rate. Also writes grading.json
next to the output file so it can be picked up by the skill-creator
eval-viewer/aggregate_benchmark tooling if you're re-running the full loop.
"""
import json
import re
import sys
from pathlib import Path


def load_evals():
    evals_path = Path(__file__).parent / "evals.json"
    return json.loads(evals_path.read_text())


def find_eval(evals_data, eval_id_or_name):
    for e in evals_data["evals"]:
        if str(e["id"]) == str(eval_id_or_name) or e.get("eval_name") == eval_id_or_name:
            return e
    raise SystemExit(f"No eval found matching '{eval_id_or_name}'")


def grade(evals_data, eval_def, output_path: Path):
    text = output_path.read_text(encoding="utf-8")
    lower = text.lower()
    expectations = []

    for fact in eval_def.get("facts_to_recover", []):
        passed = fact.lower() in lower
        expectations.append({
            "text": f"Recovers/mentions fact: {fact}",
            "passed": passed,
            "evidence": "found in text" if passed else "not found",
        })

    banned_hits = []
    for pattern in evals_data.get("banned_meta_phrases", []):
        m = re.search(pattern, lower)
        if m:
            banned_hits.append(m.group(0))
    no_meta = len(banned_hits) == 0
    expectations.append({
        "text": "Contains no banned meta-narrative phrasing",
        "passed": no_meta,
        "evidence": "none found" if no_meta else f"found: {banned_hits}",
    })

    for req in evals_data.get("structural_requirements", []):
        found = bool(re.search(req["pattern"], lower))
        expectations.append({
            "text": req["description"],
            "passed": found,
            "evidence": "present" if found else "missing",
        })

    passed_count = sum(1 for e in expectations if e["passed"])
    total = len(expectations)
    return {
        "summary": {
            "pass_rate": passed_count / total if total else 0.0,
            "passed": passed_count,
            "failed": total - passed_count,
            "total": total,
        },
        "expectations": expectations,
    }


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        raise SystemExit(1)

    eval_id_or_name, output_path = sys.argv[1], Path(sys.argv[2])
    evals_data = load_evals()
    eval_def = find_eval(evals_data, eval_id_or_name)
    result = grade(evals_data, eval_def, output_path)

    for exp in result["expectations"]:
        mark = "PASS" if exp["passed"] else "FAIL"
        print(f"  [{mark}] {exp['text']}  ({exp['evidence']})")
    print(f"\nPass rate: {result['summary']['passed']}/{result['summary']['total']}")

    grading_path = output_path.parent / "grading.json"
    grading_path.write_text(json.dumps(result, indent=2))
    print(f"Wrote {grading_path}")


if __name__ == "__main__":
    main()
