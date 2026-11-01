#!/usr/bin/env python3
"""Reproduce reference SQL on a new owned synthetic MariaDB, never an existing service."""
import argparse
from collections import Counter
import hashlib
import json
import os
import plistlib
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid

from verify import ROOT, DOCS, final_state, read_json

TOOLS = Path(__file__).resolve().parent
SCHEMA = "FIELD_2026_BADOatNZ"


def safe_output(path):
    path = path.resolve()
    allowed = [ROOT / "tmp/codex", Path(tempfile.gettempdir()).resolve(), Path("/tmp").resolve()]
    if path.exists() or not any(base in path.parents for base in allowed):
        raise ValueError("Output must be a NEW directory below ignored tmp/codex or system temporary storage")
    return path


def quote_identifier(value):
    return "`" + value.replace("`", "``") + "`"


def connection_environment(environment):
    return {k: v for k, v in environment.items() if not k.startswith(("MYSQL", "MARIADB"))}


def socket_options(socket):
    return ["--no-defaults", "--protocol=SOCKET", "--host=localhost", "--user=root", "--socket=" + str(socket)]


def freeze_sources():
    tracked = subprocess.check_output(["git", "ls-files"], cwd=ROOT, text=True).splitlines()
    sources = [ROOT / p for p in tracked if p.startswith(("main/", "DataEntry/", "gpxui/", "DATABASE/", "tests/", "notes/codex_proposals/validator_sandbox/"))]
    sources += [p for folder in (TOOLS, DOCS) for p in folder.rglob("*") if p.is_file() and p.suffix in (".py", ".R", ".json", ".sql", ".md") and "__pycache__" not in p.parts]
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(set(sources))}


