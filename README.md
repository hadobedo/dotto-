# dotto++

Rootless adaptation/rewrite of **dotto+**, originally written by ConorTheDev & Mirac 

## Changes vs the original

Summary:
- removed `libcolorpicker` dependancy, use native iOS 14+ `UIColorPickerViewController`
- removed `libappearancecell`, built in-bundle `DottoAppearanceSelectionTableCell`.
- removed `SBIconView _frameForAccessoryView:` hook as no longer present on iOS 14+; use `accessoryCenterForIconBounds:` positioning hook

## Acknowledgements

- ConorTheDev & Mirac for the original dotto+ (original tweak, badge art, icons, overall concept) —
  [Dynastic archive](https://repo.dynastic.co/dotto),
  [Mirac](https://twitter.com/thatmirac), [ConorTheDev](https://github.com/ConorTheDev).
- MTACS iOS-17-Runtime-Headers dump (iOS 17.1) for selector verification.
- RootHide's Theos fork and documentation.
- Rebuilt by [Nick's Works (me!)](https://twitter.com/Nicks_Works)
