#!/usr/bin/env python3
"""Record explicit visual-review evidence in a NEW report, never infer it from rendering."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
from verify import final_state, read_json


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def reviewed_report(report, pdf, images, pages, reviewer, note):
    checks = {item["id"]: item for item in report["checks"]}
    if checks["report_render"]["state"] != "PASS" or report["synthetic_pipeline_state"] != "PASS":
        raise ValueError("Rendering and the synthetic pipeline must PASS first")
    if not reviewer.strip() or not note.strip() or len(images) != pages or len(set(images)) != pages:
        raise ValueError("Named reviewer, notes, and one distinct image path for EVERY page required")
    if report.get("pdf_sha256") and report["pdf_sha256"] != digest(pdf):
        raise ValueError("PDF changed after rendering")
    if any(not image.is_file() or not image.stat().st_size for image in images):
        raise ValueError("Missing page image")
    output = copy.deepcopy(report)
    check = next(item for item in output["checks"] if item["id"] == "visual_review")
    check.update(state="PASS", reviewer=reviewer, note=note, pdf_sha256=digest(pdf), pages=[{"page": i+1, "image_sha256": digest(image)} for i, image in enumerate(images)])
    output["full_acceptance_state"] = final_state(output["checks"])
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--reviewer", required=True)
    parser.add_argument("--note", required=True)
    parser.add_argument("--page-images", type=Path, nargs="+", required=True)
    parser.add_argument("--attest-all-pages-reviewed", action="store_true", required=True)
    parser.add_argument("--pdfinfo", default=shutil.which("pdfinfo"))
    args = parser.parse_args()
    if not args.pdfinfo:
        parser.error("pdfinfo required to independently count every rendered page")
    report_path = args.report.resolve()
    pdf = report_path.parent / "synthetic-todos.pdf"
    information = subprocess.check_output([args.pdfinfo, str(pdf)], text=True)
    pages = int(re.search(r"(?m)^Pages:\s+(\d+)", information).group(1))
    report = reviewed_report(read_json(report_path), pdf, [p.resolve() for p in args.page_images], pages, args.reviewer, args.note)
    report["original_report_sha256"] = digest(report_path)
    target = report_path.parent / "reviewed-report.json"
    with target.open("x") as stream:
        json.dump(report, stream, indent=2)
        stream.write("\n")
    print(json.dumps({"reviewed_report": str(target), "full_acceptance_state": report["full_acceptance_state"]}))


if __name__ == "__main__":
    main()
