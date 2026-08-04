# dotto++ 1.1.1 Release Plan

## Context

- The requested Settings label change is: replace **“Perceptual Pastel Colours”** with **“Alt. Pastel Algorithm”**. The parent **“Use Pastel Colours”** continues to use dotto+ 1.0.6’s original HSV brightness algorithm; the conditional alternate switch continues to select the OKLab/OKLCH implementation.
- The comparison baseline is tag `v1.1.0` (`f21742f`). The current candidate is `development` at `0336c6f`; `main` must remain at `5414d10` until every release gate passes.
- `v1.1.0` and `development` have unrelated Git histories even though their trees share an earlier conceptual codebase. GitHub’s compare API reports no common ancestor. A normal merge is therefore unsafe and the generated `--first-parent` release notes cannot describe 1.1.1 adequately.
- The source/runtime is materially safer than 1.1.0: complete badge state restoration, a dedicated SnowBoard-safe overlay, a live master toggle, guarded KVC/main-thread updates, width-aware geometry, direct layer normalization, bounded badge discovery/reapply, badged-app folder colours, corrected colour extraction, and hardened package verification.
- No timer, polling loop, file logger, continuous trace, or unconditional runtime log was found. The only runtime logging is the `DPP_BADGE_TRACE` block in `Tweak.x`, enabled for non-`FINALPACKAGE` builds by `Makefile`; release builds compile it out. Since the geometry investigation is complete, remove this development-only instrumentation before promotion rather than carrying experimental logging into the release source.
- `kFaithfulPastelColor` and its inverse migration are development-only experiments introduced after 1.1.0. Stable 1.1.0 users never had this key. Remove that migration and retain only `kPerceptualPastelColor`, defaulting to `NO`, so stable upgrades have simple semantics.
- Current `../docs/AUDIT.md` attests commit `4b4f50f`, not the pastel/UI changes through `0336c6f`. Current-device validation and release-artifact hashes must be refreshed for the final candidate.
- Release-process findings that block promotion:
  1. stable-feed verification can false-pass by matching stale version and architecture lines from different package stanzas;
  2. GitHub Release creation currently runs independently of production-gated stable-feed publication;
  3. release notes rely on commit history that cannot produce a useful 1.1.0 → 1.1.1 summary;
  4. development publication duplicates version `1.1.1` in workflow/script constants;
  5. `development` cannot be merged normally into `main` because their histories are unrelated.
- Readiness verdict: **not ready today**, but no known runtime redesign is required. It becomes release-ready once the code cleanup, workflow hardening, current-device matrix, exact release build, audit refresh, and controlled main promotion below pass.

## Approach

1. Make the requested UI wording change without changing preference keys or runtime behavior.
2. Remove completed diagnostic/experimental code while preserving compatibility with stable 1.1.0 preferences and colour archives.
3. Harden package and publication checks so the exact two release artifacts—not stale feed entries—must pass.
4. Add a curated `../CHANGELOG.md` and make GitHub release notes consume the 1.1.1 section instead of relying on unrelated commit history.
5. Rebuild and test the exact final `development` commit on iOS 15 rootless and iOS 17 RootHide, including SnowBoard and preference transitions.
6. Promote the exact tested tree onto a new branch based on `main`, in a clean clone, then verify tree identity before updating `main`. Do not merge unrelated histories and do not touch `main` before explicit release approval.
7. Tag only the verified main-contained release commit, then require stable-feed and GitHub-release publication to complete as one gated sequence.

## Files

### User-visible behavior and cleanup

- `dottoPlusPlusPrefs/Resources/Root.plist`
  - Change only the conditional row label to `Alt. Pastel Algorithm`.
  - Keep key `kPerceptualPastelColor`, default `false`, subtitle `Use OKLab/OKLCH colour adjustment`, and existing Darwin notification.
- `dottoPlusPlusPrefs/Resources/en.lproj/Localizable.strings`
  - Replace the old perceptual label key/value with `"Alt. Pastel Algorithm" = "Alt. Pastel Algorithm";`.
  - Leave untranslated locales to display the English key rather than inventing unreviewed translations.
- `Tweak.x`
  - Keep the current faithful-default/alternate-OKLab selection.
  - Remove `DPP_BADGE_TRACE` storage, SnowBoard image scanning used only by tracing, `DottoPlusPlusTraceBadgeView`, every trace call, and trace-only imports.
- `Makefile`
  - Remove the conditional `-DDPP_BADGE_TRACE=1` flag.
