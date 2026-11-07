#!/usr/bin/env python3
"""GitHub Android channel policy and publication; never changes source versions."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

EPOCH = 1_000_000
MAX_CODE = 2_100_000_000


def run(*args: str) -> str:
    return subprocess.check_output(args, text=True).strip()


def decide(event: str, ref: str, publish: bool, count: int, source_code: int,
           source_name: str, sha: str) -> dict[str, str]:
    if count < 1 or not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise ValueError("A full-history commit and full SHA are required")
    if not re.fullmatch(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)", source_name) or not 0 < source_code <= MAX_CODE:
        raise ValueError("Source defaults must contain a numeric X.Y.Z and valid Android code")
    stable = ref.startswith("refs/tags/")
    if event not in {"push", "workflow_dispatch"}:
        raise ValueError("Signing only supports push and workflow_dispatch")
    if stable:
        if not re.fullmatch(r"v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)", ref[10:]):
            raise ValueError("Stable tag must be vX.Y.Z")
        if ref != f"refs/tags/v{source_name}":
            raise ValueError("Tag and source versionName differ")
    elif ref != "refs/heads/master":
        raise ValueError("Signing only supports master and stable tags")
    code = EPOCH + count * 2 + int(stable)
    if code > MAX_CODE:
        raise ValueError("Android versionCode limit exceeded")
    if stable and source_code != code:
        raise ValueError(f"Stable source versionCode must equal {code}; account for release commit")
    name = source_name if stable else f"{source_name}-beta.{sha[:12]}"
    return {"channel": "stable" if stable else "development", "version_code": str(code),
            "version_name": name, "tag": ref[10:] if stable else "development",
            "publish": str(event == "push" or publish).lower(), "sha": sha}


def prepare() -> None:
    text = Path("android/app/build.gradle.kts").read_text()
    code = int(re.search(r"^\s*versionCode\s*=\s*(\d+)\s*$", text, re.M)[1])
    name = re.search(r'^\s*versionName\s*=\s*"([^"]+)"\s*$', text, re.M)[1]
    sha = run("git", "rev-parse", "HEAD")
    if sha != os.environ["GITHUB_SHA"]:
        raise ValueError("Checkout is not the triggering SHA")
    if run("git", "rev-parse", "--is-shallow-repository") != "false":
        raise ValueError("Full git history is required")
    decision = decide(os.environ["GITHUB_EVENT_NAME"], os.environ["GITHUB_REF"],
                      os.environ.get("MANUAL_PUBLISH", "false") == "true",
                      int(run("git", "rev-list", "--count", "HEAD")), code, name, sha)
    if decision["channel"] == "stable":
        subprocess.run(["git", "merge-base", "--is-ancestor", sha, "origin/master"], check=True)
        notes = Path(f"docs/releases/{name}.md")
        if not notes.is_file() or not notes.read_text().strip():
            raise ValueError("Stable release notes are required")
        releases = api("GET", "releases?per_page=100")
        for release in releases:
            if release["draft"] or release["prerelease"] or release["tag_name"] == decision["tag"]:
                continue
            match = re.search(r"Version code: (\d+)", release.get("body") or "")
            if match and int(match[1]) >= int(decision["version_code"]):
                raise ValueError("Stable versionCode must exceed previous stable releases")
    decision["build_id"] = f"{os.environ['GITHUB_RUN_ID']}-{os.environ['GITHUB_RUN_ATTEMPT']}"
    Path("release-decision.json").write_text(json.dumps(decision))
    with open(os.environ["GITHUB_OUTPUT"], "a") as output:
        for key, value in decision.items():
            output.write(f"{key}={value}\n")


def configure_signing() -> None:
    import base64
    import stat
    required = ["KEYSTORE_BASE64", "KEYSTORE_PASSWORD", "KEY_ALIAS", "KEY_PASSWORD"]
    if any(not os.environ.get(key) for key in required):
        raise ValueError("All four signing secrets must be configured")
    os.umask(0o077)
    keystore = Path(os.environ["RUNNER_TEMP"]) / "studyhabit-release.keystore"
    keystore.write_bytes(base64.b64decode("".join(os.environ["KEYSTORE_BASE64"].split()), validate=True))
    keystore.chmod(stat.S_IRUSR | stat.S_IWUSR)
    # Java Properties.load(InputStream) expects ISO-8859-1 with Unicode escapes.
    def escape(value: str) -> str:
        return "".join("\\u%04x" % ord(c) for c in value)
    values = {"storeFile": str(keystore), "storePassword": os.environ["KEYSTORE_PASSWORD"],
              "keyAlias": os.environ["KEY_ALIAS"], "keyPassword": os.environ["KEY_PASSWORD"],
              "storeType": "pkcs12"}
    Path("android/app/key.properties").write_text("".join(f"{k}={escape(v)}\n" for k, v in values.items()))


def verify_binaries(apks: list[Path], aabs: list[Path], d: dict) -> None:
    expected = os.environ["RELEASE_CERT_SHA256"].lower()
    if not re.fullmatch(r"[0-9a-f]{64}", expected):
        raise ValueError("RELEASE_CERT_SHA256 must be the trusted existing public fingerprint")
    sdk = Path(os.environ["ANDROID_HOME"])
    signer = sorted(sdk.glob("build-tools/*/apksigner"), key=lambda p: tuple(int(x) for x in p.parent.name.split(".") if x.isdigit()))[-1]
    if len(apks) != 1 or len(aabs) != 1:
        raise ValueError("Expected exactly one release APK and AAB")
    result = run(str(signer), "verify", "--print-certs", str(apks[0]))
    fingerprints = set(re.findall(r"certificate SHA-256 digest: ([0-9a-fA-F]+)", result))
    if fingerprints != {expected}:
        raise ValueError("APK signing identity differs from trusted certificate")
    badging = run(str(signer.parent / "aapt"), "dump", "badging", str(apks[0])).splitlines()[0]
    for value in ["name='de.schuelken.studyhabit'", f"versionCode='{d['version_code']}'", f"versionName='{d['version_name']}'"]:
        if value not in badging:
            raise ValueError("Unexpected APK package/version metadata")
    if "jar verified." not in run("jarsigner", "-verify", str(aabs[0])):
        raise ValueError("AAB JAR signature verification failed")
    cert = run("keytool", "-printcert", "-jarfile", str(aabs[0]))
    fingerprints = {v.replace(":", "").lower() for v in re.findall(r"SHA256:\s*([0-9A-Fa-f:]+)", cert)}
    if fingerprints != {expected}:
        raise ValueError("AAB signing identity differs from trusted certificate")
    import xml.etree.ElementTree as ET
    manifest_xml = run("java", "-jar", os.environ["BUNDLETOOL_JAR"], "dump", "manifest", f"--bundle={aabs[0]}", "--module=base")
    manifest_root = ET.fromstring(manifest_xml)
    ns = "{http://schemas.android.com/apk/res/android}"
    if (manifest_root.get("package"), manifest_root.get(ns + "versionCode"), manifest_root.get(ns + "versionName")) != ("de.schuelken.studyhabit", d["version_code"], d["version_name"]):
        raise ValueError("Unexpected AAB package/version metadata")


def stage() -> None:
    import shutil
    d = json.loads(Path("release-decision.json").read_text())
    apks = list(Path("android/app/build/outputs/apk/release").glob("*.apk"))
    aabs = list(Path("android/app/build/outputs/bundle/release").glob("*.aab"))
    verify_binaries(apks, aabs, d)
    build_suffix = "" if d["channel"] == "stable" else "-" + d["build_id"]
    target = Path("release-assets")
    if target.exists():
        shutil.rmtree(target)
    target.mkdir()
    for source in apks + aabs:
        shutil.copyfile(source, target / f"StudyHabit-{d['version_name']}-{d['sha']}{build_suffix}{source.suffix}")
    manifest = "SHA256SUMS" if d["channel"] == "stable" else f"SHA256SUMS-{d['sha']}{build_suffix}.txt"
    (target / manifest).write_text("".join(f"{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n" for p in sorted(target.iterdir())))


def api(method: str, endpoint: str, data: dict | None = None):
    args = ["gh", "api", "--method", method, f"repos/{os.environ['GITHUB_REPOSITORY']}/{endpoint}"]
    if data is not None:
        args += ["--input", "-"]
    if method == "GET" and endpoint.startswith("releases?"):
        args += ["--paginate", "--slurp"]
    output = subprocess.check_output(args, input=json.dumps(data) if data is not None else None, text=True)
    parsed = json.loads(output) if output.strip() else None
    if method == "GET" and endpoint.startswith("releases?"):
        return [release for page in parsed for release in page]
    return parsed


def publish() -> None:
    d = json.loads(Path("release-decision.json").read_text())
    if d["publish"] != "true":
        return
    stable = d["channel"] == "stable"
    if stable and api("GET", f"commits/{d['tag']}")["sha"] != d["sha"]:
        raise ValueError("Stable tag moved from the selected source commit")
    if not stable and api("GET", "branches/master")["commit"]["sha"] != d["sha"]:
        print("Newer master exists; keeping the newer development channel")
        return
    releases = api("GET", "releases?per_page=100")
    matches = [r for r in releases if r["tag_name"] == d["tag"]]
    if len(matches) > 1:
        raise ValueError("Multiple releases use the selected tag")
    release = matches[0] if matches else None
    assets = sorted(Path("release-assets").iterdir())
    expected_names = {p.name for p in assets}
    body = (Path(f"docs/releases/{d['version_name']}.md").read_text() if stable else
            "Automatic verified master build. This prerelease and its development tag move with master.\n")
    body += f"\n\nCommit: {d['sha']}\nVersion: {d['version_name']}\nVersion code: {d['version_code']}\n"
    if release and not release["draft"] and not stable and not release["prerelease"]:
        raise ValueError("Refusing to mutate a non-prerelease development entry")
    if release and stable and not release["draft"]:
        verify_published_release(release["id"], d, expected_names)
        print("Existing stable release verified; no assets changed")
        return
    if not release:
        release = api("POST", "releases", {"tag_name": d["tag"], "target_commitish": d["sha"], "name": "Development build — automatic" if not stable else f"StudyHabit {d['version_name']}", "body": body, "draft": True, "prerelease": not stable})
    release_id = release["id"]
    # Upload by retained release ID; draft lookup by tag is not reliable.
    upload_url = release["upload_url"].split("{")[0]
    current = api("GET", f"releases/{release_id}")
    if not stable and not current["draft"] and not current["prerelease"]:
        raise ValueError("Refusing to mutate a non-prerelease development entry")
    for p in assets:
        existing = next((a for a in current["assets"] if a["name"] == p.name), None)
        if existing:
            if not current["draft"]:
                raise ValueError("Build-specific rolling asset already exists; retry with a new run attempt")
            api("DELETE", f"releases/assets/{existing['id']}")
        subprocess.run(["gh", "api", "--method", "POST", f"{upload_url}?name={p.name}", "-H", "Content-Type: application/octet-stream", "--input", str(p)], check=True, stdout=subprocess.DEVNULL)
    current = api("GET", f"releases/{release_id}")
    by_name = {a["name"]: a for a in current["assets"]}
    if not expected_names.issubset(by_name) or any(by_name[p.name]["size"] != p.stat().st_size for p in assets):
        raise ValueError("Uploaded inventory is incomplete")
    verify_downloads([by_name[name] for name in expected_names], assets)
    if not stable:
        for asset in current["assets"]:
            if asset["name"] not in expected_names:
                api("DELETE", f"releases/assets/{asset['id']}")
    elif set(by_name) != expected_names:
        raise ValueError("Stable draft contains unexpected assets")
    api("PATCH", f"releases/{release_id}", {"body": body, "draft": False, "prerelease": not stable, "make_latest": "true" if stable else "false"})
    if not stable:
        refs = api("GET", "git/matching-refs/tags/development")
        if any(r["ref"] == "refs/tags/development" for r in refs):
            api("PATCH", "git/refs/tags/development", {"sha": d["sha"], "force": True})
        else:
            api("POST", "git/refs", {"ref": "refs/tags/development", "sha": d["sha"]})
    verify_published_release(release_id, d, expected_names, assets)


def verify_published_release(release_id: int, d: dict, expected_names: set[str],
                             local_assets: list[Path] | None = None) -> None:
    """Re-read final REST state and verify published bytes and channel semantics."""
    current = api("GET", f"releases/{release_id}")
    stable = d["channel"] == "stable"
    if current["id"] != release_id or current["tag_name"] != d["tag"]:
        raise ValueError("Published release identity differs")
    if current["draft"] or current["prerelease"] != (not stable):
        raise ValueError("Published release flags differ from selected channel")
    if f"Commit: {d['sha']}" not in (current.get("body") or ""):
        raise ValueError("Published source provenance differs")
    if api("GET", f"commits/{d['tag']}")["sha"] != d["sha"]:
        raise ValueError("Published source tag moved from selected SHA")
    if {a["name"] for a in current["assets"]} != expected_names or len(current["assets"]) != len(expected_names):
        raise ValueError("Published asset inventory differs")
    if stable and api("GET", "releases/latest")["id"] != release_id:
        raise ValueError("Stable release is not GitHub Latest")
    if local_assets is not None:
        verify_downloads(current["assets"], local_assets)
    else:
        # Original stable binaries may contain timestamps differing from this rebuild.
        import tempfile
        with tempfile.TemporaryDirectory() as download:
            downloaded = Path(download)
            for asset in current["assets"]:
                with (downloaded / asset["name"]).open("wb") as output:
                    subprocess.run(["gh", "api", f"repos/{os.environ['GITHUB_REPOSITORY']}/releases/assets/{asset['id']}", "-H", "Accept: application/octet-stream"], stdout=output, check=True)
            verify_manifest(downloaded, "SHA256SUMS", expected_names)
            verify_binaries(list(downloaded.glob("*.apk")), list(downloaded.glob("*.aab")), d)


def verify_manifest(directory: Path, manifest_name: str, expected_names: set[str]) -> None:
    listed = set()
    for line in (directory / manifest_name).read_text().splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  ([A-Za-z0-9_.-]+)", line)
        if not match or match[2] in listed or match[2] == manifest_name:
            raise ValueError("Invalid checksum manifest")
        listed.add(match[2])
        if hashlib.sha256((directory / match[2]).read_bytes()).hexdigest() != match[1]:
            raise ValueError("Published checksum mismatch")
    if listed | {manifest_name} != expected_names:
        raise ValueError("Checksum inventory differs")


def verify_downloads(remote_assets: list[dict], local_assets: list[Path]) -> None:
    """Verify uploaded bytes by retained asset IDs, including private draft assets."""
    import tempfile
    remote = {a["name"]: a for a in remote_assets}
    with tempfile.TemporaryDirectory() as directory:
        for local in local_assets:
            destination = Path(directory) / local.name
            with destination.open("wb") as output:
                subprocess.run(["gh", "api", f"repos/{os.environ['GITHUB_REPOSITORY']}/releases/assets/{remote[local.name]['id']}", "-H", "Accept: application/octet-stream"], stdout=output, check=True)
            if hashlib.sha256(destination.read_bytes()).digest() != hashlib.sha256(local.read_bytes()).digest():
                raise ValueError("Published artifact/checksum bytes do not match verified build")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["prepare", "configure-signing", "stage", "publish"])
    args = parser.parse_args()
    {"prepare": prepare, "configure-signing": configure_signing, "stage": stage, "publish": publish}[args.command]()
