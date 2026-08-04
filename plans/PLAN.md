# dotto++ Logic Audit and Stabilization Plan

## Context

The repository is an Objective-C/Theos SpringBoard tweak, not a C project: runtime behavior is in `Tweak.x`, private declarations are in `DottoPlusPlusPrivate.h`, shared logic is in `libdottoplus/*.h` and `*.m`, and the Settings bundle is in `dottoPlusPlusPrefs/*.h` and `*.m`. No standalone `.c` files are tracked.

Static review found solid reverse-engineering work, ARC, strict compiler warnings, a pinned CI toolchain, rootless/roothide packaging, and narrowly scoped SpringBoard injection. The provisional “vibe-code” score is **4/10** where 10 means highly improvised: this is a thoughtful enthusiast/rebuild project, but several patch-on-patch choices are not production-hardened.

Prioritized findings that this plan addresses:

- **High:** `dppBadgeViews` strongly retains every `SBIconBadgeView`, so the `-dealloc` cleanup in `Tweak.x` is unreachable and stale views accumulate.
- **High:** live disable restores only the stock image/text visibility although enabled mode mutates frame, center, tint, alpha, background/layer contents, and every non-background subview’s hidden state.
- **High:** `-[SBIconBadgeView init]` ignores the object returned by `%orig`.
- **Medium:** the Darwin callback touches UIKit and mutable global collections without explicitly returning to the main queue.
- **Medium:** direct KVC of `backgroundView`, `textView`, and provider `iconImageView` can throw inside SpringBoard when private internals differ.
- **Medium:** adaptive folder colors are cached even though they depend on current badge membership; app colors are not invalidated when an icon/provider is reconfigured.
- **Medium:** dominant-color downsampling uses integer aspect-ratio division and can divide by zero for portrait images; a valid one-cluster/solid-color image incorrectly returns red; first-pixel dominance starts at zero.
- **Medium:** the Settings color picker writes and posts a Darwin notification for every drag update, while the UI tracks a different, sometimes uninitialized global selected-color object.
- **Medium:** adaptive-color cell enablement manually calls the table data source for a hard-coded index path and reads a stale preference snapshot.
- **Medium:** the package permits installation below the `15.0` deployment target.
- **Low/dead code:** `dottoPlusPlusIsIconFolder`, `darkerColor`, `pastelColor`, `colors`, `indexOfSelected`, the self-to-self center constraint, `DottoPrefsCompat.h`, and `symbolImageNamed:color:`’s color argument are unused or inert. Palette values and preference string constants are duplicated. Cancelled/failed appearance gestures can leave a choice dimmed. Bundle/package versions disagree.

A jailbroken iPhone 13 Pro is connected over USB and SSH at `mobile@100.99.60.75`; dotto++ 1.1.0 debug is installed from the development feed. Use that device for immediate runtime validation of the iOS 15–17-compatible hook behavior, memory/lifecycle paths, preference notifications, and screenshots. Additional OS-version/device coverage remains deferred unless another device is available.

## Approach

Apply a behavior-preserving stabilization in four ordered layers:

1. Fix lifecycle, thread, and initializer correctness in hooks before cosmetic refactors.
2. Make adaptive-color/image analysis deterministic and safe for malformed or unusual inputs.
3. Remove duplicate Settings state and ensure writes/notifications occur once per committed interaction.
4. Remove proven dead surface, align metadata/docs, and record the audit evidence.

Preserve the existing preference domain, keys, archived `UIColor` representation, badge art, geometry, appearance choices, and iOS 15–17 support. Keep the one-next-runloop SnowBoard reapply workaround initially; do not replace it without device evidence that another integration is reliable.

## Files

### Modify

