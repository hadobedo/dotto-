# dotto++ SnowBoard Badge Compatibility Plan

## Context

SnowBoard is installed on the connected iPhone as `AAASnowBoardStub.dylib` and `Snowboard.dylib`. The installed SnowBoard dylib loads alphabetically after `dottoPlusPlus.dylib`, and both tweaks currently mutate the same `SBIconBadgeView` internals (`backgroundView`, `textView`, parent layer, geometry, and visibility). dotto++ 1.1.1 compensates with one next-runloop reapply, but SnowBoard can run later and overwrite those values. This is hook-order competition rather than explicit compatibility.

The connected test device is an iPhone 13 Pro on iOS 17.1.1 with dotto++ 1.1.1 and SnowBoard installed. MCP can capture screenshots, live SpringBoard syslog, crash reports, and interact with folders/Settings. CI publishes rootless and roothide debug packages from `development`.

## Approach

1. Add change-only debug instrumentation in non-release builds to record badge state after Apple/SnowBoard `%orig`, after dotto applies, and on the next runloop.
2. Stop drawing dotto into SnowBoard’s `backgroundView`; create a dedicated dotto-owned overlay subview and image view.
3. Add an explicit two-mode renderer policy: **dotto++** owns badge rendering or **SnowBoard** owns badge rendering. Default to dotto++ to preserve existing behavior.
4. Initialize common hooks on the first main-queue turn so constructor-installed SnowBoard hooks exist first and dotto++ becomes the outer wrapper; retain iOS 17-only hook grouping.
5. Build/publish a development package and test both ownership modes with SnowBoard enabled/disabled across Home Screen, folders, paging, icon reloads, and preference changes.

## Files

- `Tweak.x` — overlay view, ownership predicate, tracing, delayed hook initialization, restore/yield behavior.
- `libdottoplus/DottoPlusPlusPreferences.h/.m` — renderer enum/key/accessor.
- `dottoPlusPlusPrefs/Resources/Root.plist` — renderer selector and explanatory footer.
- `Makefile` — enable overwrite tracing only for debug/non-final packages.
- `../docs/AUDIT.md` and `../README.md` — document compatibility policy and device evidence.
- Existing build/publish workflows remain unchanged unless verification exposes a pipeline defect.

## Reuse

- Reuse `DottoPlusPlusBadgeArt`, adaptive-color logic, geometry helpers, badge state snapshots, weak registry, Darwin preference reload, and iOS 17 hook group.
- Reuse the existing preference suite/notification and CI development publication.
- Preserve SnowBoard’s own badge subviews for restoration and SnowBoard ownership mode.

## Assumptions

- “dotto++ renderer” means dotto dots win while SnowBoard may continue theming icons and other UI.
- “SnowBoard renderer” means dotto restores/yields all badge visual and geometry changes while remaining installed.
- The overlay must not use timers or continuous polling.
- Debug tracing must be absent from `FINALPACKAGE=1` release builds.
- Existing preference keys, colors, badge art, and geometry remain compatible.

## Steps