- `libdottoplus/DottoPlusPlusPreferences.m`
  - Remove `DottoPlusPlusLegacyFaithfulPastelColorKey`, migration writes, and inverse fallback.
  - Keep `DottoPlusPlusPerceptualPastelColorKey` and return `NO` when absent.
- `libdottoplus/DottoPlusPlusPreferences.h`
  - Retain only the public perceptual preference constant/accessor used by current source.

### Release automation and verification

- `scripts/verify_package.sh`
  - Verify the tweak dylib, tweak filter plist, shared library, preference bundle binary, PreferenceLoader entry, badge art, and bundle Info.plist exist in the archive.
  - Add an `EXPECT_RELEASE=1` mode that rejects known trace strings/symbols and confirms the release package contains no runtime diagnostic markers.
- `.github/workflows/publish.yml`
  - Pass `EXPECT_RELEASE=1` to package verification.
  - Replace line-oriented stable-feed greps with stanza-aware checks for package, version, architecture, filename, and SHA-256 matching each downloaded artifact.
  - Verify the aggregate feed and each rootless/RootHide subfeed separately.
  - Make `create-github-release` depend on successful `publish-repository`, preserving the production approval gate and preventing GitHub “Latest” from appearing before the stable feed succeeds.
  - Generate the user-facing changes section from `../CHANGELOG.md` for the tagged version; fail if that section is absent or empty.
  - Verify both GitHub release asset hashes against the downloaded build artifacts.
- `.github/workflows/build.yml`
  - Remove hard-coded `EXPECTED_VERSION: 1.1.1` and hard-coded `Version: 1.1.1` feed verification.
  - Read the version from `control` in `publish-dev` and pass/use that value consistently.
- `scripts/publish_repo.sh`
  - Derive the expected version from repository `control` when not explicitly supplied; retain package/architecture uniqueness validation.

### Release documentation

- `../CHANGELOG.md` (new)
  - Add a curated 1.1.1 section and a concise 1.1.0 baseline entry.
- `../README.md`
  - Change the pastel option wording to **Alt. Pastel Algorithm**.
  - Remove the stale claim that a development debug build is the current release evidence; point to the final audit instead.
- `../docs/ANALYSIS.md`
  - Use the final user-facing alternate-option name while retaining the technical OKLab/OKLCH explanation.
- `../docs/AUDIT.md`
  - Replace obsolete commit/run/hash evidence with the exact final candidate, final CI release run, both artifact hashes, installed package hashes, device matrix, and accepted residual risks.
  - Record that runtime tracing was removed after its evidence was captured.
- Keep `PLAN.md`, `SNOWBOARD_PLAN.md`, and `LIVE_BADGE_TRANSITION_PLAN.md` as historical engineering records; they are not packaged and do not execute.
- Do not stage or modify unrelated `.pi-subagents/`, `IconDance/`, or `ICONDANCE_*.md` paths.

## Reuse

- Reuse `DottoPlusPlusPastelColorKey`, `DottoPlusPlusPerceptualPastelColorKey`, `pastelColorsEnabled`, and `perceptualPastelColorsEnabled`; do not add another preference key.
- Reuse `dpp_faithfulPastelColor` for the parent toggle and `dpp_oklabPastelColor` for the alternate toggle.
- Reuse `DottoPlusPlusRootListController`’s `pastelSpecifier`, `perceptualPastelSpecifier`, and `updatePerceptualPastelSpecifierVisibilityAnimated:` behavior; only the displayed label changes.
- Reuse `read_control_version` and existing archive extraction logic in `scripts/verify_package.sh`.
- Reuse the stanza-aware package validation pattern already implemented by `assert_packages_stanza` in `scripts/publish_repo.sh` when hardening stable publication.
- Reuse the pinned RootHide Theos commit and two-scheme matrix already present in both workflows.
- Reuse the current state restoration, overlay ownership, geometry, caching, and `DottoPlusPlusBadgeNeedsApply` fast paths; the release review found no reason to redesign them.

## Assumptions

- Release version remains `1.1.1`; `control` and both preference bundle version fields remain `1.1.1`.
- Supported firmware remains `>= 15.0` and `< 18.0`.
- “Alt. Pastel Algorithm” is the exact requested English label. Its internal key remains `kPerceptualPastelColor` because that accurately describes the behavior and avoids another preference migration.
- Parent pastel enabled + alternate disabled means exact dotto+ 1.0.6 HSV brightness behavior. Parent enabled + alternate enabled means OKLab/OKLCH behavior. Parent disabled means no pastel transform regardless of the stored alternate value.
- Development-only `kFaithfulPastelColor` does not require stable migration. Existing development testers may need to reselect the alternate mode once; this is preferable to shipping permanent inverse experimental semantics.
- RootHide testing is performed on `100.99.60.75`; rootless testing is performed on `192.168.1.156`. Install only the architecture matching each jailbreak.
- `main` remains at `5414d10` until all candidate checks pass and the maintainer explicitly approves promotion.
- The exact candidate tree, not local Linux packages with arm64e ABI warnings, is the release authority. Promotion and release artifacts use the pinned macOS CI toolchain.