- `Tweak.x` — weak registry, `%orig` initializer handling, main-queue reload, guarded private lookup, symmetric capture/restore, cache invalidation, iOS 17 hook gating.
- `DottoPlusPlusPrivate.h` — clarify exact private selectors/types and iOS 17-only availability used by hook groups.
- `libdottoplus/DottoPlusPlusPreferences.h`
- `libdottoplus/DottoPlusPlusPreferences.m` — shared exported constants, hidden snapshot storage, validated/clamped reads, removal of synchronous `synchronize`.
- `libdottoplus/UIColor+dottoPlusPlus.h`
- `libdottoplus/UIColor+dottoPlusPlus.m` — namespaced live color helper, fixed downsampling/clustering, nullable failure result, reduced public category surface.
- `libdottoplus/RGBPixel.h` — document the cluster count invariant (`d >= 1` for a created cluster).
- `dottoPlusPlusPrefs/DottoPlusPlusRootListController.h`
- `dottoPlusPlusPrefs/DottoPlusPlusRootListController.m` — visible-cell adaptive state, typed/dead API cleanup.
- `dottoPlusPlusPrefs/DottoPlusPlusColorSelectionTableCell.h`
- `dottoPlusPlusPrefs/DottoPlusPlusColorSelectionTableCell.m` — single palette source and preference-backed selected state.
- `dottoPlusPlusPrefs/DottoPlusPlusColorRowStackView.h`
- `dottoPlusPlusPrefs/DottoPlusPlusColorRowStackView.m` — lazy canonical palette and removal of global selection/picker/dead properties.
- `dottoPlusPlusPrefs/DottoPlusPlusColorItemView.h`
- `dottoPlusPlusPrefs/DottoPlusPlusColorItemView.m` — own lazy picker, normalized committed write, presenter guard.
- `dottoPlusPlusPrefs/DottoPlusPlusAppearanceSelectionTableCell.m` — cancelled/failed gesture restoration.
- `dottoPlusPlusPrefs/Resources/Info.plist` — align bundle version with package version.
- `control` — add the iOS 15 lower firmware bound.
- `scripts/verify_package.sh` — verify the new dependency constraint and bundle/package version agreement.
- `scripts/publish_repo.sh` — fail closed when the deploy key is missing and verify both debug package architectures are present before pushing the dev feed.
- `.github/workflows/build.yml` — keep development-branch publishing downstream of both matrix builds and add an explicit publish verification signal.
- `.github/workflows/publish.yml` — make the `v1.1.1` GitHub release explicitly latest and verify the latest-release API after publication.
- `../README.md` — correct formatting and state the tested/runtime support matrix precisely.
- `../docs/ANALYSIS.md` — separate original-binary behavior from current rebuild fixes so historical notes do not imply unfixed behavior.

### Add

- `../docs/AUDIT.md` — severity-ranked findings, dispositions, compatibility assumptions, verification evidence, residual risks, and the final vibe-code scorecard.

### Delete after reference checks

- `dottoPlusPlusPrefs/DottoPrefsCompat.h` — only supports the manual cell-construction path removed below.

No change is planned for `RGBPixel.m`, link/credit controllers, localization resources, badge assets, dependency versions, or preference keys unless compilation/reference checks expose a direct need.

## Reuse

- Keep `DottoPlusPlusScheduleReapply`, `DottoPlusPlusBadgeCenterForIconWidth`, badge-art crop/cache logic, folder traversal, and the existing Darwin notification architecture.
- Reuse `DottoPlusPlusPreferences` as the single source of persisted state instead of introducing another settings store.
- Reuse `DottoPlusPlusColorRowStackView +standardColors` as the canonical 11-color palette; make it initialize itself once and have the selection cell slice that array into its two rows.
- Reuse existing `-configureForIcon:infoProvider:` to ask SpringBoard to reconstruct stock badge state after live disable.
- Reuse the two existing CI matrix builds (`roothide` and `rootless`) and `scripts/verify_package.sh`.
- Keep strict `-Wall -Wextra -Werror` and ARC flags as the compile-time quality gate.

## Assumptions

