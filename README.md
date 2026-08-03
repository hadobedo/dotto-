# dotto++

Rootless adaptation/rewrite of **dotto+**, originally written by ConorTheDev & Mirac.
Tested and working on iOS 15-17 using rootless/roothide jailbreaks

## Changes/Fixes
- removed `libcolorpicker` dependency; uses the native
  iOS 14+ `UIColorPickerViewController`
- removed `libappearancecell` dependency; rebuilt selector in-bundle (`DottoPlusPlusAppearanceSelectionTableCell`)
- removed the `SBIconView _frameForAccessoryView:` hook (removed
  on iOS 17); kept `_centerForAccessoryView` and added `accessoryCenterForIconBounds:` positioning hook for iOS 17
- adjusted adaptive badge logic a bit; folder badges average the colours of the** apps that are
  currently showing a badge;** and the dominant-colour algorithm ignores near-black
  and near-white pixels so dark/white icon canvases don't win (e.g. TikTok
  gets its teal accents selected, not just black)

## Acknowledgements

- ConorTheDev & Mirac for the original dotto+ (original tweak, badge art, icons, overall concept) —
  [Dynastic archive](https://repo.dynastic.co/dotto),
  [Mirac](https://twitter.com/thatmirac), [ConorTheDev](https://github.com/ConorTheDev).
- [Simple Icons](https://simpleicons.org/) (MIT) for the brand marks used in the Links section.
- MTACS iOS-17-Runtime-Headers dump (iOS 17.1) for selector verification.
- RootHide's Theos fork and documentation.
- Rebuilt by [Nick's Works (me!)](https://twitter.com/Nicks_Works)
