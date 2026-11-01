"""Safety/acceptance tests for dev tooling only; no database or app."""
import copy
from pathlib import Path
import sys
import tempfile
import re
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from bootstrap import connection_environment, freeze_sources, pipeline_exit_code, safe_output, socket_options
from verify import DOCS, ROOT, final_state, read_json, validate_approval, validate_schema, validate_study, validate_workflow
from record_review import reviewed_report


class Contracts(unittest.TestCase):
    def setUp(self):
        self.workflow = read_json(DOCS / "workflow.json")

    def test_cycle_and_future_dependency_rejected(self):
        self.workflow["steps"][0]["depends_on"] = ["release"]
        self.assertTrue(validate_workflow(self.workflow))

    def test_shared_artifact_ownership_rejected(self):
        self.workflow["roles"][1]["owns"].append("source-manifest")
        self.assertTrue(validate_workflow(self.workflow))

    def test_authority_cannot_be_switched_on(self):
        self.workflow["authority"]["production_access_by_default"] = True
        self.assertTrue(validate_workflow(self.workflow))

    def test_missing_required_fields_rejected_by_schema(self):
        del self.workflow["steps"][0]["action"]
        self.assertTrue(validate_schema(self.workflow, read_json(DOCS / "workflow.schema.json")))

    def test_schema_changes_cannot_silently_add_unsupported_rules(self):
        self.assertTrue(validate_schema({}, {"unknownConstraint": True}))

    def test_incomplete_profile_blocks_adaptation(self):
        self.assertTrue(validate_study(read_json(DOCS / "study-template.json")))

    def test_missing_required_checks_never_pass(self):
        for state in ("NOT RUN", "NOT AVAILABLE"):
            self.assertEqual(final_state([{"state": "PASS"}, {"state": state}]), "NOT RUN")
        self.assertEqual(final_state([{"state": "NOT RUN"}, {"state": "FAIL"}]), "FAIL")
        self.assertEqual(final_state([{"state": "PASS"}, {"state": "NOT AVAILABLE", "required": False}]), "PASS")

    def test_existing_or_broad_output_rejected(self):
        with tempfile.TemporaryDirectory() as path:
            with self.assertRaises(ValueError):
                safe_output(Path(path))
        with self.assertRaises(ValueError):
            safe_output(Path("/"))

    def test_adaptation_requires_exact_human_approved_paths(self):
        approval = {"approved_by": "Invented reviewer", "rationale": "Invented decision", "approved_paths": ["main/global.R"]}
        self.assertFalse(validate_approval(["main/global.R"], approval))
        self.assertTrue(validate_approval(["main/server.R"], approval))
        approval["approved_paths"] = ["main/*"]
        self.assertTrue(validate_approval(["main/global.R"], approval))

    def test_review_cannot_bless_failed_or_incomplete_pdf(self):
        report = {"synthetic_pipeline_state": "FAIL", "checks": [{"id":"report_render", "state":"PASS"}]}
        with self.assertRaises(ValueError):
            reviewed_report(report, Path("unused"), [], 2, "Reviewer", "Notes")
        report["synthetic_pipeline_state"] = "PASS"
        with self.assertRaises(ValueError):
            reviewed_report(report, Path("unused"), [Path("page1")], 2, "Reviewer", "Notes")

    def test_executed_test_files_are_frozen(self):
        selected = re.findall(r'"(test-[^"\n]+[.]R)"', (ROOT / "tools/reconstruction/checks.R").read_text())
        self.assertTrue(selected)
        frozen = freeze_sources()
        self.assertTrue(all("tests/testthat/" + name in frozen for name in selected))

    def test_late_required_failure_returns_nonzero(self):
        report = {"owned_shutdown": True, "checks": [{"state": "FAIL", "required": True}]}
        self.assertEqual(pipeline_exit_code(report), 1)
        report["checks"][0]["state"] = "NOT RUN"
        self.assertEqual(pipeline_exit_code(report), 0) # incomplete evidence is reported, never called full PASS

    def test_external_mysql_environment_cannot_redirect_connections(self):
        environment = {"MYSQL_HOST":"example.invalid", "MYSQL_PWD":"invented", "MARIADB_HOME":"invented", "R_LIBS":"overlay"}
        self.assertEqual(connection_environment(environment), {"R_LIBS":"overlay"})

    def test_cli_transport_is_explicit_socket_and_localhost(self):
        options = socket_options(Path("/tmp/fw-reconstruct-invented.sock"))
        self.assertEqual(options[0], "--no-defaults")
        self.assertIn("--protocol=SOCKET", options)
        self.assertIn("--host=localhost", options)


if __name__ == "__main__":
    unittest.main()