- Supported runtime remains iOS 15.x–17.x; iOS 18 is out of scope.
- Visual parity with the current dot/circle art, 26-point badge size, relative corner positioning, adaptive/pastel options, and SnowBoard compatibility is required.
- Preference keys and archived color data are public compatibility surface and must not be migrated or renamed.
- The `infoProvider` association remains strong in this pass because its ownership graph is not proven. Only the definitely incorrect global strong registry is changed; provider ownership can be revisited after runtime retain-cycle evidence.
- A failed dominant-color extraction should return `nil` so callers use the configured fallback color; red must not be used as an error sentinel because red is a valid icon color.
- Device validation is available immediately on the connected jailbroken iPhone 13 Pro over `mobile@100.99.60.75`, currently running the installed 1.1.0 development build. This proves only that device/OS combination; iOS 15/16 and other hardware remain separate coverage.
- No broad rewrite to Swift, Orion, or another hook framework is included; that would increase compatibility risk without fixing the identified defects.

## Steps

1. **Create the audit baseline in `../docs/AUDIT.md`.** Record every finding from `Tweak.x`, `DottoPlusPlusPrivate.h`, `libdottoplus`, Settings classes, plist/control metadata, and CI. For each item include severity, exact symbol/path, observable consequence, planned disposition, and verification status. Add the 4/10 score with separate subscores for reverse-engineering rigor, runtime safety, state management, testability, and maintainability. Expected result: the audit remains useful even if some refactors are deferred.

2. **Centralize preference constants and harden preference reads in `DottoPlusPlusPreferences.h/.m`.** Export namespaced constants for the suite, Darwin notification, and six existing keys; replace duplicate static strings in `Tweak.x`, `DottoPlusPlusRootListController.m`, `DottoPlusPlusColorItemView.m`, and `DottoPlusPlusAppearanceSelectionTableCell.m`. Move the mutable `preferences` property into a private class extension, remove it from the public header, remove deprecated `-synchronize`, clamp `-transparency` to `0.0...1.0`, and keep all existing defaults/data formats. Expected result: one code source for preference identifiers, no public mutable snapshot, and malformed opacity cannot escape UIKit’s valid alpha range.

3. **Fix badge-view ownership, initialization, and callback threading in `Tweak.x`.** Change `dppBadgeViews` to `NSHashTable<SBIconBadgeView *> *` initialized with `weakObjectsHashTable`; remove the now-redundant `-dealloc` hook; in `-init`, assign `self = %orig` and register only the returned non-nil object. Make `DottoPlusPlusUpdateBadges` dispatch its reload/cache/view work to the main queue (executing directly only when already on main). Enumerate a snapshot from `dppBadgeViews.allObjects` in notification and scheduled-reapply paths. Expected result: detached badge views deallocate, registry iteration cannot retain stale views, replacement/nil initializers are respected, and UIKit/global mutable state is main-thread confined.

4. **Make private view access fail safe and gate the iOS 17 hook.** Add one static guarded KVC helper in `Tweak.x` that returns `nil` on `NSUndefinedKeyException`; validate returned objects before treating them as image views. Route `backgroundView`, `textView`, and `iconImageView` lookup through it, returning the selected fallback color or skipping application when required internals are absent. Put `accessoryCenterForIconBounds:` in an iOS-17-only Logos group initialized from `%ctor`; keep the common badge and `_centerForAccessoryView` hooks in the base group. Update `DottoPlusPlusPrivate.h` comments/declarations to distinguish selectors verified on 17.1 from the claimed 15–17 runtime matrix. Expected result: a private ivar rename degrades the tweak instead of crashing SpringBoard, and iOS 15/16 do not install an iOS 17-only hook.