def pipeline_exit_code(report):
    return int(bool(report.get("error") or not report.get("owned_shutdown", False) or
                    any(c.get("required", True) and c["state"] == "FAIL" for c in report["checks"])))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mariadb-bin", type=Path, help="Directory containing MariaDB 11.8.9 client/server/install-db/admin")
    parser.add_argument("--output", type=Path, help="New artifact directory (default ignored tmp/codex)")
    parser.add_argument("--render", action="store_true", help="Render synthetic PDF after gates; still requires visual review")
    parser.add_argument("--quarto", type=Path, help="Explicit local Quarto executable, never an installer")
    args = parser.parse_args()
    token = uuid.uuid4().hex
    output = safe_output(args.output or ROOT / "tmp/codex" / ("reconstruction-" + token[:10]))
    output.mkdir(parents=True)
    specification = read_json(DOCS / "acceptance.json")
    catalog_rules = read_json(DOCS / "rules.json")["rules"]
    checks = {c["id"]: dict(c, state="NOT RUN") for c in specification["checks"]}
    checks["legacy_golden_equivalence"]["state"] = "NOT AVAILABLE"
    report = {"schema_version": "1.0.0", "mode": "reference_reproduction", "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "data": "invented fixtures only; no dump/config/network", "checks": list(checks.values()), "stages": [], "files": {}}
    source_manifest = freeze_sources()
    (output / "source-manifest.json").write_text(json.dumps({"reference": "9e010e5", "selected_commit": report["source_commit"], "sha256": source_manifest}, indent=2) + "\n")
    process = None
    server_log = None
    owned_device = None
    attachment_attempted = False
    image = None
    active_check = "recipe"
    connection_env = connection_environment(os.environ)
    socket_base = Path("/private/tmp") if Path("/private/tmp").exists() else Path("/tmp")
    socket = socket_base / ("fw-reconstruct-" + token[:12] + ".sock")
    owner = output / "owner.json"
    owner.write_text(json.dumps({"token": token, "socket": str(socket), "purpose": "synthetic_reconstruction"}))

    def record(name, state="PASS", **evidence):
        checks[name].update(state=state, **evidence)
        print(name + ": " + state, flush=True)

    def run(label, command, *, data=None, timeout=1800, env=None, allow_missing=False):
        started = time.monotonic()
        log = output / (label + ".log")
        try:
            with log.open("w") as stream:
                result = subprocess.run(command, cwd=ROOT, input=data, text=True, stdout=stream, stderr=subprocess.STDOUT, timeout=timeout, env=connection_env if env is None else env)
        except FileNotFoundError:
            if allow_missing:
                return None
            raise
        report["stages"].append({"name": label, "exit_code": result.returncode, "wall_seconds": round(time.monotonic() - started, 3)})
        if result.returncode and not allow_missing:
            raise RuntimeError(label + " failed; inspect " + log.name)
        return result.returncode

    def binary(name):
        path = args.mariadb_bin / name if args.mariadb_bin else Path(shutil.which(name) or "/nonexistent")
        if not path.is_file():
            raise FileNotFoundError("Missing MariaDB executable: " + name)
        return str(path)

    client = None

    def query(sql):
        return subprocess.check_output(client + [SCHEMA], input=sql, text=True, cwd=ROOT, timeout=120, env=connection_env).splitlines()

    def install(label, path, database=None):
        report["files"][str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
        run(label, client + ([database] if database else []), data=path.read_text())

    def publication():
        health = query("SELECT state, completed_at IS NOT NULL, reference_date=(SELECT value FROM settings WHERE variable='reference_date'), task_row_count=(SELECT COUNT(*) FROM TODO_LIST) FROM TODO_REFRESH_STATUS ORDER BY refresh_id DESC LIMIT 1;")
        if len(health) != 1 or health[0] != "succeeded\t1\t1\t1":
            raise RuntimeError("Newest publication state/count/date gate failed")
        leftovers = query("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_type='BASE TABLE' AND (RIGHT(table_name,6)='_BUILD' OR RIGHT(table_name,9)='_PREVIOUS');")
        if leftovers != ["0"]:
            raise RuntimeError("Abnormal BUILD/PREVIOUS tables remain")
        def columns(table):
            return query("SELECT COLUMN_NAME FROM information_schema.columns WHERE table_schema=DATABASE() AND table_name='" + table + "' ORDER BY ORDINAL_POSITION;")
        names = columns("TODO_LIST")
        if not names or names != columns("TODO_LIST_SNAPSHOT"):
            raise RuntimeError("TODO/snapshot column contract differs")
        select = "SELECT JSON_ARRAY(" + ",".join(map(quote_identifier, names)) + ") FROM "
        def multiset(table):
            # Typed JSON preserves SQL NULL versus literal text and duplicate
            # rows. Python integers retain exact BIGINT values; no row-name digest.
            return Counter(json.dumps(json.loads(row), ensure_ascii=True, separators=(",", ":")) for row in query(select + table + ";"))
        if multiset("TODO_LIST") != multiset("TODO_LIST_SNAPSHOT"):
            raise RuntimeError("Exact typed TODO/snapshot row multiset differs")
        pointers = {
            "TODO_NEST_CONTEXT_INPUT": "TODO_NEST_CONTEXT_SNAPSHOT",
            "TODO_BROOD_CONTEXT_INPUT": "TODO_BROOD_CONTEXT_SNAPSHOT",
            "TODO_CHICK_CAPTURE_CONTEXT_INPUT": "TODO_CHICK_CAPTURE_CONTEXT_SNAPSHOT",
            "TODO_HIDING_SPOT_PHOTO_CONTEXT_INPUT": "TODO_HIDING_SPOT_PHOTO_CONTEXT_SNAPSHOT",
            "ADULT_CHICK_GPS_PARENT_LINKS_INPUT": "TODO_PARENT_CHICK_GPS_LINKS_SNAPSHOT",
            "TODO_PARENT_STATUS_INPUT": "TODO_PARENT_STATUS_SNAPSHOT",
            "TODO_PARENT_STATUS": "TODO_PARENT_STATUS_SNAPSHOT",
            "TODO_BROOD_CLOSURE_STATUS": "TODO_BROOD_CLOSURE_STATUS_SNAPSHOT"
        }
        for view, target in pointers.items():
            body = query("SELECT VIEW_DEFINITION FROM information_schema.views WHERE table_schema=DATABASE() AND table_name='" + view + "';")
            if len(body) != 1 or target.lower() not in body[0].lower():
                raise RuntimeError("Unexpected helper routing: " + view)

    try:
        run("recipe", [sys.executable, str(TOOLS / "verify.py")])
        record("recipe")
        active_check = "environment"
        code = run("environment", ["Rscript", "--vanilla", str(TOOLS / "runtime_inventory.R"), "--check"], allow_missing=True)
        record("environment", "PASS" if code == 0 else "NOT AVAILABLE", detail="See environment.log; unresolved package provenance cannot count as a pin")
        active_check = "isolated_install"
        client = [binary("mariadb"), *socket_options(socket), "--batch", "--raw", "--skip-column-names", "--unbuffered"]
        server = binary("mariadbd")
        installer = binary("mariadb-install-db")
        admin = binary("mariadb-admin")
        if socket.exists():
            raise RuntimeError("Fresh socket unexpectedly exists; refusing to reuse")
        datadir = output / "data"
        if sys.platform == "darwin":
            # The full reference refresh needs the target's case-sensitive
            # table semantics; native case-insensitive macOS is not equivalent.
            image = output / "synthetic-server.sparsebundle"
            mount = output / "case-sensitive"
            mount.mkdir()
            run("create_case_sensitive_volume", ["hdiutil", "create", "-size", "2g", "-fs", "Case-sensitive APFS", "-type", "SPARSEBUNDLE", "-volname", "FWReconstruct_" + token[:8], str(image)], timeout=120)
            attachment_attempted = True
            attached = plistlib.loads(subprocess.check_output(["hdiutil", "attach", "-nobrowse", "-mountpoint", str(mount), "-plist", str(image)], timeout=120))
            devices = [item["dev-entry"] for item in attached.get("system-entities", []) if item.get("mount-point") == str(mount)]
            if len(devices) != 1:
                raise RuntimeError("Could not establish exact owned image device")
            owned_device = devices[0]
            datadir = mount / "data"
        run("initialise", [installer, "--no-defaults", "--datadir=" + str(datadir), "--auth-root-authentication-method=normal", "--skip-test-db", "--lower-case-table-names=0"], timeout=120)
        server_log = (output / "server.log").open("w")
        command = [server, "--no-defaults", "--datadir=" + str(datadir), "--socket=" + str(socket), "--pid-file=" + str(output / "server.pid"), "--skip-networking", "--lower-case-table-names=0", "--character-set-server=utf8mb4", "--collation-server=utf8mb4_uca1400_ai_ci"]
        if hasattr(os, "geteuid") and os.geteuid() == 0:
            command.append("--user=root")
        process = subprocess.Popen(command, stdout=server_log, stderr=subprocess.STDOUT, env=connection_env)
        for _ in range(150):
            if process.poll() is not None:
                raise RuntimeError("Owned server exited; inspect server.log")
            probe = subprocess.run(client, input="SELECT 1;", text=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=connection_env)
            if probe.returncode == 0:
                break
            time.sleep(.2)
        else:
            raise RuntimeError("Owned server did not become ready")
        settings = subprocess.check_output(client, input="SELECT VERSION(), @@skip_networking, @@lower_case_table_names, @@collation_server;", text=True, env=connection_env).strip().split("\t")
        if len(settings) != 4 or not settings[0].startswith("11.8.9-") or settings[1:3] != ["1", "0"] or settings[3] != "utf8mb4_uca1400_ai_ci":
            raise RuntimeError("Target version/network/collation differs")
        report["server"] = dict(zip(("version", "skip_networking", "lower_case_table_names", "collation"), settings))
        install("base_tables", ROOT / "DATABASE/main_tables.SQL")
        install("support_tables", ROOT / "DATABASE/support_tables.SQL", SCHEMA)
        install("fixtures", TOOLS / "fixtures.sql")
        query("CREATE TABLE reconstruction_owner(token varchar(32)); INSERT INTO reconstruction_owner VALUES ('" + token + "');")
        install("functions", ROOT / "DATABASE/functions.SQL")
        install("hatching", ROOT / "DATABASE/predict_hatching.SQL")
        active_check = "inspectors"
        run("inspectors", ["Rscript", "--vanilla", str(TOOLS / "inspectors.R"), str(ROOT), str(socket), str(owner)])
        record("inspectors")
        active_check = "isolated_install"
        install("views", ROOT / "DATABASE/views.SQL", SCHEMA)
        record("isolated_install")
        active_check = "publication"
        install("refresh", ROOT / "DATABASE/refresh_todo_list_snapshot.SQL", SCHEMA)
        publication()
        record("publication")
        active_check = "semantic_fixtures"
        # Connected full-instance check supplements the small predicate fixtures.
        values = query("SELECT latest_encounter_count=1, latest_encounter_flagged_count=1 FROM TODO_CHICK_CAPTURE_CONTEXT_INPUT WHERE nest_id='C9902';")
        if values != ["1\t1"]:
            raise RuntimeError("Synthetic latest ring-linked flagged encounter differs")
        if query("SELECT COUNT(*) FROM TODO_LIST WHERE nest_id='C9902' AND LOWER(todo) LIKE '%flag%';") != ["0"]:
            raise RuntimeError("Synthetic fully flagged latest encounter still has a flagging task")
        env = dict(connection_env)
        env["PATH"] = str(Path(client[0]).parent) + os.pathsep + env.get("PATH", "")
        run("semantic_fixtures", ["Rscript", "--vanilla", str(TOOLS / "checks.R"), str(ROOT), str(socket), str(output / "focused-results.json"), str(owner)], env=env)
        record("semantic_fixtures")
        active_check = "reference_transition"
        install("historical_view", ROOT / "DATABASE/notA_summary.SQL")
        history = query("SELECT male_later_confirmed_nests LIKE '%C9904%', COALESCE(female_later_confirmed_nests,'') NOT LIKE '%C9904%' FROM notA_summary WHERE nest_id='C9903';")
        if history != ["1\t1"]:
            raise RuntimeError("Historical synthetic confirmed-identity link gate failed")
        view_definition = query("SHOW CREATE VIEW notA_summary;")
        query("UPDATE settings SET value='2026-11-03' WHERE variable='reference_date';")
        if query("SELECT COUNT(*) FROM notA_summary;") != ["0"]:
            raise RuntimeError("Historical report did not hide stale snapshot")
        install("refresh_next_date", ROOT / "DATABASE/refresh_todo_list_snapshot.SQL", SCHEMA)
        publication()
        if query("SHOW CREATE VIEW notA_summary;") != view_definition or query("SELECT COUNT(*)>0 FROM notA_summary;") != ["1"]:
            raise RuntimeError("Historical view did not follow normal publication without reinstall")
        record("reference_transition")
        record("study_decisions", detail="Reference-description scope only; no target-study transfer approval")
        if args.render:
            active_check = "report_render"
            quarto = args.quarto or shutil.which("quarto")
            bundled = Path("/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto")
            if not quarto and bundled.is_file():
                quarto = bundled
            if quarto:
                env["QUARTO_PATH"] = str(quarto)
            run("render", ["Rscript", "--vanilla", str(TOOLS / "render.R"), str(ROOT), str(socket), str(output / "synthetic-todos.pdf"), str(owner)], env=env)
            record("report_render")
            report["pdf_sha256"] = hashlib.sha256((output / "synthetic-todos.pdf").read_bytes()).hexdigest()
    except (Exception, KeyboardInterrupt) as error:
        report["error"] = str(error)
        record(active_check, "FAIL", detail=str(error))
    finally:
        shutdown = True
        if process is not None:
            if process.poll() is None:
                try:
                    subprocess.run([admin, *socket_options(socket), "shutdown"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20, env=connection_env)
                    process.wait(timeout=20)
                except (subprocess.TimeoutExpired, OSError):
                    shutdown = False
                    process.terminate() # Only the Popen-owned PID; never a service/session lookup.
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
            shutdown = shutdown and not socket.exists()
        if server_log is not None:
            server_log.close()
        if attachment_attempted and owned_device is None:
            # A mount can succeed before an attach call is interrupted or its
            # response parsed. Recover only this newly created image's device.
            try:
                information = plistlib.loads(subprocess.check_output(["hdiutil", "info", "-plist"], timeout=15))
                matches = [item for item in information.get("images", []) if Path(item.get("image-path", "")).resolve() == image.resolve()]
                if matches:
                    entities = matches[0].get("system-entities", [])
                    owned_device = next((e.get("dev-entry") for e in entities if e.get("dev-entry")), None)
                    if owned_device is None:
                        shutdown = False
                else:
                    report["owned_image_detached"] = True
            except (subprocess.SubprocessError, OSError, ValueError):
                shutdown = False
        if owned_device:
            try:
                subprocess.run(["hdiutil", "detach", owned_device], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=30)
                report["owned_image_detached"] = True
            except (subprocess.SubprocessError, OSError):
                report["owned_image_detached"] = False
                shutdown = False
        report["owned_shutdown"] = shutdown
        if not shutdown:
            record("isolated_install", "FAIL", detail="Owned shutdown/socket cleanup did not complete normally")
        computational = [checks[n] for n in ("recipe", "isolated_install", "inspectors", "publication", "semantic_fixtures", "reference_transition")]
        report["source_manifest_sha256"] = hashlib.sha256((output / "source-manifest.json").read_bytes()).hexdigest()
        drift = [path for path, digest in source_manifest.items() if not (ROOT / path).is_file() or hashlib.sha256((ROOT / path).read_bytes()).hexdigest() != digest]
        if drift:
            record("recipe", "FAIL", detail="Source changed during execution", changed_paths=drift)
        try:
            executed = read_json(output / "focused-results.json") if (output / "focused-results.json").is_file() else {}
        except (OSError, ValueError):
            executed = {}
            record("semantic_fixtures", "FAIL", detail="Unreadable focused check artifact")
        report["rule_coverage"] = []
        for rule in catalog_rules:
            remaining = [path for path in rule["tests"] if Path(path).name not in executed]
            report["rule_coverage"].append({"id": rule["id"], "state": "NOT RUN" if remaining or checks["semantic_fixtures"]["state"] != "PASS" else "PASS", "remaining_declared_test_files": remaining})
        report["rule_coverage_note"] = "Crosswalk file coverage only; PASS does not establish completeness of scientific scenarios. Full target-study acceptance requires independent approved cases."
        report["synthetic_pipeline_state"] = final_state(computational)
        report["full_acceptance_state"] = final_state(report["checks"])
        (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({"report": str(output / "report.json"), "synthetic_pipeline": report["synthetic_pipeline_state"], "full_acceptance": report["full_acceptance_state"], "owned_shutdown": shutdown}), flush=True)
    return pipeline_exit_code(report)


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    raise SystemExit(main())
