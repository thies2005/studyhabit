<h1 align="center">Android release channels</h1>

<p align="center"><strong>Project reference</strong><br>Setup, usage, and maintenance guidance.</p>

<p align="center">
  <a href="../../README.md">Project overview</a>
</p>

StudyHabit is licensed under **GPL-3.0-or-later** (SPDX identifier); see the
root `LICENSE` for the GPLv3 terms. This declaration permits GPL version 3 or
any later version. Existing third-party notices and licenses still apply.

Every push to `master` runs checks and produces a signed APK and AAB. Verified
builds update the same `development` prerelease, which is never GitHub Latest.
Its tag moves only after the complete replacement upload succeeds; source SHA
and build-specific artifact/checksum names identify the exact build. Names include
run ID and attempt so a timestamped rebuild cannot replace a valid download. Other
branches and pull requests get checks and unsigned APK artifacts, without
release credentials. No workflow commits automatic version bumps.

`android-release.yml` manual runs default to `publish=false`: build, sign,
verify and retain artifacts, without changing releases or tags. Publishing a
manual development run requires `master` and `publish=true`.

## Signing setup

Retain the existing repository secrets `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`,
`KEY_ALIAS`, and `KEY_PASSWORD`. They must represent the existing dedicated
StudyHabit release key. Set repository variable `RELEASE_CERT_SHA256` to
`9a7fcb28be088517c43d49e060fda6701f517a2bdccc65d0ecf907e280b45f30`.
The workflow refuses missing secrets, unsigned artifacts, or a different
certificate. Temporary signing files are removed even after failure. The
default local/source release build remains unsigned; signed builds explicitly
use `-Pstudyhabit.release.signing.enabled=true` with `android/app/key.properties`.
Keep an offline keystore/password backup: GitHub secrets cannot be downloaded.

## Stable release instruction for agents

Only create/push a stable tag after the user explicitly asks for a stable
release. This setup task does not authorize a stable release. Work from the
latest remote `master` in an isolated worktree when the local checkout has
unrelated edits or lags behind remote; this checkout initially lagged the
published 2.0.13 build. Never reset or overwrite another checkout's work.

1. Fetch full history and tags. Choose an unused numeric version `X.Y.Z`,
   update the literal `versionName`, and write curated `docs/releases/X.Y.Z.md`.
2. Version allocation has fixed epoch 1,000,000. At the final release commit,
   development uses `1000000 + 2 * git rev-list --count HEAD`; stable uses that
   value plus 1. Set the literal `versionCode` to the stable value, including
   the release preparation commit in the count. With one new commit on current
   HEAD, set it to `1000000 + 2 * (current_count + 1) + 1`. Recalculate after
   any additional commit or merge. Keep source literal declarations intact.
3. Run Android tests/lint and applicable backend/web checks; commit only the
   intended release work. Push the commit and wait for its development build.
4. Recheck actual commit count, source code, notes and ancestry to remote
   `master`. Tag exactly that commit `vX.Y.Z`, then push only that tag.
5. Monitor Actions, verify the published downloads/checksums, source SHA,
   certificate and inventory, and confirm stable is Latest.

Never rewrite `master` history or move a stable tag. Codes must stay within
Android's 2,100,000,000 limit. The epoch migrates above legacy codes; once
adopted it is permanent. Stable is newer than development at the same commit;
a subsequent development build is newer again, so testers may need to wait for
a later stable build before switching channels. Published stable assets are
never overwritten; reruns verify their original checksums, metadata and signatures. A failed
draft is reused by release ID. Development updates share one serialized queue,
skip stale master commits, upload the complete set, then remove old assets.

## Obtainium, F-Droid and Google Play

Add `https://github.com/thies2005/studyhabit` to Obtainium. Keep prereleases
disabled for stable releases, or enable them and select the `development` tag
for automatic builds; filter assets to `\.apk$`. Obtainium installs APKs,
not the AAB. Android certificate and version-code compatibility still applies.

For rolling development updates, turn on **Release Date as Version** and **Use Latest Asset Date as Release Date**, and turn off **Verify Latest Tag**. The `development` tag stays constant, so tracking its name alone will miss replacement builds. Keep the tag filter at `^development$` and the APK filter at `\.apk$`. Before the first new stable release, use this development configuration. See the [Obtainium source options](https://wiki.obtainium.imranr.dev/sources/) and [version tracking](https://wiki.obtainium.imranr.dev/app_tracking/).

The existing `fdroid/metadata/de.schuelken.studyhabit.yml` remains a **disabled
draft** with GPL-3.0-or-later declared. Before submission, replace its placeholder
commit with the verified immutable stable commit, update versionName/versionCode,
audit all Android dependencies, and test the source build with F-Droid tools.
The unsigned Gradle default is intentional for F-Droid. The metadata recipe
uses `subdir: android`, removes unrelated backend/web code, and does not claim
reproducibility. Main F-Droid normally signs its own builds; using the developer
signature requires verified reproducible builds and an accepted binary recipe.
Do not submit the disabled draft or promise cross-store update compatibility.

The existing `scripts/release_validation.py` and `fastlane/metadata` are preserved
for their separate manual signing/Play opt-in interface; the channel workflow
uses `scripts/android_release.py` and does not enable those upload flags.
Its Play-specific target-SDK/license checks still apply to that future path.

The signed AAB prepares future Play uploads; this workflow never uploads to
Play. Configure Play Console, current target-SDK compliance, privacy/data-safety
forms, store assets and testing requirements separately. For the same app to
update across GitHub and Play, enroll the existing app signing key with Play
App Signing, then use a separate upload key as appropriate. Letting Play create
a different app signing key changes cross-store update compatibility.