5. **Implement symmetric stock-state restoration in `Tweak.x`.** Replace `dottoPlusPlusStockBackgroundImage` with one associated snapshot object that records every property changed by `-dottoPlusPlusApply`: background image/tint/background/layer background/frame/alpha, badge view background/layer contents, and each existing subview’s original `hidden` state. Add `-dottoPlusPlusCaptureStateIfNeeded` and `-dottoPlusPlusRestoreStateAndDiscardSnapshot`. In `-configureForIcon:infoProvider:`, restore/discard before `%orig`, then store the new icon/provider and capture/apply only when enabled. In preference reload, when transitioning to disabled, restore first and call the stock `configureForIcon:infoProvider:` for views with valid saved inputs so badge text/layout is regenerated; otherwise just restore. Make repeated apply/restore calls idempotent. Expected result: disabling without respring returns all dotto++-owned mutations to the pre-application values and current badge text is rebuilt.

6. **Correct adaptive-color cache ownership and invalidation in `Tweak.x`.** Never read/write `dppColourCache` for `SBFolderIcon`, because folder color depends on live child badge membership. Remove the cached app entry whenever `-configureForIcon:infoProvider:` receives that icon, then recompute after `%orig` has refreshed its image view. Continue clearing the full cache on relevant preference reload. Treat a nil dominant-color result as a request for `dottoSelectedColour`. Expected result: folder color follows badge membership immediately and reused/updated icons do not retain stale colors.

7. **Repair and narrow the color-analysis API in `UIColor+dottoPlusPlus.h/.m` and `RGBPixel.h`.** Replace integer aspect-ratio math with floating-point dimensions derived from a maximum 2,000-pixel budget, explicitly clamp both dimensions to at least one, and guard multiplication/allocation overflow. Initialize a new cluster’s `d` to one; fall back to unfiltered clusters only when the filtered set is empty; return the sole cluster when count is one; return `nil` for no drawable/opaque color or allocation/context failure. Convert `dottoColourDistance:andB:` into a file-static helper so it is not a public UIImage selector. Remove unused `darkerColor`/`pastelColor`; rename `lighterColor` to a namespaced method and in `Tweak.x` retain the original color if conversion fails. Expected result: portrait, landscape, solid, transparent, grayscale, and dynamic-color inputs cannot divide by zero or produce a fake error-red result.

8. **Remove duplicate/global color UI state in the Settings bundle.** Make `+standardColors` lazily return the canonical palette without depending on row construction. Build the two rows in `DottoPlusPlusColorSelectionTableCell` from slices of that palette plus the picker sentinel. Delete `+selectedColor`, `+setSelectedColor:`, `dppSelectedColor`, `colors`, `indexOfSelected`, eager row picker creation, and the self-to-self center constraint. In `-updateCircles`, reload/read `DottoPlusPlusPreferences.dottoSelectedColour` as the authority. Give only the custom `DottoPlusPlusColorItemView` a lazily created `UIColorPickerViewController`; persist the normalized color only from `colorPickerViewControllerDidFinish:`, use that same normalized object for UI refresh, and safely abort if no foreground presenter exists. Type all `forController:` parameters/properties to their actual classes. Expected result: initial outlines match persisted state, picker dragging does not flood SpringBoard, and the UI has no parallel selection model.

9. **Fix adaptive-row lifecycle and appearance gesture cleanup.** In `DottoPlusPlusRootListController`, remove `setCellForRowAtIndexPath:enabled:` and the special `readPreferenceValue:` path. After `[super setPreferenceValue:specifier:]`, update only visible `DottoPlusPlusColorSelectionTableCell` instances using the just-written adaptive value; also configure that cell in `tableView:willDisplayCell:forRowAtIndexPath:` from a freshly reloaded preference snapshot. Remove `DottoPrefsCompat.h` and its imports after grep confirms no consumers. Rename `symbolImageNamed:color:` to `symbolImageNamed:` and update both call sites. In `DottoPlusPlusAppearanceSelectionTableCell`, restore alpha for Ended, Cancelled, and Failed states, selecting only on Ended. Expected result: scrolling/reopening Settings preserves correct enabled state, no data-source method is invoked to mutate a cell, and interrupted gestures do not leave dimmed UI.