## Steps

1. **Rename the alternate pastel row.** In `dottoPlusPlusPrefs/Resources/Root.plist`, change the `kPerceptualPastelColor` label from `Perceptual Pastel Colours` to `Alt. Pastel Algorithm`. Update the English localization and the README/analysis wording. Expected result: the conditional row has the requested name while its key, default, subtitle, visibility, and notification remain unchanged.

2. **Remove the development-only pastel migration.** In `DottoPlusPlusPreferences.m`, delete `DottoPlusPlusLegacyFaithfulPastelColorKey`, the migration block in `-reloadPreferences`, and the inverse fallback in `-perceptualPastelColorsEnabled`. Make the accessor return the stored `kPerceptualPastelColor` value or `NO` when absent. Expected result: stable 1.1.0 upgrades retain all real preferences and the alternate algorithm is opt-in with no experimental baggage.

3. **Remove completed badge tracing.** Delete all `DPP_BADGE_TRACE` branches, trace maps, SnowBoard-loaded scanning, trace calls, and trace-only imports from `Tweak.x`; delete its build flag from `Makefile`. Do not alter `DottoPlusPlusBadgeNeedsApply`, scheduling, geometry, overlay ownership, caching, or restoration behavior. Expected result: no runtime logging code remains in debug or release binaries and runtime behavior is unchanged.

4. **Strengthen archive verification.** Extend `scripts/verify_package.sh` to require all runtime/package members and, under `EXPECT_RELEASE=1`, extract the tweak/shared-library/bundle binaries and fail on known diagnostic strings such as `dotto++ badge phase=`, `next-runloop-before`, `next-runloop-after`, and `after-root-geometry`. Expected result: package omissions and accidental diagnostic reintroduction fail CI before upload.

5. **Eliminate duplicated development-version constants.** Read `control` once in the `publish-dev` job and use that value for `scripts/publish_repo.sh` and source-feed verification. Make `publish_repo.sh` derive the same value from `control` by default. Expected result: a future version bump has one authority and cannot silently publish/verify the wrong version.

6. **Make stable-feed verification artifact-specific.** In `publish.yml`, calculate each downloaded artifact’s package/version/architecture/filename/SHA-256, regenerate indexes, then parse complete `Packages` stanzas. Require exactly one matching 1.1.1 stanza for each candidate in the aggregate feed and the correct matching stanza in each subfeed; compare stanza SHA-256 values to the actual artifacts. Expected result: old packages cannot make a broken release false-pass.

7. **Make publication atomic.** Change `create-github-release.needs` from `build-release` to `publish-repository` (or include both if workflow syntax requires), then verify uploaded GitHub asset hashes and Latest tag after release creation. Expected result: production approval and successful stable-feed publication precede the public GitHub release.

8. **Create the curated changelog.** Add `../CHANGELOG.md` with this 1.1.1 user-facing content:

   - Added a live **Enabled** switch that restores native/SnowBoard badges without a respring.
   - Reworked SnowBoard compatibility around a dedicated dotto++ overlay and symmetric state restoration.
   - Fixed badge size and corner placement across normal icons, folders, dock/wide containers, paging, and live transitions.
   - Reduced redundant layout/reapply work and eliminated idle badge-processing activity.
   - Improved adaptive colours, including folder colours derived from currently badged apps.
   - Restored the original dotto+ pastel algorithm and added the optional **Alt. Pastel Algorithm** using OKLab/OKLCH.
   - Fixed the custom colour picker so it remains disabled and visibly dimmed while Adaptive Colour is enabled.
   - Hardened preference handling, colour extraction, private KVC access, and main-thread updates.
   - Fixed package resource layout, aligned package/bundle versions, declared iOS 15–17 bounds, and strengthened rootless/RootHide CI/package verification.

   Also include a short 1.1.0 entry identifying localization and initial modern rootless/RootHide support. Expected result: release notes describe user-visible changes instead of exposing the long experimental commit history.

