# dotto++ Live Badge Transition Fix Plan

## Context

The latest development candidate (`5422edd`) still has two reproducible live-transition defects on the rootless iPhone 13 Pro running iOS 17.1.1 with SnowBoard enabled:

1. Dock folder badges remain numeric after switching the renderer to dotto++; a respring with dotto++ already selected makes them render as dots.
2. A badge that was previously a wide multi-digit SnowBoard/native pill moves to the wrong horizontal position when switching to dotto++; a respring corrects it.

The failed `3740af0` and `5422edd` attempts narrow the problem. `Tweak.x` defers `%init`, but its `dppBadgeViews` and `dppIconViews` registries are populated only by initializer hooks installed after that delay. Badge/icon views created before hook installation—especially persistent dock views—can therefore be absent from a live preference update. Recursively scanning only registered icon views cannot discover an unregistered dock icon view.

The wide-badge offset has a separate concrete cause: the `-bounds` and `-center` hooks return dot geometry while dotto++ owns badges, but returning different getter values does not update the `UIView`/`CALayer` geometry already stored when SnowBoard laid out a wide pill. `-dottoPlusPlusApply` currently configures only the child overlay and never writes the root `SBIconBadgeView` bounds/center. A respring works because initial badge construction occurs under dotto geometry.

Keep all work on `development`; do not modify or promote `main`. Leave the unrelated untracked `IconDance/` directory untouched. The assistant must not operate the phone; installation and device interactions remain manual user steps.

## Approach

Replace the ineffective post-hook `SBIconView` registry expansion with an on-demand, main-thread sweep of current SpringBoard windows, merged with the existing weak badge registry. This discovers persistent dock badges during every renderer preference transition without timers, polling, or broad tracing.

Make dotto ownership explicitly set the root badge view’s actual 26×26 bounds and converted corner center before configuring the overlay. Capture and restore the root layer geometry alongside the existing SnowBoard/native visual snapshot so switching back yields cleanly. Preserve the existing single next-runloop reapply for synchronous hook-order competition, but remove the extra icon-view-wide layout pass introduced by `5422edd`.

Extend the existing debug-only, change-only trace with enough identity and actual-layer geometry to prove that dock badges are discovered and wide pills are normalized. Do not add file logging, timers, continuous polling, or release trace strings.

## Files

- `Tweak.x`
  - Current-window badge discovery.
  - Root badge geometry capture, normalization, conversion, and restoration.
  - Removal of the ineffective `dppIconViews` registry and duplicate reapply/layout pass.
  - Narrow debug-only identity/geometry trace fields.
- `DottoPlusPlusPrivate.h`
  - Add only the minimal `SBIconView` declaration needed to retrieve the icon if implementation requires it; otherwise leave unchanged.
- `../docs/AUDIT.md`
  - Record the failed `3740af0`/`5422edd` attempts, the final implementation commit/build, manual matrix results, and release status.
- `../README.md`
  - Change only after the complete manual matrix passes, and only if compatibility claims need updating.

No preference keys, plist rows, package version, badge assets, dependency metadata, CI workflow, or release workflow changes are required.

## Reuse

- Keep `dppBadgeViews` as the weak registry for post-hook and detached-but-live badge objects.
- Reuse `DottoPlusPlusCollectBadgeViews` as the recursive traversal primitive, generalized to traverse each visible/current `UIWindow` rather than only registered `SBIconView` objects.
- Reuse `DottoPlusPlusIconViewForBadge`, `DottoPlusPlusBadgeCenterForIconWidth`, `DottoPlusPlusShouldOwnBadges`, `DottoPlusPlusScheduleReapply`, `dppApplyingBadge`, the associated `DottoPlusPlusBadgeState`, and the dedicated overlay.
- Reuse the existing Darwin reload notification and main-queue callback.
- Reuse `DPP_BADGE_TRACE` and the `FINALPACKAGE=1` exclusion in `Makefile`.
- Reuse `scripts/verify_package.sh` and the existing rootless/roothide development CI matrix.

## Assumptions