10. **Align package metadata and documentation for the 1.1.1 candidate.** Change `control` to `Version: 1.1.1` and require both `firmware (>= 15.0)` and `firmware (<< 18.0)`; update `scripts/verify_package.sh` to assert that supported range. Set both preference bundle version fields to `1.1.1`, and extend package verification to extract the bundle `Info.plist` and compare it with `control`’s version. Fix README emphasis/spacing, distinguish CI-built schemes from device-tested versions, and link `../docs/AUDIT.md`. Update the current-rebuild portion of `../docs/ANALYSIS.md` to mark the weak registry, restored state, color fixes, and hook gating without rewriting the historical 1.0.6 decompilation. Expected result: development packages are clearly the 1.1.1 candidate and installation constraints, binaries, docs, and audit claims agree.

11. **Make development publishing fail closed and self-verifying.** Preserve `.github/workflows/build.yml`’s `publish-dev` dependency on the complete `build-and-package` matrix and its `github.ref == 'refs/heads/development'` gate. In `scripts/publish_repo.sh`, replace the current missing-`REPO_DEPLOY_KEY` success exit with a hard failure, verify the staged `dev/debs` contains one current `1.1.1` package for each expected architecture (`iphoneos-arm64` rootless and `iphoneos-arm64e` roothide), regenerate `Packages*`/`Release`, and verify those two package stanzas before committing and pushing `hadobedo/repo` main. Add a final workflow step that prints the published dev-feed commit and URL. Expected result: a green `publish-dev` job proves the debug feed was actually updated instead of silently skipping publication.

12. **Perform dead-code/reference closure before building.** Search the complete tracked tree for every removed symbol/header and for duplicated preference literals. Retain a symbol only if a real consumer is found, documenting that exception in `../docs/AUDIT.md`. Confirm all declarations match implementations and no implementation-only selector unintentionally remains public. Expected result: dead-code removals are proven by repository-wide references rather than appearance alone.

13. **Build, push to `development`, verify publication, and run the device matrix.** Run both CI-equivalent package builds, package verification, plist validation, and local static checks first. Commit the reviewed changes on the source repository’s `development` branch and push it to the configured `hadobedo` remote (`https://github.com/hadobedo/dotto-.git`, the repository for the dotto++ project); do not push implementation commits directly to `main`. Wait for both `build-and-package` matrix jobs and `publish-dev` to succeed, then confirm the `https://hadobedo.github.io/repo/dev/` metadata exposes both 1.1.1 debug packages before installing from that feed for the manual scenarios below. Record pass/fail evidence and any deferred SnowBoard/private-API issues in `../docs/AUDIT.md`; do not upgrade a static assumption to “verified” without device evidence. Expected result: the exact candidate tested on devices is produced and published by CI from `development`.

14. **Release 1.1.1 only after an explicit readiness gate.** After the development-feed/device matrix is accepted, merge or fast-forward the exact tested `development` commit to `main`, then create and push tag `v1.1.1` on that main-contained commit. Keep `.github/workflows/publish.yml`’s main-ancestry and tag/control-version checks; pass `--latest` to `gh release create`, and add a final `gh api repos/$GITHUB_REPOSITORY/releases/latest --jq .tag_name` assertion equal to `v1.1.1`. Require the `build-release`, production `publish-repository`, and `create-github-release` jobs to succeed; verify the stable feed contains both architectures and GitHub displays 1.1.1 as Latest. Expected result: development pushes only update the debug feed, while the explicit main/tag gate publishes the stable feed and latest GitHub release.

## Verification

### Static/reference checks

Run from the repository root after implementation:

```sh
plutil -lint dottoPlusPlus.plist \
  dottoPlusPlusPrefs/Resources/Info.plist \
  dottoPlusPlusPrefs/Resources/Root.plist \
  Layout/Library/PreferenceLoader/Preferences/dottoPlusPlusPrefs.plist

git grep -nE 'dottoPlusPlusIsIconFolder|darkerColor|pastelColor|indexOfSelected|DottoPrefsCompat|setSelectedColor:|selectedColor]'

git grep -n 'com.nicksworks.dottoplusplus/ReloadPrefs' -- '*.h' '*.m' '*.x'
```