9. **Wire release notes to the changelog.** In `publish.yml`, extract the heading matching the tag version from `../CHANGELOG.md`, fail if missing, and append checksums/install instructions. Do not use `git log` as the primary changes section. Expected result: unrelated branch history no longer affects release-note quality.

10. **Refresh static release review.** Run the exact `v1.1.0` tree-to-tree diff against the final development candidate; search shipping sources for logging, timers, polling, file writes, stale experimental keys, TODO/FIXME markers, old pastel labels, and version mismatches. Update `../docs/AUDIT.md` with findings and the final candidate SHA. Expected result: only intentional compatibility paths remain and the audit references the actual candidate.

11. **Build the exact candidate in canonical CI.** Produce `FINALPACKAGE=1` rootless `iphoneos-arm64` and RootHide `iphoneos-arm64e` packages using the pinned macOS toolchain. Run enhanced package verification, record SHA-256 hashes, confirm PAC-capable arm64e slices, and stage packages to the matching devices. Expected result: both packages pass and contain no trace markers.

12. **Run the two-device upgrade and behavior matrix.** Start from the actual v1.1.0 package where practical, preserve its preferences, install the candidate, respring once, and test:
    - enabled dots and disabled native/SnowBoard restoration;
    - repeated live master-toggle transitions;
    - normal icons, folders, dock/wide containers, paging, folder open/close, badge count changes, and respring/reload;
    - Adaptive Colour on/off and picker dimming/non-interaction through scrolling and reopening Settings;
    - Pastel off, original pastel on, alternate algorithm on, alternate row show/hide, and retained alternate choice;
    - SnowBoard enabled/disabled and Choicy configuration;
    - no crash, KVC exception, unrecognized selector, sustained CPU activity, or new log spam.
    Expected result: matching behavior on iOS 15 rootless and iOS 17 RootHide, with any untested OS/theme combinations explicitly recorded as residual risk.

13. **Freeze the release candidate.** After successful device testing, record the exact `development` SHA, CI run, package hashes, device OS/builds, and test outcomes in `../docs/AUDIT.md`. Make no source changes afterward without rebuilding and repeating affected tests. Expected result: one immutable candidate is the promotion authority.

14. **Reconcile history without merging unrelated roots.** In a fresh clean clone only, create `release/1.1.1` from `origin/main` at `5414d10`. Replace the index/worktree with the exact frozen candidate tree (for example, `git read-tree --reset -u <candidate-sha>`), commit once as `Release 1.1.1`, and verify the new commit tree equals the candidate tree byte-for-byte. Expected result: a clean main-descended release commit containing exactly the tested source, with `v1.1.0` reachable in its history.

15. **Review and promote main only after approval.** Push the release branch, inspect the full tree diff and CI results, then fast-forward/merge that main-based release commit only after explicit maintainer approval. Verify `git merge-base --is-ancestor v1.1.0 main` and candidate-tree identity. Expected result: `main` advances from `5414d10` only to the reviewed release commit.

16. **Tag and verify the public release.** Tag the exact promoted main commit as `v1.1.1`. Require release builds, package verification, production-gated stable-feed publication, artifact-specific feed checks, GitHub release creation, asset-hash verification, and Latest-tag verification to succeed. Expected result: feed packages and GitHub assets are the exact canonical release artifacts and rollback evidence is preserved.

## Verification

### Static and source checks

```bash
git diff --check
git grep -nE 'Perceptual Pastel Colours|Faithful Pastel Colours|kFaithfulPastelColor'
git grep -nE 'DPP_BADGE_TRACE|dotto\+\+ badge phase|os_log|next-runloop-before|after-root-geometry' -- Makefile Tweak.x
git grep -nE 'NSTimer|CADisplayLink|dispatch_source|dispatch_after|writeToFile|fopen' -- Tweak.x libdottoplus dottoPlusPlusPrefs
python3 - <<'PY'
import plistlib
with open('dottoPlusPlusPrefs/Resources/Root.plist', 'rb') as f:
    root = plistlib.load(f)
rows = {item.get('key'): item for item in root['items'] if item.get('key')}
assert rows['kUsePastelColor']['default'] is False
assert rows['kPerceptualPastelColor']['default'] is False
assert rows['kPerceptualPastelColor']['label'] == 'Alt. Pastel Algorithm'
PY
```

Expected pass signals: old labels, legacy key, trace code, runtime logging, timers, and file logging return no matches; the plist assertions pass.

### Version and history checks

