#!/usr/bin/env python3
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from release_validation import ValidationError, fdroid_readiness, parse_explicit_bool, validate_release

REPO = Path(__file__).resolve().parents[2]


def write_repo(base: Path, *, version_name="2.0.12", version_code=84, target_sdk=35, changelog="Native release.\n", license=False):
    app = base / "android" / "app"
    changelogs = base / "fastlane" / "metadata" / "android" / "en-US" / "changelogs"
    changelogs.mkdir(parents=True, exist_ok=True)
    (changelogs / f"{version_code}.txt").write_text(changelog, encoding="utf-8")
    app.mkdir(parents=True, exist_ok=True)
    (app / "build.gradle.kts").write_text(
        f'targetSdk = {target_sdk}\nversionCode = {version_code}\nversionName = "{version_name}"\n',
        encoding="utf-8",
    )
    if license:
        (base / "LICENSE").write_text("Owner-selected license text\n", encoding="utf-8")
    return app


class GateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        write_repo(self.repo)

    def valid(self, **overrides):
        options = dict(
            tag_ref="refs/tags/v2.0.12",
            sign_artifacts=False,
            publish_github=False,
            upload_play_internal=False,
            release_signing_enabled=False,
            github_release_enabled=False,
            play_internal_enabled=False,
        )
        options.update(overrides)
        return validate_release(self.repo, **options)

    def test_disabled_review_build_is_valid(self):
        result = self.valid()
        self.assertEqual((result.version_name, result.version_code), ("2.0.12", 84))
        self.assertFalse(result.sign_artifacts)

    def test_signing_requires_repository_opt_in(self):
        with self.assertRaisesRegex(ValidationError, "RELEASE_SIGNING_ENABLED"):
            self.valid(sign_artifacts=True, release_signing_enabled=False)

    def test_github_requires_signing_and_repository_opt_in(self):
        with self.assertRaisesRegex(ValidationError, "GITHUB_RELEASE_ENABLED"):
            self.valid(publish_github=True, sign_artifacts=True, release_signing_enabled=True)
        with self.assertRaisesRegex(ValidationError, "publish_github=true requires sign_artifacts"):
            self.valid(publish_github=True, github_release_enabled=True)

    def test_play_is_blocked_by_target_sdk_and_license(self):
        with self.assertRaisesRegex(ValidationError, "targetSdk>=36"):
            self.valid(upload_play_internal=True, sign_artifacts=True, release_signing_enabled=True, play_internal_enabled=True)

    def test_play_success_path_checks_license_and_target_sdk(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            write_repo(base, target_sdk=36, license=True)
            decision = validate_release(
                base,
                tag_ref="refs/tags/v2.0.12",
                sign_artifacts=True,
                publish_github=False,
                upload_play_internal=True,
                release_signing_enabled=True,
                github_release_enabled=False,
                play_internal_enabled=True,
            )
            self.assertTrue(decision.upload_play_internal)

    def test_tag_must_match_committed_version(self):
        with self.assertRaisesRegex(ValidationError, "does not match"):
            self.valid(tag_ref="refs/tags/v2.0.13")

    def test_tag_pattern_rejects_prerelease_branch_and_build_metadata(self):
        for tag in ("refs/tags/v2.0.12-rc.1", "refs/heads/v2.0.12", "refs/tags/v2.0.12+84"):
            with self.assertRaises(ValidationError):
                self.valid(tag_ref=tag)

    def test_changelog_limit_and_missing_numeric_file(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            write_repo(base, changelog="x" * 501)
            with self.assertRaisesRegex(ValidationError, "at most 500"):
                validate_release(base, tag_ref="refs/tags/v2.0.12", sign_artifacts="false", publish_github="false", upload_play_internal="false", release_signing_enabled="false", github_release_enabled="false", play_internal_enabled="false")
            write_repo(base, version_code=85)
            (base / "fastlane/metadata/android/en-US/changelogs/85.txt").unlink()
            with self.assertRaisesRegex(ValidationError, "missing numeric Play changelog"):
                validate_release(base, tag_ref="refs/tags/v2.0.12", sign_artifacts="false", publish_github="false", upload_play_internal="false", release_signing_enabled="false", github_release_enabled="false", play_internal_enabled="false")

    def test_gate_boolean_must_be_explicit(self):
        for value in ("yes", "1", ""):
            with self.assertRaises(ValidationError):
                parse_explicit_bool(value, "input")


class FdroidDraftTests(unittest.TestCase):
    def test_draft_is_blocked_without_license(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            metadata = base / "fdroid" / "metadata"
            metadata.mkdir(parents=True)
            (metadata / "de.schuelken.studyhabit.yml").write_text("Disabled: true\nLicense: Unknown\nAutoUpdateMode: None\nUpdateCheckMode: None\n")
            result = fdroid_readiness(base)
        self.assertFalse(result["ready_for_submission"])
        self.assertIn("owner-selected LICENSE is absent", result["blocked_reasons"])
        self.assertEqual(result["AutoUpdateMode"], "None")
        self.assertEqual(result["UpdateCheckMode"], "None")

    def test_licensed_real_recipe_is_still_placeholder_blocked(self):
        result = fdroid_readiness(REPO)
        self.assertFalse(result["ready_for_submission"])
        self.assertTrue(result["license_ready"])
        self.assertIn("build commit is still a placeholder", result["blocked_reasons"])

    def test_enabled_draft_is_not_submission_ready(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            metadata = base / "fdroid" / "metadata"
            metadata.mkdir(parents=True)
            (metadata / "de.schuelken.studyhabit.yml").write_text("Disabled: false\nLicense: Unknown\nAutoUpdateMode: None\nUpdateCheckMode: None\n")
            result = fdroid_readiness(base)
            self.assertFalse(result["ready_for_submission"])
            self.assertIn("draft metadata is not disabled", result["blocked_reasons"])


if __name__ == "__main__":
    unittest.main()
