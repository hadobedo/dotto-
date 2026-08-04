# dotto++ Runtime Recovery and Lag Profiling Plan

## Context

The actual regression sequence is:

1. dotto++ 1.1.1 was visibly applying colored dot badges on the iPhone 13 Pro running iOS 17.1.1 with SnowBoard.
2. That working implementation was functionally correct but Home Screen page swipes and folder open/close animations were choppy.
3. Profiling found excessive badge activity (approximately 4,002 `dottoPlusPlusApply` calls and 5,085 scheduled reapply calls in a 43.7-second development trace).
4. Commits `9cf1198`, `23bf189`, and `83f709f` added idempotence gates and stopped stable parallax-triggered sweeps.
5. While rebuilding, repackaging, and profiling those changes, the installed package stopped visibly overriding badges. The investigation then drifted into generic injection tests before first restoring the known-working package state.

Git and package evidence now establish these boundaries:

- `83f709f` is the last tracked runtime-code change. `4b4f50f` and `0e31607` only corrected packaged resources and recorded verification; `Tweak.x`, `Makefile`, and `dottoPlusPlus.plist` are unchanged between `83f709f` and `HEAD`.
- Earlier audit history records visible dot badges, live toggle behavior, folder interaction, and SpringBoard geometry traces before the inactive package was installed.
- The device retains known earlier package controls, including `/var/mobile/dottoplusplus-snowboard-1.1.1.deb` and `/var/mobile/dottoplusplus-1.1.1-rootless.deb`.
- The archived earlier rootless packages contain an arm64e `PAC00` slice and `@rpath/libdottoplus.dylib`; the later locally built RootHide package contains a different arm64e slice reported as `00` and uses `@loader_path/.jbroot/usr/local/lib/libdottoplus.dylib`.
- The later local RootHide build emitted linker warnings that its arm64e objects were built with an incompatible arm64e ABI compiler. This is a leading package/toolchain hypothesis, not yet a proven root cause.
- Two uncommitted diagnostic detours exist: a debug constructor `os_log` in `Tweak.x` and an `Executables = ("SpringBoard")` filter in `dottoPlusPlus.plist`. The constructor build was not installed. Neither change is part of the lag work or a confirmed fix.

The immediate objective is to restore a controlled, visibly working dotto++ build. The performance objective resumes only after that baseline is restored.

## Approach

Use a control-first A/B sequence that changes one variable at a time:

1. Return the workspace to tracked `HEAD` behavior by removing only the two uncommitted diagnostic edits.
2. Record the currently installed package/binary identity without changing the device.
3. Reinstall the archived known-working package as a runtime/environment control.
4. Build current `HEAD` with the same rootless toolchain/package style as the working control and install it.
5. If current `HEAD` works under that package style, isolate and correct the RootHide build/toolchain discrepancy. Do not change badge hooks to solve a package-load defect.
6. If current `HEAD` does not work under the known-working package style, bisect only the runtime commits between the working control source and `83f709f`.
7. Once current `HEAD` visibly works, collect matched release-build enabled/disabled Time Profiler captures and optimize only the measured hot path.

No further injection instrumentation, filter broadening, or badge-logic changes should be made before the package control test.

## Files

- `Tweak.x`
  - First remove only the uncommitted debug constructor marker.
  - Later modify runtime code only if a working release profile identifies a dotto++ hot path.
- `dottoPlusPlus.plist`
  - Restore the tracked bundle-only SpringBoard filter unless a known-working package comparison proves the executable filter is required.
- `Makefile`
  - Preserve current strict warnings and release trace exclusion.
  - Modify only if package A/B evidence proves a toolchain, architecture, install-name, or scheme defect.
- `.github/workflows/build.yml`
  - Reuse the pinned macOS RootHide Theos build as the canonical RootHide artifact source.
  - Change only if CI artifacts reproduce the local ABI/load defect.
- `scripts/verify_package.sh`
  - Extend only after root cause is proven, for example to reject a known-invalid slice/install-name combination or to verify the expected scheme-specific payload.
- `../docs/AUDIT.md`
  - Correct the runtime chronology and record package hashes, device results, profile evidence, and remaining coverage only after verification.
- `control`
  - Keep version `1.1.1`; do not change package version or firmware range during diagnosis.
- Unrelated `IconDance/`, `.pi-subagents/`, and `ICONDANCE_*.md` paths must remain untouched.

## Reuse

