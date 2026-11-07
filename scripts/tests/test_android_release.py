import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch
import json
import os
import subprocess
import tempfile

spec = importlib.util.spec_from_file_location("android_release", Path(__file__).parents[1] / "android_release.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ChannelPolicyTests(unittest.TestCase):
    def decision(self, **changes):
        args = dict(event="push", ref="refs/heads/master", publish=False, count=209,
                    source_code=84, source_name="2.0.13", sha="a" * 40)
        args.update(changes)
        return release.decide(**args)

    def test_development_and_stable_upgrade_order(self):
        development = self.decision()
        stable = self.decision(ref="refs/tags/v2.0.13", source_code=1_000_419)
        following = self.decision(count=210)
        self.assertLess(int(development["version_code"]), int(stable["version_code"]))
        self.assertLess(int(stable["version_code"]), int(following["version_code"]))
        self.assertEqual(development["tag"], "development")

    def test_untrusted_refs_and_events_fail(self):
        for changes in [dict(event="pull_request"), dict(ref="refs/heads/feature"),
                        dict(ref="refs/tags/v2.0.14"), dict(ref="refs/tags/v2.0.13-beta"),
                        dict(ref="refs/tags/v2.0.13", source_code=84), dict(count=0),
                        dict(count=1_100_000_000), dict(sha="short")]:
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                self.decision(**changes)

    def test_manual_validation_does_not_publish(self):
        self.assertEqual(self.decision(event="workflow_dispatch")["publish"], "false")
        self.assertEqual(self.decision(event="workflow_dispatch", publish=True)["publish"], "true")


class PublicationRecoveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.previous = Path.cwd()
        os.chdir(self.temp.name)
        self.addCleanup(os.chdir, self.previous)
        self.decision = dict(channel="development", publish="true", sha="a" * 40,
                             tag="development", version_name="2.0.13-beta.aaaaaaaaaaaa",
                             version_code="1000418", build_id="10-1")
        Path("release-decision.json").write_text(json.dumps(self.decision))
        Path("release-assets").mkdir()
        for name in ["new.apk", "new.aab", "SHA256SUMS-new.txt"]:
            (Path("release-assets") / name).write_bytes(b"verified")

    def test_stale_development_never_mutates_release(self):
        with patch.object(release, "api", return_value={"commit": {"sha": "b" * 40}}) as api:
            release.publish()
        self.assertEqual(api.call_count, 1)

    def test_upload_failure_keeps_previous_assets_and_tag(self):
        existing = dict(id=9, tag_name="development", draft=False, prerelease=True, body="old",
                        upload_url="https://uploads.github.com/test{?name}",
                        assets=[dict(id=1, name="old.apk", size=8)])
        calls = []
        def api(method, endpoint, data=None):
            calls.append((method, endpoint))
            if endpoint == "branches/master":
                return {"commit": {"sha": self.decision["sha"]}}
            if endpoint.startswith("releases?"):
                return [existing]
            if method == "GET" and endpoint == "releases/9":
                return existing
            raise AssertionError("Unexpected mutation before upload completed")
        with patch.object(release, "api", side_effect=api), patch.object(release.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "upload")):
            with self.assertRaises(subprocess.CalledProcessError):
                release.publish()
        self.assertTrue(all(method == "GET" for method, _ in calls))

    def test_surviving_stable_draft_is_reused_by_id(self):
        self.decision.update(channel="stable", tag="v2.0.13", version_name="2.0.13")
        Path("release-decision.json").write_text(json.dumps(self.decision))
        Path("docs/releases").mkdir(parents=True)
        Path("docs/releases/2.0.13.md").write_text("Curated notes")
        existing = dict(id=42, tag_name="v2.0.13", draft=True,
                        upload_url="https://uploads.github.com/test{?name}", assets=[])
        calls = []
        def api(method, endpoint, data=None):
            calls.append((method, endpoint))
            if endpoint == "commits/v2.0.13":
                return {"sha": self.decision["sha"]}
            if endpoint.startswith("releases?"):
                return [existing]
            if method == "GET" and endpoint == "releases/42":
                return existing
            raise AssertionError("Draft should be reused before the upload fails")
        with patch.object(release, "api", side_effect=api), patch.object(release.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "upload")):
            with self.assertRaises(subprocess.CalledProcessError):
                release.publish()
        self.assertIn(("GET", "releases/42"), calls)
        self.assertNotIn(("POST", "releases"), calls)

    def test_checksum_parser_rejects_path_escape(self):
        Path("release-assets/SHA256SUMS").write_text("0" * 64 + "  ../escape.apk\n")
        with self.assertRaises(ValueError):
            release.verify_manifest(Path("release-assets"), "SHA256SUMS", {"SHA256SUMS", "../escape.apk"})

    def test_moved_stable_tag_never_uploads_or_mutates(self):
        self.decision.update(channel="stable", tag="v2.0.13", version_name="2.0.13")
        Path("release-decision.json").write_text(json.dumps(self.decision))
        with patch.object(release, "api", return_value={"sha": "b" * 40}) as api, \
             patch.object(release.subprocess, "run") as upload:
            with self.assertRaisesRegex(ValueError, "Stable tag moved"):
                release.publish()
        api.assert_called_once_with("GET", "commits/v2.0.13")
        upload.assert_not_called()

    def test_non_prerelease_development_is_not_mutated(self):
        existing = dict(id=9, tag_name="development", draft=False, prerelease=False)
        def api(method, endpoint, data=None):
            self.assertEqual(method, "GET")
            if endpoint == "branches/master":
                return {"commit": {"sha": self.decision["sha"]}}
            if endpoint.startswith("releases?"):
                return [existing]
            raise AssertionError(endpoint)
        with patch.object(release, "api", side_effect=api), patch.object(release.subprocess, "run") as upload:
            with self.assertRaisesRegex(ValueError, "non-prerelease"):
                release.publish()
        upload.assert_not_called()

    def published_fixture(self, stable=False):
        decision = dict(self.decision)
        if stable:
            decision.update(channel="stable", tag="v2.0.13", version_name="2.0.13")
        current = dict(id=42, tag_name=decision["tag"], draft=False, prerelease=not stable,
                       body=f"Commit: {decision['sha']}",
                       assets=[dict(id=i, name=p.name, size=p.stat().st_size)
                               for i, p in enumerate(sorted(Path("release-assets").iterdir()), 1)])
        return decision, current

    def test_final_published_state_checks_flags_latest_source_and_inventory(self):
        for change in ["draft", "prerelease", "source", "notes", "inventory", "latest", "identity"]:
            with self.subTest(change=change):
                decision, current = self.published_fixture(stable=True)
                if change == "draft": current["draft"] = True
                if change == "prerelease": current["prerelease"] = True
                if change == "notes": current["body"] = "wrong source"
                if change == "inventory": current["assets"] = []
                if change == "identity": current["tag_name"] = "v9.9.9"
                def api(method, endpoint, data=None):
                    self.assertEqual(method, "GET")
                    if endpoint == "releases/42": return current
                    if endpoint == "commits/v2.0.13":
                        return {"sha": "b" * 40 if change == "source" else decision["sha"]}
                    if endpoint == "releases/latest":
                        return {"id": 99 if change == "latest" else 42}
                    raise AssertionError(endpoint)
                with patch.object(release, "api", side_effect=api), patch.object(release, "verify_downloads") as verify:
                    with self.assertRaises(ValueError):
                        release.verify_published_release(42, decision, {p.name for p in Path("release-assets").iterdir()}, list(Path("release-assets").iterdir()))
                verify.assert_not_called()

    def test_final_state_rechecks_downloads_after_publication(self):
        decision, current = self.published_fixture()
        def api(method, endpoint, data=None):
            self.assertEqual(method, "GET")
            if endpoint == "releases/42": return current
            if endpoint == "commits/development": return {"sha": decision["sha"]}
            raise AssertionError(endpoint)
        local = list(Path("release-assets").iterdir())
        with patch.object(release, "api", side_effect=api), patch.object(release, "verify_downloads") as verify:
            release.verify_published_release(42, decision, {p.name for p in local}, local)
        verify.assert_called_once_with(current["assets"], local)

    def test_surviving_stable_draft_uploads_and_publishes_same_id(self):
        decision, current = self.published_fixture(stable=True)
        current.update(draft=True, upload_url="https://uploads.github.com/test{?name}", assets=[])
        Path("release-decision.json").write_text(json.dumps(decision))
        Path("docs/releases").mkdir(parents=True)
        Path("docs/releases/2.0.13.md").write_text("Curated notes")
        calls = []
        def api(method, endpoint, data=None):
            calls.append((method, endpoint))
            if endpoint == "commits/v2.0.13": return {"sha": decision["sha"]}
            if endpoint.startswith("releases?"): return [current]
            if endpoint == "releases/latest": return current
            if endpoint == "releases/42":
                if method == "PATCH": current.update(data)
                return current
            raise AssertionError((method, endpoint))
        def upload(args, **kwargs):
            path = Path(args[-1])
            current["assets"].append(dict(id=len(current["assets"]) + 1, name=path.name, size=path.stat().st_size))
        with patch.object(release, "api", side_effect=api), patch.object(release.subprocess, "run", side_effect=upload), \
             patch.object(release, "verify_downloads") as verify:
            release.publish()
        self.assertFalse(current["draft"])
        self.assertFalse(current["prerelease"])
        self.assertEqual(current["make_latest"], "true")
        self.assertNotIn(("POST", "releases"), calls)
        self.assertEqual(verify.call_count, 2)
        self.assertEqual(calls[-1], ("GET", "releases/latest"))

    def test_existing_published_stable_is_verified_without_mutations(self):
        decision, current = self.published_fixture(stable=True)
        Path("release-decision.json").write_text(json.dumps(decision))
        Path("docs/releases").mkdir(parents=True)
        Path("docs/releases/2.0.13.md").write_text("Curated notes")
        def api(method, endpoint, data=None):
            self.assertEqual(method, "GET")
            if endpoint == "commits/v2.0.13": return {"sha": decision["sha"]}
            if endpoint.startswith("releases?"): return [current]
            raise AssertionError(endpoint)
        with patch.object(release, "api", side_effect=api), patch.object(release, "verify_published_release") as verify, \
             patch.object(release.subprocess, "run") as upload:
            release.publish()
        verify.assert_called_once_with(42, decision, {p.name for p in Path("release-assets").iterdir()})
        upload.assert_not_called()


if __name__ == "__main__":
    unittest.main()
