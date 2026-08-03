# dotto++

A rootless adaptation of **dotto+ 1.0.6**
by ConorTheDev & Mirac — notification badges, your style: circle or rounded
badges tinted with a selected or icon-adaptive colour, no text.

This is a from-scratch reimplementation (internal codename **DottoPlusPlus**)
of the original 2020 binary, targeting iOS 17.1 / iPhone arm64e / RootHide with
ElleKit. It is built with the same pinned RootHide Theos fork and CI flow as
[nuGriddy](https://github.com/hadobedo/nuGriddy).

## Features (rebuilt)

- Two badge appearances: **dotto** (rounded) and **dotto O's** (circle).
- **Adaptive Colour**: badges take the dominant color of the app icon
  (folder icons and force-touch providers fall back to the selected color).
- **Use Pastel Colours**: lightens the badge color.
- Selected colour picker with 11 standard colours + system colour picker (iOS 14+).
- **Opacity** slider (10–100%).
- Global enable switch in the Settings navigation bar.
- Live updates via the `me.conorthedev.dotto/ReloadPrefs` Darwin notification.

## Requirements

- iPhone on iOS 15–17.x (arm64/arm64e), rootless or RootHide/Dopamine with ElleKit.
- `preferenceloader` for the Settings pane.

## Build

macOS/Xcode with the pinned RootHide Theos fork (CI builds on `macos-15`,
see `.github/workflows/build.yml`):

```sh
THEOS="$HOME/roothide-theos" make clean package PACKAGE_VERSION=1.0.6+ios17.0
```

Linux cannot build the package (no iOS toolchain); use the GitHub Actions
workflow, then download the `.deb` artifact from the run page.

## Install / test

1. Install the `.deb` with Sileo or `dpkg -i` (root):
   ```sh
   dpkg -i me.conorthedev.dotto+_1.0.6+ios17.0_iphoneos-arm64e.deb
   ```
2. Respring. The tweak is enabled by default (`kEnabled` unset = YES).
3. Settings → dotto+ to adjust appearance/color/opacity.
4. Toggle the switch in the nav bar to disable/re-enable without uninstalling.
   A respring is recommended after disabling (as the original advised).

Preferences live in `me.conorthedev.dotto.prefs` (same domain as the original).

## Device safety boundary

This is a development rebuild. Before installing: preserve your Home Screen
state, verify RootHide safe mode works, record the package SHA-256, and review
the exact artifact. If SpringBoard crashes, disable the tweak via RootHide /
safe mode.

## iOS 17 changes vs the original

Summary:

- MobileSubstrate → **ElleKit**; package scheme **roothide**, arm64e.
- `CFPreferences` → `NSUserDefaults` suite (same domain/plist).
- `libcolorpicker` → native `UIColorPickerViewController` + in-bundle hex
  normalization.
- `libappearancecell` → in-bundle `DottoAppearanceSelectionTableCell`.
- Dropped the removed `SBIconView _frameForAccessoryView:` hook; added the
  iOS 17 `accessoryCenterForIconBounds:` positioning hook (same geometry).
- The disabled-state restore path no longer reads the removed
  `backgroundImageTuple` key (would throw `NSUndefinedKeyException` on iOS 17);
  it restores a captured stock background image instead.

## Acknowledgements

- ConorTheDev & Mirac for the original dotto+ (badge art and concept) —
  [Dynastic archive](https://repo.dynastic.co/dotto),
  [Mirac](https://twitter.com/thatmirac), [ConorTheDev](https://github.com/ConorTheDev).
- MTACS iOS-17-Runtime-Headers dump (iOS 17.1) for selector verification.
- RootHide's Theos fork and documentation.
- Rebuild by [Nicks_Works](https://twitter.com/Nicks_Works) —
  [Instagram](https://instagram.com/Nicks_Works) · [YouTube](https://www.youtube.com/@NicksWorks).