- Reuse `scripts/verify_package.sh` for package metadata, architecture, bundle version, and required-resource checks.
- Reuse the pinned RootHide Theos commit in `.github/workflows/build.yml` for reproducible macOS artifacts.
- Reuse the device-resident package controls instead of reconstructing an assumed working build:
  - `/var/mobile/dottoplusplus-snowboard-1.1.1.deb`
  - `/var/mobile/dottoplusplus-1.1.1-rootless.deb`
- Reuse the current package controls for comparison:
  - `/var/mobile/com.nicksworks.dottoplusplus_1.1.1_iphoneos-arm64e-final-fixed.deb`
  - `/var/mobile/dotto-debug-roothide.deb`
- Reuse existing symbols and gates when profiling:
  - `DottoPlusPlusBadgeNeedsApply`
  - `DottoPlusPlusScheduleReapply`
  - `DottoPlusPlusCurrentBadgeViews`
  - `DottoPlusPlusAverageFolderColour`
  - `DottoPlusPlusApplyRootGeometry`
  - `-[SBIconBadgeView dottoPlusPlusApply]`
- Reuse the prior 43.7-second trace as historical evidence only; do not compare its debug call counts directly with a release capture without noting the configuration difference.

## Assumptions

- The user has stopped the unrelated tweak test before dotto++ runtime validation begins.
- Choicy continues to allow `dottoPlusPlus`, SnowBoard, and its required stub in SpringBoard.
- The user can explicitly install a selected `.deb` through their normal root-capable package workflow when asked; do not improvise with Filza or unavailable root helpers.
- The iPhone may remain disconnected from the Mac during package recovery. A Mac/device connection is required only when matched Time Profiler captures begin.
- The package/toolchain difference is the leading hypothesis, not a conclusion. The archived known-working reinstall is the deciding control.
- `development` remains the only working branch and `main` remains at `5414d10` until all runtime and performance gates pass.

## Steps

1. **Remove the abandoned constructor diagnostic from `Tweak.x`.**
   - Delete only the `#if DPP_BADGE_TRACE` block containing `os_log(OS_LOG_DEFAULT, "dotto++ constructor reached")` inside `%ctor`.
   - Expected result: `%ctor` begins by creating `dppBadgeViews`, matching tracked `HEAD`.

2. **Restore the tracked SpringBoard filter in `dottoPlusPlus.plist`.**
   - Replace the uncommitted bundle-plus-executable filter with `{ Filter = { Bundles = ( "com.apple.springboard" ); }; }`.
   - Expected result: the filter matches all previously documented working packages; no speculative filter behavior remains.

3. **Confirm that runtime source is exactly the final performance candidate.**
   - Run `git diff -- Tweak.x dottoPlusPlus.plist Makefile`.
   - Run `git diff --stat 83f709f..HEAD -- Tweak.x Makefile dottoPlusPlus.plist`.
   - Expected result: both commands produce no runtime/package-definition diff.

4. **Record the installed device identity before changing it.**
   - Record package status, architecture, installed dylib size/hash, support-library size/hash, tweak plist contents, and SpringBoard PID.
   - Record the hashes and control metadata of each candidate `.deb` on the device.
   - Expected result: the installed files can be mapped to one exact package artifact; no later visual result is attributed to an unknown binary.

5. **Compare known-working and inactive package products without installing either.**
   - For each control package, compare:
     - Debian architecture and dependencies.
     - Tweak and support-library archive paths.
     - Tweak plist encoding/content.
     - Mach-O slices and arm64e ABI capabilities.
     - `otool -L` install names and rpaths.
     - Code-signing metadata.
     - Tweak and support-library SHA-256 hashes.
   - Expected result: a compact matrix identifies every package-level variable; source changes are not mixed into this comparison.

6. **Stage and install the canonical RootHide control package with explicit user approval.**
   - Do not install the archived rootless control package on the RootHide target.
   - Use the published CI `iphoneos-arm64e` artifact from `https://hadobedo.github.io/repo/dev/debs/com.nicksworks.dottoplusplus_1.1.1_iphoneos-arm64e.deb`, expected SHA-256 `73a8e1e82234bb6d8f983c78cac8c47307865ef70a26fc43b020858a4709d996`.
   - Place the exact verified artifact at `/tmp/com.nicksworks.dottoplusplus_1.1.1_iphoneos-arm64e-ci.deb` on the target device, then use the user’s normal root-capable package installation method.
   - Restart SpringBoard once after installation.
   - Do not alter Choicy, SnowBoard, preferences, or other tweak state in the same step.
   - Expected result: either colored dot badges return, proving the canonical RootHide package loads in the current SpringBoard environment, or they do not, proving the failure remains in the RootHide runtime/package path.