```bash
test "$(awk '$1 == "Version:" {print $2}' control)" = 1.1.1
python3 - <<'PY'
import plistlib
with open('dottoPlusPlusPrefs/Resources/Info.plist', 'rb') as f:
    info = plistlib.load(f)
assert info['CFBundleShortVersionString'] == '1.1.1'
assert info['CFBundleVersion'] == '1.1.1'
PY
git merge-base --is-ancestor v1.1.0 release/1.1.1
test "$(git rev-parse release/1.1.1^{tree})" = "$(git rev-parse <frozen-candidate-sha>^{tree})"
```

Expected pass signals: all versions are 1.1.1, the release commit descends from v1.1.0/main, and its tree exactly matches the tested candidate.

### Canonical package checks

```bash
make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless ARCHS="arm64 arm64e" PACKAGE_VERSION=1.1.1
EXPECT_RELEASE=1 EXPECTED_ARCH=iphoneos-arm64 scripts/verify_package.sh
make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide ARCHS="arm64 arm64e" PACKAGE_VERSION=1.1.1
EXPECT_RELEASE=1 EXPECTED_ARCH=iphoneos-arm64e scripts/verify_package.sh
```

Run these through the pinned macOS CI environment, not as promotion evidence from the warning-producing local Linux toolchain. Expected pass signals: one package per build, correct architecture/dependencies/resources/bundle version, PAC-capable arm64e slice, and no diagnostic strings.

### Manual device checks

- iOS 15 rootless: install only `iphoneos-arm64`.
- iOS 17 RootHide: install only `iphoneos-arm64e`.
- Capture before/after screenshots for pastel off, original pastel, and alternate pastel.
- Reopen Settings and scroll the colour cell off/on screen while Adaptive Colour is enabled; it remains dimmed and non-interactive.
- Observe 30 seconds idle on SpringBoard after transitions; no sustained CPU/layout activity or dotto++ runtime log stream appears.
- Check SpringBoard crash/system logs for dotto++, KVC, selector, assertion, or watchdog failures.

Expected pass signals: all visible transitions work on both devices, no stale UI state remains, and no crash/idle activity is introduced.

### Publication checks

- Aggregate stable `Packages` contains exact matching stanzas for `iphoneos-arm64` and `iphoneos-arm64e`, version 1.1.1, with candidate filenames and hashes.
- Rootless and RootHide subfeeds each contain the correct matching candidate stanza.
- Stable `LATEST` is `1.1.1`.
- GitHub Release `v1.1.1` is Latest only after feed publication succeeds.
- Both GitHub `.deb` assets hash-match the release artifacts and published feed files.
- Generated notes contain the curated 1.1.1 changelog and checksums.

## Risks

- **Private API/runtime risk:** SpringBoard and SnowBoard internals vary by OS/theme. Mitigation: retain guarded KVC/type checks, narrow hook groups, restoration, two-device testing, and explicit iOS 15–17 bounds.
- **Preference semantics risk:** changing the alternate option name must not invert the stored `kPerceptualPastelColor` value. Mitigation: keep the key and selection logic unchanged; test all parent/child combinations. The removed `kFaithfulPastelColor` migration affects only development-test builds, not stable 1.1.0 users.
- **Performance risk:** removing tracing must not accidentally change reapply code. Mitigation: delete only trace symbols/calls/imports/flag, diff `DottoPlusPlusBadgeNeedsApply` and scheduling against the frozen pre-cleanup implementation, then rerun idle/transition checks.
- **Feed integrity risk:** old packages remain in the stable repository by design. Mitigation: verify complete current-version stanzas and hashes rather than global lines; do not delete historical packages during this release unless separately approved.
- **Publication/permission risk:** the stable feed uses a production environment and deploy key. Mitigation: make GitHub release creation depend on successful production publication and preserve artifact hashes before approval.
- **History risk:** unrelated `development` and `main` roots can create conflict-heavy or misleading merges. Mitigation: never merge them directly; promote the exact tested tree as one commit on a fresh main-based branch and verify tree identity.
- **Rollback:** before tagging, rollback is simply to leave `main` at `5414d10`. After publication, retain v1.1.0 packages/feed entries; if 1.1.1 must be withdrawn, remove/mark the GitHub release non-latest, restore stable `LATEST` and indexes to 1.1.0 through the package-repository history, and publish a corrective version rather than moving or reusing the `v1.1.1` tag.
- **Workspace contamination risk:** unrelated untracked `.pi-subagents/`, `IconDance/`, and `ICONDANCE_*.md` content must remain unstaged. Perform promotion from a fresh clone and verify `git status --short` before every release commit/tag.