- The dock symptom is caused by live-update discovery, not a separate badge class: a respring under dotto++ proves the existing `SBIconBadgeView` render path can control the dock.
- A dot remains 26×26 and uses the audited original 2pt trailing-inset target `(iconWidth - 2, 2)` in `SBIconView` coordinates, with `(58, 2)` only as the zero-width fallback. Folder/dock widths therefore remain aligned to their actual icon bounds.
- The target center must be converted from `SBIconView` coordinates into `badgeView.superview` coordinates before assigning `badgeView.center`; this prevents incorrect placement if SnowBoard inserts an intermediate container.
- Actual pre-dotto root geometry is read from `badgeView.layer.bounds` and `badgeView.layer.position`, not the hooked `-bounds`/`-center` getters.
- Window traversal occurs only on preference transitions and the existing one-turn reapply, on the main thread; it is not polling.
- iOS 15–17 support, existing preferences, appearance, adaptive/pastel behavior, and SnowBoard ownership mode remain unchanged.
- No release to `main` occurs until both reported live-transition defects pass without a respring.

## Steps

1. **Remove the ineffective icon-view registry from `Tweak.x`.** Delete `dppIconViews`, `DottoPlusPlusRegisterIconView`, the `SBIconView -init`/`-initWithFrame:` registration hooks, constructor initialization of that table, and the second `dispatch_async` block in `DottoPlusPlusUpdateBadges` that loops over `dppIconViews` and calls `layoutIfNeeded`. Retain the `SBIconView` positioning hooks. Expected result: the failed `5422edd` workaround no longer adds global icon tracking or redundant layout work.

2. **Make `DottoPlusPlusCurrentBadgeViews` discover pre-hook dock badges.** Add a main-thread-only helper, `DottoPlusPlusCollectWindowBadgeViews(NSMutableArray *)`, that enumerates `UIApplication.sharedApplication.connectedScenes`, filters `UIWindowScene` instances, traverses every scene window with `DottoPlusPlusCollectBadgeViews`, and registers each discovered `SBIconBadgeView` into `dppBadgeViews`. Merge these discovered objects with `dppBadgeViews.allObjects` while de-duplicating by object identity. If no connected window scene is available, fall back to `UIApplication.sharedApplication.windows` for iOS 15–17 resilience. Do not retain windows or create a persistent window registry. Expected result: a live preference notification includes persistent dock badge objects even if they were created before deferred `%init`.

3. **Store root badge geometry in `DottoPlusPlusBadgeState`.** Add `badgeLayerBounds` and `badgeLayerPosition` fields plus a boolean indicating valid captured geometry. In `-dottoPlusPlusCaptureStateIfNeededWithBackgroundView:`, capture `self.layer.bounds` and `self.layer.position` before any dot geometry is written. In `-dottoPlusPlusRestoreState`, restore those layer values before requesting stock layout and before discarding the snapshot. Never capture through hooked `self.bounds` or `self.center`. Expected result: SnowBoard/native pill geometry can be restored exactly when dotto yields.

4. **Add one root-geometry normalizer.** Implement `DottoPlusPlusApplyRootGeometry(SBIconBadgeView *)` in `Tweak.x`. Resolve the nearest ancestor `SBIconView`; use the audited width-aware target `(iconWidth - 2, 2)` in that icon view’s coordinate system, falling back to `(58, 2)` only when width is unavailable; convert that point into `badgeView.superview` coordinates when the icon view is not the immediate parent; then assign `badgeView.bounds = CGRectMake(0, 0, 26, 26)` and `badgeView.center = convertedCenter`. Keep the write inside the existing `dppApplyingBadge` guard. Expected result: a previously wide root badge is physically reduced and repositioned rather than merely reporting dot geometry through getters.

5. **Normalize before drawing the overlay.** In `-dottoPlusPlusApply`, after ownership and required-view checks and after capturing pre-dotto state, call `DottoPlusPlusApplyRootGeometry(self)` before `configureWithImage:color:alpha:size:center:`. Keep the `-bounds`, `-center`, sizing, and `SBIconView` positioning hooks so later SpringBoard layout queries still receive dot geometry. In `-layoutSubviews`, retain `%orig` followed by guarded `-dottoPlusPlusApply`; do not schedule another runloop pass from layout. Expected result: both immediate renderer changes and later SnowBoard layouts converge on the same actual root geometry without feedback loops.

