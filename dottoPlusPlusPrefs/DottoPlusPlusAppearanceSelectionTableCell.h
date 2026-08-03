#import <Preferences/PSTableCell.h>

// Appearance picker ("dotto" / "dotto O's"). In-bundle replacement for the
// original me.conorthedev.libappearancecell AppearanceSelectionTableCell,
// which has no roothide-compatible release.
@interface DottoPlusPlusAppearanceSelectionTableCell : PSTableCell

- (instancetype)initWithSpecifier:(PSSpecifier *)specifier;
- (void)updateForType:(NSInteger)type;

@end