7. **Verify the canonical RootHide control visually and functionally.**
   - Capture a Home Screen screenshot with at least one app and one folder badge.
   - Toggle dotto++ off and verify native/SnowBoard numeric badges return.
   - Toggle dotto++ on and verify colored dots return without a respring.
   - Open and close one badged folder and swipe one page in each direction.
   - Expected result: a binary pass/fail control with screenshots and no new SpringBoard crash report.

8. **Build current `HEAD` using the known-working rootless toolchain style.**
   - Use the regular Theos toolchain that produced the earlier rootless `PAC00` package, with `THEOS_PACKAGE_SCHEME=rootless`, `ARCHS="arm64 arm64e"`, and version `1.1.1`.
   - Build a debug package first for functional confirmation; run `EXPECTED_ARCH=iphoneos-arm64 scripts/verify_package.sh`.
   - Inspect the resulting slices, install names, signatures, and archive paths before installation.
   - Expected result: current source packaged with the known-working style, with no unexpected ABI/linker warning.

9. **Install and verify the current-HEAD rootless package.**
   - Install only after recording its exact hash and receiving user approval.
   - Repeat the checks from Step 7 without changing any other device setting.
   - Expected result:
     - If dots work, current runtime source is exonerated and the regression is package/toolchain-specific.
     - If dots fail, do not substitute a rootless package; proceed to Step 10 and isolate the canonical RootHide artifact/install path before bisecting source commits.

10. **Build a canonical current-HEAD RootHide package on macOS CI.**
    - Trigger or use the pinned GitHub Actions RootHide matrix artifact rather than the local Linux RootHide output that emitted incompatible arm64e ABI warnings.
    - Verify its archive layout, Mach-O slices, install names, signatures, and hashes against both the working rootless package and inactive local RootHide package.
    - Expected result: determine whether the discrepancy is local-toolchain-only or inherent to the RootHide scheme.

11. **Install and verify the canonical CI RootHide package.**
    - Install the exact hashed CI artifact, restart SpringBoard once, and repeat Step 7.
    - If it works, make the macOS/pinned CI artifact the release authority and add a verification guard preventing the invalid local output from being distributed.
    - If it fails while current-HEAD rootless works, isolate RootHide install-name/ABI/path handling before touching badge logic.
    - Expected result: a proven package/toolchain root cause and a reproducible RootHide build path.

12. **Only if package style is disproven, bisect runtime commits.**
    - Build package controls using one fixed, known-working toolchain at these boundaries:
      1. `86b5dc8` — initial deterministic SnowBoard overlay.
      2. `7a6120b` — layout-feedback prevention and documented working state.
      3. `9bb0ab0` — actual layer geometry writes.
      4. `84705e5` — folder-colour caching.
      5. `9cf1198`, `23bf189`, `83f709f` — performance gates.
    - Install one candidate at a time, record the installed hash, restart SpringBoard, and perform only the Step 7 pass/fail check.
    - Expected result: identify the first source commit that loses visible badge ownership without conflating package outputs.

13. **Create release builds for performance A/B only after current `HEAD` works.**
    - Build `FINALPACKAGE=1` from the working package/toolchain path.
    - Verify debug strings such as `dotto++ badge phase` and `after-root-geometry` are absent.
    - Keep code and package identical between A/B captures; change only `kEnabled`.
    - Expected result: profiling measures shipping behavior rather than trace overhead.

14. **Capture a matched disabled baseline when the iPhone is connected to the Mac.**
    - Attach Time Profiler to SpringBoard.
    - With dotto++ disabled, perform a fixed script: five left/right page cycles and five open/close cycles of the same badged folder.
    - Record trace duration, SpringBoard PID, package/dylib hash, SnowBoard state, and interaction timestamps.
    - Expected result: baseline frame-time and call-tree evidence for SpringBoard/SnowBoard without dotto++ ownership.

15. **Capture the matched enabled profile.**
    - Restart SpringBoard, enable dotto++, and repeat the identical interaction script and duration.
    - Expected result: an enabled trace directly comparable with Step 14.

16. **Attribute lag before changing code.**
    - Compare total CPU and hot-stack contribution for:
      - `layoutSubviews` hooks.
      - `_applyParallaxSettings` hooks.
      - `DottoPlusPlusBadgeNeedsApply`.
      - `DottoPlusPlusScheduleReapply` and `DottoPlusPlusCurrentBadgeViews`.
      - `DottoPlusPlusAverageFolderColour` and pixel/color extraction.
      - Overlay configuration and layer geometry writes.
    - Count only calls present in the release profile; do not infer from old debug logs alone.
    - Expected result: one measured dominant cost or a conclusion that lag lies outside dotto++.