Pass signals:

- Every plist reports `OK`.
- The dead-symbol grep returns no source matches.
- The reload notification literal exists only at its canonical definition (plist resources necessarily retain their declarative literal and should be listed as documented exceptions).

### CI-equivalent builds and development publication

```sh
VERSION=$(awk '$1 == "Version:" { print $2 }' control)
make clean package THEOS_PACKAGE_SCHEME=roothide ARCHS="arm64 arm64e" PACKAGE_VERSION="$VERSION"
EXPECTED_ARCH=iphoneos-arm64e scripts/verify_package.sh

make clean package THEOS_PACKAGE_SCHEME=rootless ARCHS="arm64 arm64e" PACKAGE_VERSION="$VERSION"
EXPECTED_ARCH=iphoneos-arm64 scripts/verify_package.sh
```

Pass signals: both builds finish with no warnings promoted by `-Werror`; each verification reports package metadata verified; the dependency range is `>= 15.0` and `< 18.0`; package and embedded preference bundle versions are `1.1.1`.

After `git push hadobedo development` sends the reviewed candidate to `hadobedo/dotto-`’s `development` branch, verify in GitHub Actions that `build-and-package` succeeds for both matrix entries and `publish-dev` succeeds afterward. Then check the published feed:

```sh
curl -fsSL https://hadobedo.github.io/repo/dev/Packages -o /tmp/dottoplus-dev-Packages
grep -F 'Version: 1.1.1' /tmp/dottoplus-dev-Packages
grep -F 'Architecture: iphoneos-arm64' /tmp/dottoplus-dev-Packages
grep -F 'Architecture: iphoneos-arm64e' /tmp/dottoplus-dev-Packages
```

Pass signals: the workflow does not report a skipped publish, the dev-feed repository receives a new CI commit, and `Packages` contains current 1.1.1 stanzas for both rootless and roothide architectures.

When the user declares the tested candidate release-ready, push the exact commit to `main`, tag it `v1.1.1`, and verify the release workflow:

```sh
gh run list --workflow publish.yml --limit 1
gh api repos/hadobedo/dotto-/releases/latest --jq .tag_name
curl -fsSL https://hadobedo.github.io/repo/Packages -o /tmp/dottoplus-stable-Packages
grep -F 'Version: 1.1.1' /tmp/dottoplus-stable-Packages
```

Pass signals: release build, production repository publish, and GitHub release jobs are green; the API prints `v1.1.1`; the stable feed contains 1.1.1.

### Dominant-color runtime fixtures

On a supported test device or an iOS UIKit test harness, evaluate generated images for: solid blue, solid red, fully transparent, black/white-only, 40×100 portrait, 100×40 landscape, and 60×60 multicolor. Pass signals:

- No crash, divide-by-zero, zero-sized context, or non-finite dimension.
- Solid blue/red returns that color, not an error sentinel.
- Transparent returns nil and the badge uses the configured fallback.
- Portrait and landscape sample dimensions remain positive and at or below the 2,000-pixel budget.
- Black/white-only fixtures return a real drawable color; multicolor output remains deterministic across repeated calls.

### Settings manual checks

1. Open Settings with a standard persisted color, then a custom persisted color. The corresponding standard swatch or picker swatch is outlined immediately.
2. Toggle Adaptive Colour while the color cell is visible, scroll it off/on screen, leave/re-enter the pane, and relaunch Settings. The color cell is dimmed/noninteractive only while adaptive mode is enabled.
3. Drag continuously in the native color picker, then finish once. Observe the Darwin notification with `notifyutil`/equivalent instrumentation: one persisted reload occurs on finish, not one per drag update.
4. Cancel an appearance press by dragging away. Alpha returns to 1.0 and the selected type does not change.

### SpringBoard device validation

