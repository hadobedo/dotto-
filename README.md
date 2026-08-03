# dotto++

Rootless adaptation/rewrite of **dotto+**, originally written by ConorTheDev & Mirac

## Changes vs the original

Summary:

- **Substrate → ElleKit** — packaged for the roothide scheme, with the same
  sources building for both **roothide (Dopamine/rootHide) and legacy
  rootless** via a CI matrix (`THEOS_PACKAGE_SCHEME` + `ROOT_PATH_NS` paths).
- **Preferences** — `CFPreferences` replaced with an `NSUserDefaults` suite on
  the same domain (`me.conorthedev.dotto.prefs`), so existing settings survive.
- **Colour picker** — removed the `libcolorpicker` dependency; uses the native
  iOS 14+ `UIColorPickerViewController` with in-bundle hex normalisation.
- **Appearance selector** — removed `libappearancecell`; rebuilt the same
  iOS 13-style selector in-bundle (`DottoPlusPlusAppearanceSelectionTableCell`).
- **Hooks** — removed the `SBIconView _frameForAccessoryView:` hook (removed
  from SpringBoard on iOS 17); kept `_centerForAccessoryView` and added the
  iOS 17 `accessoryCenterForIconBounds:` positioning hook.
- **Crash fix** — dropped the original's `setYellowTaps:` call, which was
  removed from `PSTableCell` on modern iOS and crashed the preferences pane.
- **SnowBoard coexistence** — badges re-assert their styling after each layout
  pass and clear the themed background colour, so SnowBoard theming no longer
  overrides dotto++.
- **Adaptive colour** — folder badges average the colours of the apps that are
  currently showing a badge; the dominant-colour algorithm ignores near-black
  and near-white pixels so dark/white icon canvases don't win (e.g. TikTok
  yields its teal accents, not black). Colours are cached per icon.
- **Badge rendering** — the badge art renders at its native size (crisp), and
  the dot position is derived from the icon width, so it hangs off the corner
  correctly on larger icons too.
- **Settings** — native "Credits & Source" section: "Nick's Works" opens a
  links subview (GitHub, X, Instagram, YouTube with real brand icons), and
  "Original tweak (dotto+)" links to the Dynastic archive.
- **Compatibility** — installs on iOS 15–17.x (firmware `<< 18.0`), arm64 +
  arm64e, rootless or RootHide/Dopamine with ElleKit.

## Acknowledgements

- ConorTheDev & Mirac for the original dotto+ (original tweak, badge art, icons, overall concept) —
  [Dynastic archive](https://repo.dynastic.co/dotto),
  [Mirac](https://twitter.com/thatmirac), [ConorTheDev](https://github.com/ConorTheDev).
- [Simple Icons](https://simpleicons.org/) (MIT) for the brand marks used in the Links section.
- MTACS iOS-17-Runtime-Headers dump (iOS 17.1) for selector verification.
- RootHide's Theos fork and documentation.
- Rebuilt by [Nick's Works (me!)](https://twitter.com/Nicks_Works)
