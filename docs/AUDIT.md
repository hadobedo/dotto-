# dotto++ 1.1.1 Release Audit

## Scope and status

This audit covers the final 1.1.1 source tree against the tagged 1.1.0 baseline. It includes the runtime tweak, shared preference/colour library, PreferenceLoader bundle, package metadata, depiction assets, and release automation.

- **Squashed candidate branch:** `development`, candidate commit `41610c6` (parent `v1.1.0`)
- **Baseline:** `v1.1.0` (`f21742f`)
- **Release branch:** `main`, tagged `v1.1.1`
- **Package version:** `1.1.1`
- **Supported firmware:** iOS `>= 15.0`, `< 18.0`
- **Release status:** **published and verified**; `v1.1.1` is the latest non-draft, non-prerelease GitHub Release and the stable feed contains both package architectures.

## 1.1.0 → 1.1.1 summary

The release includes the initial modern rootless/RootHide adaptation and localization work from the 1.1.0 line, followed by the 1.1.1 runtime hardening:

- live `Enabled` ownership toggle with symmetric native/SnowBoard restoration;
- dedicated dotto++ badge overlay and bounded, idempotence-gated reapply work;
- direct layer geometry normalization and width-aware corner positioning;
- iOS 17-only accessory positioning hook while retaining iOS 15/16 fallbacks;
- folder adaptive colours based on currently badged application icons with signature caching;
- corrected colour extraction, preference normalization, and robust custom colour-picker state;
- faithful dotto+ pastel behaviour by default plus opt-in `Alt. Pastel Algorithm` OKLab/OKLCH processing;
- package resource-layout correction, version alignment, firmware bounds, and stronger two-scheme CI/package checks;
- curated `CHANGELOG.md` and artifact-specific stable-publication gates;
- Sileo JSON and Zebra HTML package depictions with icon, changelog, links, and compatibility details.

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
- Pastel mode defaults to dotto+ 1.0.6's HSV brightness algorithm. `Alt. Pastel Algorithm` is visible only while pastel mode is enabled and selects the OKLab/OKLCH transform.

### Diagnostics and experiments

The completed `DPP_BADGE_TRACE`/`os_log` instrumentation, SnowBoard image scanning used only by that tracing, trace calls, trace-only imports, and Makefile debug flag were removed from the shipping source. Static shipping-source scans show no runtime logging, trace map, trace marker, timer, polling mechanism, file logger, or debug constructor marker.

The temporary inverse `kFaithfulPastelColor` migration was also removed. Stable users only use `kPerceptualPastelColor`, which defaults to `NO`; stable 1.1.0 did not ship the temporary development key.

## Package and CI evidence

### Canonical CI

- Development matrix CI: run `30909869132`, candidate `41610c6`, successful for rootless and RootHide.
- Main release build/publish: run `30909881938`, release commit `076bee0`, successful for both schemes, stable-feed publication, and GitHub Release creation.
- Main build matrix: run `30909882025`, successful for both schemes.
- Release tag: `v1.1.1` points to the published main release commit; the GitHub Release is non-draft, non-prerelease, and latest.
- Builds used the pinned macOS RootHide Theos toolchain with `FINALPACKAGE=1`.
- Release package inspection passed `EXPECT_RELEASE=1 scripts/verify_package.sh` for both architectures.

Recorded release artifact hashes:

- Rootless `iphoneos-arm64`: `c2e4a489034a99d2f1260e3b05cb38e23d0742aa42a24c6e05a85e609a23e8fe`
- RootHide `iphoneos-arm64e`: `eb298226ec3c3a9171080b2531c3fe3eacb5ed1c7cd1a03f42cbcb3331c1c897`

The matching GitHub Release assets are:

- `com.nicksworks.dottoplusplus_1.1.1_iphoneos-arm64.deb`
- `com.nicksworks.dottoplusplus_1.1.1_iphoneos-arm64e.deb`
- `SHA256SUMS`

Local Linux builds compile and package successfully but continue to emit arm64e ABI warnings; they are not promotion artifacts.

### Feed and depiction evidence

The stable package repository publication completed at feed commit `6bfb291f81ab7298050677b7db354084b3b46c03`. Its aggregate, rootless, and RootHide indexes each contain exactly one 1.1.1 stanza for the expected architecture, with matching filename, size, and SHA-256 hash.

The following stable assets were fetched successfully over HTTPS:

- `https://hadobedo.github.io/repo/assets/dottoplusplus.png`
- `https://hadobedo.github.io/repo/depictions/com.nicksworks.dottoplusplus.json`
- `https://hadobedo.github.io/repo/depictions/com.nicksworks.dottoplusplus.html`
- both stable 1.1.1 `.deb` paths for `iphoneos-arm64` and `iphoneos-arm64e`.

The package metadata points to the icon, Sileo depiction JSON, and Zebra/web depiction HTML. The depiction contains the 1.1.1 version, compatibility, changelog tabs, and GitHub, Ko-fi, X/Twitter, Instagram, and YouTube links.

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

The release automation now:

- derives development-feed and stable-release version checks from `control`;
- requires package/version/architecture uniqueness before development publication;
- verifies complete stable-feed package stanzas, filenames, sizes, and SHA-256 hashes against the exact release artifacts;
- verifies aggregate, rootless, and RootHide feed indexes separately;
- makes GitHub Release creation depend on successful stable-feed publication and artifact-specific verification;
- consumes the curated version section from `CHANGELOG.md` rather than unrelated Git history;
- verifies release asset hashes before upload and verifies the Latest tag afterward;
- generates and validates Sileo/Zebra depiction assets on every feed publication.

The canonical main and development workflows have both completed successfully for the final release tree.

## Final disposition

The 1.1.1 runtime, package, feed, depiction, and GitHub Release gates are complete. No further promotion action is pending for this release.
