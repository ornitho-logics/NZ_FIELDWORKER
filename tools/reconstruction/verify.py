#!/usr/bin/env python3
"""Offline reconstruction-contract validation; never sources the app."""
import argparse
import json
import re
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs/reconstruction"
PROTECTED = ("main/", "DataEntry/", "gpxui/", "DATABASE/",
             "notes/codex_proposals/validator_sandbox/")
STATES = {"PASS", "FAIL", "NOT RUN", "NOT AVAILABLE"}


def validate_schema(value, schema, path="$"):
    """Validate every keyword used by our bundled schema, offline.

    Not a general JSON Schema engine: a new unsupported keyword fails loudly.
    Standard validators can also consume the same schema on other platforms.
    """
    supported = {"$schema", "title", "type", "required", "properties", "const",
                 "pattern", "minLength", "minimum", "items", "enum", "minItems", "uniqueItems"}
    unknown = set(schema) - supported
    if unknown:
        return [path + ": unsupported schema keywords " + str(sorted(unknown))]
    types = {"object": dict, "array": list, "string": str, "integer": int}
    expected = schema.get("type")
    if expected and (not isinstance(value, types[expected]) or expected == "integer" and isinstance(value, bool)):
        return [path + ": wrong type"]
    errors = []
    if "const" in schema and (value != schema["const"] or type(value) is not type(schema["const"])):
        errors.append(path + ": wrong constant")
    if "enum" in schema and value not in schema["enum"]:
        errors.append(path + ": invalid enum")
    if "minimum" in schema and value < schema["minimum"]:
        errors.append(path + ": below minimum")
    if isinstance(value, dict):
        errors += [path + ": missing " + key for key in schema.get("required", []) if key not in value]
        for key, contract in schema.get("properties", {}).items():
            if key in value:
                errors += validate_schema(value[key], contract, path + "." + key)
    if isinstance(value, list):
        if len(value) < schema.get("minItems", 0):
            errors.append(path + ": insufficient items")
        if schema.get("uniqueItems") and len({json.dumps(v, sort_keys=True) for v in value}) != len(value):
            errors.append(path + ": duplicate item")
        for index, item in enumerate(value):
            if "items" in schema:
                errors += validate_schema(item, schema["items"], path + "[" + str(index) + "]")
    if isinstance(value, str):
        if len(value) < schema.get("minLength", 0) or "pattern" in schema and not re.search(schema["pattern"], value):
            errors.append(path + ": string constraint failed")
    return errors


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def final_state(checks):
    required = [c["state"] for c in checks if c.get("required", True)]
    if "FAIL" in required:
        return "FAIL"
    return "PASS" if required and all(s == "PASS" for s in required) else "NOT RUN"


def validate_workflow(workflow):
    errors = []
    roles = [r["id"] for r in workflow["roles"]]
    if len(set(roles)) != len(roles):
        errors.append("duplicate role")
    owners = [p for r in workflow["roles"] for p in r["owns"]]
    if len(set(owners)) != len(owners):
        errors.append("overlapping artifact ownership")
    steps = workflow["steps"]
    ids = [s["id"] for s in steps]
    if len(set(ids)) != len(ids):
        errors.append("duplicate step")
    visited = set()
    for step in steps:
        if step["role"] not in roles:
            errors.append("unknown role: " + step["id"])
        if not set(step["depends_on"]).issubset(visited):
            errors.append("missing, cyclic or out-of-order dependency: " + step["id"])
        if not all(step.get(k) for k in ("action", "gate", "outputs")):
            errors.append("empty step contract: " + step["id"])
        for path in step["inputs"]:
            if not (ROOT / path).is_file():
                errors.append("missing input: " + path)
        visited.add(step["id"])
    flags = workflow["authority"]
    expected = {"human_scientific_decisions_required": True, "production_access_by_default": False,
                "publication_by_default": False, "profiles_are_runtime_configuration": False,
                "history_is_normative": False, "failed_required_gate_stops_dependents": True}
    if any(flags.get(k) is not v for k, v in expected.items()):
        errors.append("authority contract changed")
    return errors