6. **Simplify the preference transition to one deterministic sequence.** In `DottoPlusPlusUpdateBadges`, reload preferences, clear color cache, obtain the window-inclusive `DottoPlusPlusCurrentBadgeViews` snapshot, run `-dottoPlusPlusRestoreAndReconfigureStock` once per badge, invalidate only that badge hierarchy, and call the existing coalesced `DottoPlusPlusScheduleReapply` once. Ensure `DottoPlusPlusScheduleReapply` also uses the window-inclusive snapshot. Do not add additional delays, timers, repeated retries, or global `layoutIfNeeded` loops. Expected result: all current page, folder, and dock badges receive the selected ownership policy in the same bounded transition.

7. **Extend only debug trace evidence.** Update `DottoPlusPlusTraceBadgeView` under `#if DPP_BADGE_TRACE` to include the badge class, immediate parent class, nearest `SBIconView` class/pointer, window class/pointer, `self.layer.bounds`, `self.layer.position`, hooked getter bounds/center, and whether the object came from the weak registry/window sweep if that source can be represented without persistent state. Keep the existing per-view/per-phase signature suppression. Add a dedicated phase immediately after root normalization, such as `after-root-geometry`. Expected result: one changed log line can distinguish “dock badge not discovered” from “discovered but overwritten” and can compare stored layer geometry with getter geometry.

8. **Perform source-level closure before building.** Run repository searches to confirm `dppIconViews`/`DottoPlusPlusRegisterIconView` are gone, window scanning is called only by the bounded current-badge snapshot, root geometry is captured before normalization, and no logger/timer/polling API was introduced. Confirm `IconDance/` remains untracked and untouched. Expected result: the fix replaces prior speculation instead of stacking another scheduling mechanism on top.

9. **Build and validate both package schemes locally.** Build debug rootless and roothide packages with the existing strict flags, run `scripts/verify_package.sh` for each expected architecture, and inspect the debug dylib for the new trace phase. Then make a `FINALPACKAGE=1` build and confirm no trace phase/signature strings remain. Expected result: all Objective-C/Logos changes compile under `-Werror`, package metadata stays at 1.1.1, and release artifacts contain no trace instrumentation.

10. **Commit and publish only on `development`.** Commit the focused implementation and audit pre-test note, push `development`, and require rootless, roothide, and `publish-dev` jobs to pass. Do not merge, fast-forward, tag, or push `main`. Expected result: the manually tested package is traceable to one development commit and CI run.

11. **Request manual installation; do not operate the phone.** Ask the user to refresh/reinstall 1.1.1 from the development feed and respring once only to load the candidate. Do not launch apps, tap UI, install packages, or respring through tools. Expected result: all subsequent behavior reports come from user-controlled device interaction.

12. **Run the focused manual transition matrix before broader regression testing.** With SnowBoard enabled, begin in SnowBoard renderer mode and identify (a) a normal page badge, (b) a multi-digit/wide page badge, and (c) a badged dock folder. Toggle to dotto++ without respring: all three must become correctly positioned dots immediately. Toggle back to SnowBoard: numeric/pill geometry and text must return immediately. Repeat the round trip twice, then repeat after opening/closing a folder and paging the Home Screen. Expected result: neither dock ownership nor wide-badge position depends on tapping an icon or respringing.

13. **Run regression and lag checks only after the focused matrix passes.** Verify startup with each renderer selected, dotto disabled/enabled, SnowBoard Choicy-disabled/re-enabled, adaptive/pastel/appearance/opacity changes, folder badges, icon badge-count changes across one/two/three digits, and one normal respring. Observe SpringBoard responsiveness and check for new crash/KVC/unrecognized-selector output; do not add broad tracing. Expected result: no sustained CPU/layout loop, no crash, and clean bidirectional restoration.

14. **Record evidence and apply the release gate.** Update `../docs/AUDIT.md` with the implementation commit, CI run, package hashes, exact manual outcomes, and any remaining limitation. Update README compatibility language only if the full matrix passes. If either reported defect persists, keep `main` blocked and use the enhanced trace to choose the next narrow hook/path; do not add another blind delayed reapply. Expected result: release readiness is evidence-based and `main` remains untouched until accepted.

## Verification