Run the first-pass matrix on the connected jailbroken iPhone 13 Pro over SSH (`mobile@100.99.60.75`) with the installed 1.1.0 development build. Capture the device OS/build, jailbreak scheme, package hash, screenshots, and relevant logs. Repeat on iOS 15/16 or another scheme only when hardware is available; do not generalize this device result to the full support range:

1. Enable/disable without respring after changing appearance, opacity, pastel mode, and adaptive mode. Compare view hierarchy properties and screenshots to a stock/themed baseline; no hidden/tint/frame/alpha residue remains.
2. Page Home Screen and repeatedly open/close folders. Inspect SpringBoard memory and, in a debug session, `dppBadgeViews.allObjects.count`; detached views disappear and memory/iteration count does not monotonically grow.
3. Change which app inside a folder has a badge without reopening Settings. The folder dot color updates to the current badged set.
4. Update/retheme an app icon and force badge reconfiguration. The app’s adaptive color recomputes.
5. Exercise notification changes, animated badge updates, Force Touch/context menus, folders, App Library, dock, and rotation/iPad layout if available. No SpringBoard crash or recursive layout storm occurs.
6. Repeat with SnowBoard enabled and disabled. The dot remains authoritative after the one-turn reapply without sustained CPU/layout churn.
7. Review crash logs and system console for KVC exceptions, unrecognized selectors, main-thread UIKit warnings, and repeated apply loops. Pass signal: none are present.

## Risks

- **Private API/OS variance:** iOS 17.1 headers do not prove iOS 15/16 behavior. The connected iPhone 13 Pro provides a real runtime check for its installed OS; after the candidate is published to the dev repo, manually test the rootless build on iOS 15 and iOS 16 as planned. Guarded lookup and hook grouping reduce crash impact; roll back the specific hook group if a version fails rather than disabling all fixes.
- **Third-party themers:** capturing/restoring exact pre-application state may interact with SnowBoard hook order. The snapshot must restore values it actually captured, not assumed stock constants. If device testing shows ordering conflicts, keep the weak-registry/thread/color fixes and defer only the live-restore portion with the respring recommendation documented.
- **Calling stock configure on disable:** this may have lifecycle assumptions. Guard for non-nil icon/provider, perform it only on the main thread, and fall back to snapshot restore if testing shows recursion or invalid context.
- **Weak registry:** views can disappear during iteration; always enumerate `allObjects` snapshots on the main thread. Do not weaken the provider association in the same change without ownership evidence.
- **Color behavior:** fixing one-cluster/extreme filtering intentionally changes adaptive output for solid and mostly monochrome icons. Keep fixture results/screenshots in the audit so visual changes are reviewable.
- **Notification coalescing:** committing custom color only on picker finish changes live preview behavior. Local outline preview may remain, but cross-process badge updates should occur once; if product requirements demand live SpringBoard preview, debounce rather than restoring per-drag synchronous writes.
- **Packaging permissions:** adding `firmware (>= 15.0)` blocks unsupported older installs but performs no preference/data migration. Existing keys and archives remain untouched.
- **Version alignment:** bundle version verification must handle the compression format emitted by both package schemes. Fail closed with a clear diagnostic; do not silently skip an unreadable data archive.
- **CI publication credentials:** `REPO_DEPLOY_KEY`, GitHub Pages deployment, or production-environment approval can block publishing even when compilation succeeds. Treat a skipped/failed `publish-dev` as a failed candidate, surface the exact missing external action, and never claim the dev feed was updated from build artifacts alone.
- **Branch/release safety:** all candidate work goes to `development`; `main` and `v1.1.1` remain untouched until explicit release readiness after device testing. The release tag must identify the exact tested commit and be contained in main, or `publish.yml` must fail.
- **Rollback:** changes are separable by the ordered layers above. If runtime validation fails, revert the failing layer while retaining independently verified lifecycle/algorithm fixes. A bad dev package can be superseded from `development`; a stable release should be corrected with a new version rather than moving an already published tag. No database, auth, billing, entitlement, or irreversible migration is involved.