17. **Implement one bounded performance fix.**
    - Change only the measured hot path in `Tweak.x` or the relevant color helper.
    - Preserve state restoration, SnowBoard overlay ownership, width-aware geometry, folder badge-membership semantics, and the no-timer/no-polling rule.
    - Expected result: a reviewable patch tied to profile evidence, not another broad reapply redesign.

18. **Rebuild and repeat the same A/B verification.**
    - Run strict rootless and RootHide builds, package verification, visual toggle/geometry checks, the same folder/page interaction script, and matched Time Profiler capture.
    - Expected result: lower dotto++ CPU/call count and visibly smoother interaction without badge regressions.

19. **Update `../docs/AUDIT.md` only with verified facts.**
    - Correct the chronology: working-but-laggy, package/runtime regression during profiling, control result, proven root cause, final package hashes, and post-fix profile evidence.
    - Keep iOS 15/16 marked build-supported but device-unverified.
    - Expected result: audit statements match exact artifacts and observed device behavior.

## Verification

### Workspace and source

- `git status --short`
  - Pass signal: only intended dotto++ files are modified; unrelated IconDance files remain untouched.
- `git diff --check`
  - Pass signal: no whitespace errors.
- `git diff --stat 83f709f..HEAD -- Tweak.x Makefile dottoPlusPlus.plist`
  - Pass signal before new fixes: no output.

### Builds and packages

- Rootless debug/current-source build using the known-working regular toolchain.
- Rootless and RootHide `FINALPACKAGE=1` builds using the chosen canonical toolchains.
- `EXPECTED_ARCH=iphoneos-arm64 scripts/verify_package.sh`
- `EXPECTED_ARCH=iphoneos-arm64e scripts/verify_package.sh`
  - Pass signal: version `1.1.1`, firmware bounds, bundle version, architecture, PreferenceLoader entry, and badge assets all verify.
- `strings <release tweak> | grep -E 'dotto\+\+ badge phase|after-root-geometry|constructor reached'`
  - Pass signal: no matches.
- `file`, `otool -L`, `codesign -dvvv`, and SHA-256 checks on each candidate binary.
  - Pass signal: output matches the package style proven to load on the device; no unresolved or unexpected dependency remains.

### Device functional control

- Installed package status reports `com.nicksworks.dottoplusplus 1.1.1` and the expected architecture.
- Installed tweak/support-library hashes match the selected `.deb`.
- Enabled screenshot shows colored dot badges on an application and folder.
- Disabled screenshot shows restored native/SnowBoard numeric badges.
- Re-enabling restores dots without a respring.
- Five page-swipe cycles and five folder open/close cycles complete without missing badges or a SpringBoard crash.

### Performance

- Disabled and enabled traces use the same release binary, SpringBoard lifecycle, SnowBoard state, duration, and interaction script.
- Pass signal for a fix: enabled dotto++ hot-path CPU/call counts decrease materially relative to the pre-fix enabled trace, and interaction is no longer visibly choppy.
- Idle capture contains no recurring dotto++ sweep, timer, or polling activity.

## Risks

- **SpringBoard instability:** A bad tweak build can cause a respring loop. Keep the archived known-working package available and use Choicy/safe mode to disable dotto++ before reinstalling the control package.
- **Same-version package ambiguity:** Every package is version `1.1.1`, so package-manager caches can obscure which binary is installed. Record archive and installed-file hashes after every installation.
- **Toolchain/ABI ambiguity:** `arm64e 00` versus `PAC00` is evidence, not by itself proof. Only an A/B install using otherwise identical source can establish causality.
- **Rootless-on-RootHide compatibility:** The older rootless package is a diagnostic control because it previously worked on this device; it is not automatically the final RootHide release solution.
- **Third-party interference:** Keep SnowBoard and Choicy state fixed during each A/B pair. If other SpringBoard tweaks change, discard the comparison and repeat it.
- **Profiling distortion:** Debug tracing materially increases work. Use `FINALPACKAGE=1` for lag conclusions and retain debug packages only for bounded functional diagnosis.
- **Rollback:** Reinstall the exact hashed archived control package, restore its bundle-only filter, restart SpringBoard, and verify dots/toggle behavior. Do not move `main` or publish a replacement until the recovery and performance gates pass.
