#!/usr/bin/env python3
"""Strict validators for StudyHabit's manual Android release workflow.

The validators intentionally fail closed: an unrecognized boolean, missing metadata,
or a requested destination without an explicit repository opt-in is an error.
"""
from __future__ import annotations

import argparse
import json
import sys
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

TAG_REF_RE = re.compile(r"^refs/tags/v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d+)$")
VERSION_CODE_RE = re.compile(r"^\s*versionCode\s*=\s*(\d+)\s*$", re.MULTILINE)
VERSION_NAME_RE = re.compile(r'^\s*versionName\s*=\s*"([^"]+)"\s*$', re.MULTILINE)
TARGET_SDK_RE = re.compile(r"^\s*targetSdk\s*=\s*(\d+)\s*$", re.MULTILINE)
MAX_CHANGELOG_CHARS = 500


class ValidationError(ValueError):
    """A release must not proceed."""


@dataclass(frozen=True)
class AndroidVersion:
    version_code: int
    version_name: str
    target_sdk: int


@dataclass(frozen=True)
class ReleaseDecision:
    tag: str
    version_name: str
    version_code: int
    changelog_path: str
    changelog_chars: int
    sign_artifacts: bool
    publish_github: bool
    upload_play_internal: bool


def parse_explicit_bool(value: str, label: str) -> bool:
    normalized = value.strip().lower() if isinstance(value, str) else value
    if normalized is True:
        return True
    if normalized is False:
        return False
    if normalized == "true":
        return True
    if normalized == "false":
        return False
    raise ValidationError(f"{label} must be exactly 'true' or 'false' (got an unrecognized value)")


def read_android_version(repo_root: Path) -> AndroidVersion:
    gradle = repo_root / "android" / "app" / "build.gradle.kts"
    try:
        content = gradle.read_text(encoding="utf-8")
    except OSError as exc:
        raise ValidationError(f"cannot read {gradle}: {exc}") from exc
    code_match = VERSION_CODE_RE.search(content)
    name_match = VERSION_NAME_RE.search(content)
    sdk_match = TARGET_SDK_RE.search(content)
    if not code_match or not name_match or not sdk_match:
        raise ValidationError("android/app/build.gradle.kts must define versionCode, versionName, and targetSdk")
    version_code = int(code_match.group(1))
    if version_code < 1:
        raise ValidationError("versionCode must be a positive integer")
    version_name = name_match.group(1)
    if not re.fullmatch(r"\d+\.\d+\.\d+", version_name):
        raise ValidationError(f"versionName must be numeric X.Y.Z, got {version_name!r}")
    return AndroidVersion(version_code, version_name, int(sdk_match.group(1)))


def validate_release(
    repo_root: Path | str,
    *,
    tag_ref: str,
    sign_artifacts: str | bool,
    publish_github: str | bool,
    upload_play_internal: str | bool,
    release_signing_enabled: str | bool,
    github_release_enabled: str | bool,
    play_internal_enabled: str | bool,
) -> ReleaseDecision:
    root = Path(repo_root).resolve()
    if not TAG_REF_RE.fullmatch(tag_ref):
        raise ValidationError("release must run from refs/tags/vX.Y.Z with numeric components only")

    requested_sign = parse_explicit_bool(sign_artifacts, "sign_artifacts")
    requested_github = parse_explicit_bool(publish_github, "publish_github")
    requested_play = parse_explicit_bool(upload_play_internal, "upload_play_internal")
    enabled_sign = parse_explicit_bool(release_signing_enabled, "RELEASE_SIGNING_ENABLED")
    enabled_github = parse_explicit_bool(github_release_enabled, "GITHUB_RELEASE_ENABLED")
    enabled_play = parse_explicit_bool(play_internal_enabled, "PLAY_INTERNAL_ENABLED")

    android = read_android_version(root)
    expected_tag = f"v{android.version_name}"
    tag_name = tag_ref.removeprefix("refs/tags/")
    if tag_name != expected_tag:
        raise ValidationError(
            f"tag {tag_name} does not match committed Android versionName {android.version_name}"
        )

    changelog = root / "fastlane" / "metadata" / "android" / "en-US" / "changelogs" / f"{android.version_code}.txt"
    if not changelog.is_file():
        raise ValidationError(f"missing numeric Play changelog: {changelog.relative_to(root)}")
    changelog_text = changelog.read_text(encoding="utf-8")
    changelog_chars = len(changelog_text)
    if not changelog_text.strip():
        raise ValidationError(f"changelog {changelog.name} is empty")
    if changelog_chars > MAX_CHANGELOG_CHARS:
        raise ValidationError(
            f"changelog is {changelog_chars} characters; Play permits at most {MAX_CHANGELOG_CHARS}"
        )

    failures: list[str] = []
    if requested_sign and not enabled_sign:
        failures.append("sign_artifacts=true requires RELEASE_SIGNING_ENABLED=true")
    if requested_github and not enabled_github:
        failures.append("publish_github=true requires GITHUB_RELEASE_ENABLED=true")
    if requested_play and not enabled_play:
        failures.append("upload_play_internal=true requires PLAY_INTERNAL_ENABLED=true")
    if requested_github and not requested_sign:
        failures.append("publish_github=true requires sign_artifacts=true")
    if requested_play and not requested_sign:
        failures.append("upload_play_internal=true requires sign_artifacts=true")
    if requested_play:
        if android.target_sdk < 36:
            failures.append(
                f"Play internal upload is blocked until targetSdk>=36 (current targetSdk={android.target_sdk})"
            )
        if not (root / "LICENSE").is_file():
            failures.append("Play internal upload is blocked until the repository has an owner-selected LICENSE")
    if failures:
        raise ValidationError("; ".join(failures))

    return ReleaseDecision(
        tag=tag_name,
        version_name=android.version_name,
        version_code=android.version_code,
        changelog_path=str(changelog.relative_to(root)),
        changelog_chars=changelog_chars,
        sign_artifacts=requested_sign,
        publish_github=requested_github,
        upload_play_internal=requested_play,
    )