1. Add `DottoPlusPlusBadgeRendererKey`, `DottoPlusPlusBadgeRenderer` enum, and `-badgeRenderer` to `DottoPlusPlusPreferences`; default invalid/missing values to dotto++.
2. Add a `PSSegmentCell` renderer row to `Root.plist` with values `0/1`, labels `dotto++/SnowBoard`, the existing defaults domain/notification, and a footer explaining which tweak owns badges.
3. Add `DottoPlusPlusBadgeOverlayView` in `Tweak.x`, containing one noninteractive template `UIImageView`. Associate one overlay with each badge view; create it only after the original state snapshot so restore data never treats it as SnowBoard content.
4. Rewrite `-dottoPlusPlusApply` so dotto ownership configures only the overlay image/tint/alpha/geometry, hides pre-existing badge-rendering subviews, clears parent residual rendering, and keeps the overlay frontmost. Do not replace or resize SnowBoard’s `backgroundView`.
5. When SnowBoard ownership is selected or dotto++ is disabled, hide the overlay, restore the captured pre-dotto state, and call stock/themed configuration through the existing safe reconfigure path. Make repeated transitions idempotent.
6. Replace all hook enable checks with one `DottoPlusPlusShouldOwnBadges()` predicate so geometry, intrinsic sizing, animation suppression, and positioning yield consistently in SnowBoard mode.
7. Add loaded-image SnowBoard detection and debug-only `DottoPlusPlusTraceBadgeView(view, phase)` instrumentation. Record background image pointer, tint/background colors, frame/alpha/hidden state, overlay frame/image/visibility/z-order, and loaded SnowBoard status. Store the last signature per phase/view and log only changes. Trace `after-orig`, `after-dotto`, `next-runloop-before`, and `next-runloop-after`.
8. In debug builds define `DPP_BADGE_TRACE=1`; omit it for `FINALPACKAGE=1`. Move `%init` for common hooks and the iOS 17 group to a single first-main-queue-turn initializer so SnowBoard’s constructor hooks are already installed before dotto wraps them.
9. Build rootless locally, run package verification, push to `development`, wait for both CI matrix builds and `publish-dev`, then install the new dev package on the connected iPhone.
10. Test SnowBoard installed/enabled with renderer set to dotto++: verify dots remain visible through folder open/close, Home Screen paging, Settings changes, respring/icon reload, and adaptive/pastel/appearance/opacity changes. Capture overwrite traces and confirm SnowBoard changes only its own views while the overlay remains frontmost.
11. Test renderer set to SnowBoard: verify dotto overlay is hidden, SnowBoard badge settings become visible immediately, and no dotto geometry/hidden/tint residue remains. Toggle back to dotto++ and verify the overlay returns without respring.
12. Disable SnowBoard through its normal configuration/Choicy path and repeat Home Screen/folder/paging/preference smoke checks in dotto++ mode. Re-enable SnowBoard and repeat. Check SpringBoard crash reports, KVC/unrecognized-selector errors, repeated layout logs, and memory behavior.
13. Record build IDs, package hashes, screenshots/log findings, unresolved SnowBoard extension behavior, and final compatibility status in `../docs/AUDIT.md`; update README with the explicit renderer setting.

## Verification

Static/build:

```sh
git diff --check
bash -n scripts/*.sh
python3 -c 'import plistlib; plistlib.load(open("dottoPlusPlusPrefs/Resources/Root.plist", "rb"))'
make clean package THEOS_PACKAGE_SCHEME=rootless ARCHS="arm64 arm64e" PACKAGE_VERSION=1.1.1
EXPECTED_ARCH=iphoneos-arm64 scripts/verify_package.sh
```

Pass signals: no compiler errors under `-Werror`; debug dylib contains trace marker strings; a `FINALPACKAGE=1` build does not; package metadata passes.

CI/feed: both rootless/roothide matrix jobs and `publish-dev` succeed; dev feed contains both architectures.

Device pass signals:

- Dotto++ mode: only dotto dots are visible and SnowBoard cannot replace them after layout/theme reload.
- SnowBoard mode: SnowBoard badges are visible and no dotto overlay or geometry remains.
- Switching modes works without respring.
- Folder opening, paging, icon reload, and all dotto preference changes preserve the selected owner.
- Trace order demonstrates SnowBoard `%orig` state followed by stable dotto overlay state; next-runloop state does not oscillate.
- No SpringBoard crash report, KVC exception, unrecognized selector, or sustained reapply loop.

## Risks

- Delayed hook initialization could miss badge views created before the first main-queue turn; verify immediately after respring and retain lazy registration/application paths.
- SnowBoard may alter parent badge geometry or visibility rather than only its subviews. Making dotto the outer hook wrapper addresses synchronous changes; trace evidence must identify any later asynchronous mutation.
- Hiding SnowBoard subviews while preserving them requires snapshots to exclude the dotto overlay and restore exactly the captured values.
- Renderer switching changes ownership live; recursion guards and idempotent restore/reconfigure behavior are required.
- SnowBoard version/extension internals are private and may differ across releases. Compatibility is verified against the installed version and must degrade safely.
