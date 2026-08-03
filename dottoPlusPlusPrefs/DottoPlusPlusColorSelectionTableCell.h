#import <Preferences/PSTableCell.h>

#import "DottoPlusPlusPreferences.h"

@class DottoPlusPlusColorRowStackView;

// The "Color" cell: two rows of swatches + custom picker, height 90.
@interface DottoPlusPlusColorSelectionTableCell : PSTableCell

@property (nonatomic, strong) DottoPlusPlusPreferences *preferences;
@property (nonatomic, strong) UIStackView *colorStackView;
@property (nonatomic, strong) DottoPlusPlusColorRowStackView *firstColorRow;
@property (nonatomic, strong) DottoPlusPlusColorRowStackView *secondColorRow;

- (instancetype)initWithSpecifier:(PSSpecifier *)specifier;
- (void)updateCircles;
- (double)preferredHeightForWidth:(double)width;

@end
