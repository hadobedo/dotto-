# dotto++ 1.1.1 Release Audit

## Scope and status

This audit covers the proposed 1.1.1 release candidate against the tagged 1.1.0 baseline. It includes the runtime tweak, shared preference/colour library, PreferenceLoader bundle, package metadata, and release automation.

- **Candidate branch:** `development`
- **Candidate runtime commit:** `6c838ef` (`Record exact final-tip release hashes`)
- **Baseline:** `v1.1.0` (`f21742f`)
- **main:** still `5414d10`; no stable feed publication, release tag, or main-branch promotion has occurred
- **Package version:** `1.1.1`
- **Supported firmware:** iOS `>= 15.0`, `< 18.0`
- **Release status:** **runtime-validated and ready for deliberate main-promotion review**; stable publication, main promotion, and tagging remain intentionally blocked pending explicit approval

## 1.1.0 → 1.1.1 summary

The candidate includes the initial modern rootless/RootHide adaptation and localization work from the 1.1.0 line, followed by the 1.1.1 runtime hardening:

- live `Enabled` ownership toggle with symmetric native/SnowBoard restoration;
- dedicated dotto++ badge overlay and bounded, idempotence-gated reapply work;
- direct layer geometry normalization and width-aware corner positioning;
- iOS 17-only accessory positioning hook while retaining iOS 15/16 fallbacks;
- folder adaptive colours based on currently badged application icons with signature caching;
- corrected colour extraction, preference normalization, and robust custom colour-picker state;
- faithful dotto+ pastel behaviour by default plus opt-in `Alt. Pastel Algorithm` OKLab/OKLCH processing;
- package resource-layout correction, version alignment, firmware bounds, and stronger two-scheme CI/package checks;
- curated `../CHANGELOG.md` and artifact-specific stable-publication gates.

## Runtime review

### Confirmed static properties

- Badge discovery uses weak storage and current SpringBoard windows; detached views are not retained by the registry.
- Private KVC access is guarded and type-checked.
- Preference reload and UIKit/badge mutation are dispatched to the main queue.
- `dppApplyingBadge` prevents recursive application.
- Badge state captures/restores mutated view and layer state before yielding to native/SnowBoard rendering.
- The dotto++ overlay is owned independently from SnowBoard/native badge objects.
- Geometry writes normalize both public view geometry and the actual badge layer.
- Reapply scheduling is coalesced and gated by `DottoPlusPlusBadgeNeedsApply`; there is no timer or polling loop.
- Folder colour work is cached by badged-app membership signature.
- Pastel mode defaults to dotto+ 1.0.6’s HSV brightness algorithm. `Alt. Pastel Algorithm` is visible only while pastel mode is enabled and selects the OKLab/OKLCH transform.

### Diagnostics and experiments

The completed `DPP_BADGE_TRACE`/`os_log` instrumentation, SnowBoard image scanning used only by that tracing, trace calls, trace-only imports, and Makefile debug flag were removed from the candidate. Static shipping-source scans show no runtime logging, trace map, trace marker, timer, polling mechanism, file logger, or debug constructor marker.

The temporary inverse `kFaithfulPastelColor` migration was also removed. Stable users only use `kPerceptualPastelColor`, which defaults to `NO`; stable 1.1.0 did not ship the temporary development key.

## Package and CI evidence

### Current candidate CI

- Development matrix CI: run `30882509729`, candidate `25e1bef`, successful.
- Canonical release-gates CI: run `30882759967`, successful for both schemes.
- Release packages were built with `FINALPACKAGE=1` using the pinned macOS RootHide Theos toolchain.
- Release package inspection confirmed no diagnostic trace markers.
- arm64e slices report PAC-capable `PAC00` ABI metadata.

Recorded candidate artifact hashes:

- Rootless `iphoneos-arm64`: `18bd36ee3babb4cbeb6a8fb21468ae581881d28309185feef18715e4798500fb`
- RootHide `iphoneos-arm64e`: `91f730c3f8ad2e52e603e074df7837b322d62b26ed1dfe804b695fef44a109a7`

The matching packages are staged, but not installed automatically:

- rootless device: `/tmp/com.nicksworks.dottoplusplus_1.1.1-final-tip-rootless.deb`
- RootHide device: `/tmp/com.nicksworks.dottoplusplus_1.1.1-final-tip-roothide.deb`

Local Linux builds compile and package successfully but continue to emit arm64e ABI warnings; they are not promotion artifacts.

### Package verification

`EXPECT_RELEASE=1 scripts/verify_package.sh` passed against both canonical CI artifacts. It verified:

- package name, version, architecture, dependencies, and bundle versions;
- tweak dylib and filter plist;
- PreferenceLoader entry and preference bundle executable/Info.plist;
- shared `libdottoplus.dylib`;
- both required badge images;
- SpringBoard-only filter bundle;
- absence of diagnostic trace markers.

## Manual device evidence

The final 1.1.1 packages were installed and manually validated on both configured devices:

- iOS 15 rootless on `192.168.1.156` with `iphoneos-arm64`;
- iOS 17 RootHide on `100.99.60.75` with `iphoneos-arm64e`.

User-confirmed checks passed on both devices:

- adaptive colours on regular icons and folders, including changing badged-app membership;
- folders, paging, dock/wide layouts, opening/closing transitions, and stable badge geometry;
- live Enabled toggle with native/SnowBoard restoration and re-enable;
- Adaptive Colour picker dimming and restoration when the setting changes;
- pastel off, faithful original pastel, and `Alt. Pastel Algorithm` paths;
- Settings reopening/state persistence and respring behavior;
- no visible SpringBoard crash, KVC/selector failure, badge flicker, idle churn, or unexpected logging during the check.

The final two-device runtime matrix is **passed**. The RootHide loader may rewrite a small code-signature/UUID region during installation, so the on-device dylib hash need not equal the pre-install package payload; package metadata and architecture remain correct.

## Release automation review

The candidate now:

- derives development-feed version checks from `control` rather than a duplicated workflow constant;
- requires package/version/architecture uniqueness before development publication;
- verifies complete stable-feed package stanzas, filenames, sizes, and SHA-256 hashes against the exact release artifacts;
- verifies aggregate, rootless, and RootHide feed indexes separately;
- makes GitHub Release creation depend on successful production-gated stable-feed publication;
- consumes the curated version section from `../CHANGELOG.md` rather than unrelated Git history;
- verifies release asset hashes before upload and verifies the Latest tag afterward.

These release-workflow changes have been YAML- and shell-syntax checked but have not been run against the production-gated stable publication path, by design.

## Promotion gate

The runtime candidate is ready for promotion review. Promotion still requires:

1. freezing this candidate with no further runtime/source changes;
2. creating a fresh main-descended release tree with byte-identical candidate contents;
3. explicit maintainer approval before advancing `main`, tagging `v1.1.1`, or publishing the stable feed.

Until then, `main` remains safely at `5414d10` and no stable package feed or GitHub release is published.
