# Changelog

## 1.1.3

- Removed the iOS 18 firmware cap; dotto++ now installs on iOS 15 and above.
- iOS 18 support: `SBIconBadgeView`'s `_backgroundView` is a plain/material
  `UIView` there rather than an `SBDarkeningImageView`. `dottoPlusPlusApply`
  rejected anything that was not an image view, so nothing was drawn on 18.
  Any `UIView` is now accepted, and capture/restore only touch `.image` when
  the background really is an image view. (Based on PR #1 by Jond-ie.)
- Badge colour results are cached by icon artwork identity instead of being
  invalidated on every icon reconfiguration, so install-progress ticks no
  longer trigger a full icon re-render and average on the main thread.
- Folder colours are keyed by the backing `CGImage`, keeping cached colours
  valid across badge-count changes.
- Replaced the `@available(iOS 17.0, *)` check with a runtime
  `isOperatingSystemAtLeastVersion:` test; the clang-22 RootHide toolchain does
  not link compiler-rt, leaving `___isPlatformVersionAtLeast` unresolved at load.

## 1.1.1

- The dotto++ toggle and all settings should now work without a respring!
- “Dynamic” folder badge colours are now derived only from apps that currently have badges.
- Overhauled badge sizing and corner-placement logic.
- Fixed the dotto+ pastel toggle and added an optional alternative pastel algorithm (OKLab/OKLCH).
- Fixed SnowBoard behaviour; dotto++ should now properly override SnowBoard badges while enabled.
- Fixed erroneous badge reapplication logic introduced in v1.1.0.
- Fixed the colour picker from incorrectly becoming “un-greyed out” in dotto++ preferences.
- Other miscellaneous fixes.

## 1.1.0

- Initial (re)release for modern rootless and RootHide setups.
