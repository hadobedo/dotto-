#import <Preferences/PSTableCell.h>

#import "DottoPreferences.h"

@class DottoColorRowStackView;

// The "Color" cell: two rows of swatches + custom picker, height 90.
@interface DottoColorSelectionTableCell : PSTableCell

@property (nonatomic, strong) DottoPreferences *preferences;
@property (nonatomic, strong) UIStackView *colorStackView;
@property (nonatomic, strong) DottoColorRowStackView *firstColorRow;
@property (nonatomic, strong) DottoColorRowStackView *secondColorRow;

- (instancetype)initWithSpecifier:(PSSpecifier *)specifier;
- (void)updateCircles;
- (double)preferredHeightForWidth:(double)width;

@end