### Static and reference checks

```sh
git branch --show-current
git status --short
git diff --check
git grep -nE 'dppIconViews|DottoPlusPlusRegisterIconView'
git grep -nE 'NSTimer|dispatch_source.*TIMER|fopen|NSFileHandle|writeToFile' -- Tweak.x
```

Pass signals:

- Branch is `development`.
- `IconDance/` is still the only unrelated untracked path.
- `git diff --check` is clean.
- The removed icon-registry grep returns no matches.
- No timer, continuous polling, or file logging was added.

### Local builds

```sh
VERSION=$(awk '$1 == "Version:" { print $2 }' control)

make clean package THEOS_PACKAGE_SCHEME=rootless ARCHS="arm64 arm64e" PACKAGE_VERSION="$VERSION"
EXPECTED_ARCH=iphoneos-arm64 scripts/verify_package.sh
DEBUG_DYLIB=$(find .theos -type f -name 'dottoPlusPlus.dylib' -print -quit)
strings "$DEBUG_DYLIB" | grep -F 'after-root-geometry'

make clean package THEOS_PACKAGE_SCHEME=roothide ARCHS="arm64 arm64e" PACKAGE_VERSION="$VERSION"
EXPECTED_ARCH=iphoneos-arm64e scripts/verify_package.sh

make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless ARCHS="arm64 arm64e" PACKAGE_VERSION="$VERSION"
FINAL_DYLIB=$(find .theos -type f -name 'dottoPlusPlus.dylib' -print -quit)
! strings "$FINAL_DYLIB" | grep -F 'after-root-geometry'
```

Pass signals:

- All builds complete under `-Wall -Wextra -Werror`.
- Package verification reports version 1.1.1 and the expected architecture/dependencies.
- Debug contains the focused trace phase; final package does not.

### CI and feed

- Both `build-and-package` matrix jobs pass.
- `publish-dev` passes and publishes the exact implementation commit.
- Development feed exposes current 1.1.1 packages for `iphoneos-arm64` and `iphoneos-arm64e`.
- No implementation commit reaches `main`.

### Manual device pass signals

- Switching SnowBoard → dotto++ updates page and dock-folder badges without a respring.
- A pre-existing wide multi-digit pill becomes a correctly positioned 26×26 dot immediately.
- Switching dotto++ → SnowBoard restores numeric text and circle/pill geometry immediately.
- Repeated round trips, folder opening, paging, count changes, and preference changes remain stable.
- Respring startup is correct with either renderer selected.
- No icon tap is needed to repair layout.
- No SpringBoard crash, KVC exception, unrecognized selector, sustained CPU use, or layout feedback occurs.

## Risks

- **Window traversal cost:** Traversing all current SpringBoard windows is broader than a registry lookup. Mitigation: run it only on the existing bounded preference/reapply paths, de-duplicate objects, retain only weak badge references, and never poll.
- **Intermediate coordinate containers:** SnowBoard may insert a superview between the icon and badge. Mitigation: convert the target point from `SBIconView` into the immediate superview before assigning `center`; trace both classes and actual layer position.
- **Auto Layout/SnowBoard overwrite:** A later layout may reset root geometry. Mitigation: keep the existing layout hook and single coalesced next-turn reapply; use trace evidence rather than adding retries.
- **Restoration fidelity:** Writing root bounds/center introduces new owned state. Mitigation: capture actual layer bounds/position before mutation and restore them before stock/themed reconfiguration.
- **Private UIKit/SpringBoard lifecycle:** Connected scene/window APIs and private badge classes can vary across iOS 15–17. Mitigation: use public scene/window traversal with a windows fallback, guard nil/type cases, and retain existing private-selector availability boundaries.
- **Regression to SpringBoard lag:** Broad scans or recursive layout can become expensive. Mitigation: remove `dppIconViews` and global `layoutIfNeeded`, keep one bounded scan/reapply, and reject any implementation that adds layout scheduling from `layoutSubviews`.
- **Rollback:** If the candidate crashes or regresses layout, revert the single focused development commit, republish the previous development package, select SnowBoard renderer or respring as a temporary device workaround, and keep `main` unchanged. There are no data, auth, billing, permission, migration, or preference-format changes to roll back.