def fdroid_readiness(repo_root: Path | str) -> dict[str, object]:
    root = Path(repo_root).resolve()
    metadata = root / "fdroid" / "metadata" / "de.schuelken.studyhabit.yml"
    if not metadata.is_file():
        raise ValidationError("fdroid metadata draft is missing")
    content = metadata.read_text(encoding="utf-8")
    settings = {
        "Disabled": _yaml_scalar(content, "Disabled"),
        "License": _yaml_scalar(content, "License"),
        "AutoUpdateMode": _yaml_scalar(content, "AutoUpdateMode"),
        "UpdateCheckMode": _yaml_scalar(content, "UpdateCheckMode"),
    }
    missing = [key for key, value in settings.items() if value is None]
    if missing:
        raise ValidationError(f"fdroid metadata is missing required fields: {', '.join(missing)}")
    license_ready = (root / "LICENSE").is_file()
    blocked_reasons: list[str] = []
    if not license_ready:
        blocked_reasons.append("owner-selected LICENSE is absent")
    if str(settings["License"]).lower() == "unknown":
        blocked_reasons.append("License is Unknown pending owner selection")
    if settings["Disabled"] is not True:
        blocked_reasons.append("draft metadata is not disabled")
    else:
        blocked_reasons.append("draft remains disabled pending F-Droid review")
    if settings["AutoUpdateMode"] != "None":
        blocked_reasons.append("AutoUpdateMode must remain None before acceptance")
    if settings["UpdateCheckMode"] != "None":
        blocked_reasons.append("UpdateCheckMode must remain None before acceptance")
    if "REPLACE_WITH_ACCEPTED_IMMUTABLE_RELEASE_TAG_COMMIT" in content:
        blocked_reasons.append("build commit is still a placeholder")
    return {
        "ready_for_submission": not blocked_reasons,
        "blocked_reasons": blocked_reasons,
        "license_ready": license_ready,
        **settings,
    }


def _yaml_scalar(content: str, key: str) -> object | None:
    match = re.search(rf"(?m)^{re.escape(key)}:\s*(.*?)\s*$", content)
    if not match:
        return None
    raw = match.group(1)
    if key == "Disabled" and raw in {">", ">-", "|", "|-"}:
        # F-Droid accepts a nonempty explanation as its Disabled value.
        remainder = content[match.end():]
        return bool(re.search(r"\n[ \t]+\S", remainder))
    if raw in {"true", "True"}:
        return True
    if raw in {"false", "False"}:
        return False
    if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in "'\"":
        return raw[1:-1]
    return raw


def _comma(items: Iterable[str]) -> str:
    return ",".join(items)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    release = sub.add_parser("release", help="validate tag, committed version, metadata, and opt-in gates")
    release.add_argument("--repo-root", type=Path, default=Path.cwd())
    release.add_argument("--tag-ref", required=True)
    release.add_argument("--sign-artifacts", required=True)
    release.add_argument("--publish-github", required=True)
    release.add_argument("--upload-play-internal", required=True)
    release.add_argument("--release-signing-enabled", required=True)
    release.add_argument("--github-release-enabled", required=True)
    release.add_argument("--play-internal-enabled", required=True)

    fdroid = sub.add_parser("fdroid-readiness", help="check that the disabled draft cannot be submitted accidentally")
    fdroid.add_argument("--repo-root", type=Path, default=Path.cwd())
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        result = (
            fdroid_readiness(args.repo_root)
            if args.command == "fdroid-readiness"
            else validate_release(
                args.repo_root,
                tag_ref=args.tag_ref,
                sign_artifacts=args.sign_artifacts,
                publish_github=args.publish_github,
                upload_play_internal=args.upload_play_internal,
                release_signing_enabled=args.release_signing_enabled,
                github_release_enabled=args.github_release_enabled,
                play_internal_enabled=args.play_internal_enabled,
            )
        )
    except ValidationError as exc:
        print(f"release validation failed: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(asdict(result) if isinstance(result, ReleaseDecision) else result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