def validate_study(profile):
    if not profile.get("id") or not profile.get("scientific_owner"):
        return ["study ID and scientific owner required"]
    required = {d["id"] for d in read_json(DOCS / "study-template.json")["decisions"]}
    decisions = profile.get("decisions", [])
    if len({d["id"] for d in decisions}) != len(decisions):
        return ["duplicate study decision"]
    errors = []
    if {d["id"] for d in decisions} != required:
        errors.append("study decision inventory differs from template")
    for decision in decisions:
        if decision.get("status") not in ("approved", "disabled") or not decision.get("rationale") or not decision.get("approved_by"):
            errors.append("unresolved decision: " + decision["id"])
        if decision.get("status") == "approved" and decision.get("value") is None:
            errors.append("missing approved value: " + decision["id"])
    return errors


def protected_changes(reference, root=ROOT):
    changed = subprocess.check_output(["git", "diff", "--name-only", reference, "--"], cwd=root, text=True).splitlines()
    changed += subprocess.check_output(["git", "ls-files", "--others", "--exclude-standard"], cwd=root, text=True).splitlines()
    return sorted({p for p in changed if p.startswith(PROTECTED)})


def validate_approval(changed, approval):
    if not approval.get("approved_by") or not approval.get("rationale"):
        return ["Named human approval and rationale required for target changes"]
    paths = approval.get("approved_paths", [])
    if any(not isinstance(p, str) or not p or p.startswith("/") or ".." in Path(p).parts or any(c in p for c in "*?[]\\") for p in paths):
        return ["Approved paths must be literal repository-relative files"]
    return ["Unapproved target runtime change: " + p for p in changed if p not in paths]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--study", type=Path, help="Validate completed adaptation decisions; unresolved template must fail")
    parser.add_argument("--mode", choices=("reference_reproduction", "study_adaptation"), default="reference_reproduction")
    parser.add_argument("--approved-changes", type=Path)
    parser.add_argument("--reference-root", type=Path, help="Separate retained reference checkout for adaptation comparison")
    args = parser.parse_args()
    errors = []
    workflow = read_json(DOCS / "workflow.json")
    schema = read_json(DOCS / "workflow.schema.json")
    errors += validate_schema(workflow, schema)
    formal = "FAIL" if errors else "PASS"
    if errors:
        print(json.dumps({"state": "FAIL", "errors": errors}, indent=2))
        return 1
    errors += validate_workflow(workflow)
    rules = read_json(DOCS / "rules.json")
    identifiers = [r["id"] for r in rules["rules"]]
    if len(set(identifiers)) != len(identifiers):
        errors.append("duplicate rule ID")
    for rule in rules["rules"]:
        if not rule["statement"] or not rule["transfer"]:
            errors.append("incomplete rule: " + rule["id"])
        for path in rule["sources"] + rule["tests"]:
            if not (ROOT / path).is_file():
                errors.append("missing rule reference: " + path)
        if 'id="' + rule["manual_anchor"] + '"' not in (ROOT / rules["manual"]).read_text():
            errors.append("missing manual anchor: " + rule["id"])
    protocol = ROOT / rules["validator_protocol"]
    if "protocol_version: " + rules["validator_version"] not in protocol.read_text():
        errors.append("validator protocol identity mismatch")
    for check in read_json(DOCS / "acceptance.json")["checks"]:
        if "/" in check["executor"] and not (ROOT / check["executor"]).is_file():
            errors.append("missing executor: " + check["executor"])
    changed = protected_changes(workflow["reference_commit"])
    if args.mode == "reference_reproduction":
        errors += ["protected runtime changed: " + p for p in changed]
    else:
        if not args.study or not args.approved_changes or not args.reference_root:
            errors.append("Adaptation requires approved study, literal change manifest and separate reference-root")
        else:
            if args.reference_root.resolve() == ROOT:
                errors.append("Target and retained reference must be separate checkouts")
            approval = read_json(args.approved_changes)
            errors += validate_approval(changed, approval)
            if approval.get("reference_commit") != workflow["reference_commit"]:
                errors.append("Change approval references a different baseline")
            errors += ["Retained reference changed: " + p for p in protected_changes(workflow["reference_commit"], args.reference_root)]
    if args.study:
        errors += validate_study(read_json(args.study))
    print(json.dumps({"state": "FAIL" if errors else "PASS", "mode": args.mode, "formal_json_schema": formal,
                      "rules": len(identifiers), "steps": len(workflow["steps"]),
                      "protected_runtime_changes": changed, "errors": errors}, indent=2))
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
