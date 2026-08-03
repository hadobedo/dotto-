#import "DottoColorSelectionTableCell.h"

#import "DottoColorItemView.h"
#import "DottoColorRowStackView.h"
#import "DottoPrefsCompat.h"

#import <Preferences/PSSpecifier.h>

static const double kCellHeight = 90.0;

@implementation DottoColorSelectionTableCell

- (instancetype)initWithSpecifier:(PSSpecifier *)specifier {
    return [self initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil specifier:specifier];
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
                    specifier:(PSSpecifier *)specifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier])) {
        [self setYellowTaps:NO];

        self.preferences = [DottoPreferences sharedInstance];
        [self.preferences reloadPreferences];

        // First row: 6 colors.
        NSArray<UIColor *> *firstRowColors = @[
            [UIColor colorWithRed:232.0 / 255.0 green:53.0 / 255.0 blue:83.0 / 255.0 alpha:1.0],  // #E83553
            [UIColor colorWithRed:255.0 / 255.0 green:59.0 / 255.0 blue:48.0 / 255.0 alpha:1.0],  // #FF3B30
            [UIColor colorWithRed:255.0 / 255.0 green:149.0 / 255.0 blue:0.0 / 255.0 alpha:1.0],  // #FF9500
            [UIColor colorWithRed:255.0 / 255.0 green:204.0 / 255.0 blue:0.0 / 255.0 alpha:1.0],  // #FFCC00
            [UIColor colorWithRed:52.0 / 255.0 green:199.0 / 255.0 blue:89.0 / 255.0 alpha:1.0],  // #34C759
            [UIColor colorWithRed:90.0 / 255.0 green:200.0 / 255.0 blue:250.0 / 255.0 alpha:1.0], // #5AC8FA
        ];
        self.firstColorRow = [[DottoColorRowStackView alloc] initWithColors:firstRowColors
                                                              forController:self];

        // Second row: 5 colors + custom color picker (clear swatch).
        NSArray<UIColor *> *secondRowColors = @[
            [UIColor colorWithRed:0.0 / 255.0 green:122.0 / 255.0 blue:255.0 / 255.0 alpha:1.0],  // #007AFF
            [UIColor colorWithRed:175.0 / 255.0 green:82.0 / 255.0 blue:222.0 / 255.0 alpha:1.0], // #AF52DE
            [UIColor colorWithRed:255.0 / 255.0 green:45.0 / 255.0 blue:85.0 / 255.0 alpha:1.0],  // #FF2D55
            [UIColor whiteColor],
            [UIColor colorWithRed:17.0 / 255.0 green:17.0 / 255.0 blue:17.0 / 255.0 alpha:1.0],   // #111111
            [UIColor clearColor],
        ];
        self.secondColorRow = [[DottoColorRowStackView alloc] initWithColors:secondRowColors
                                                               forController:self];

        self.colorStackView = [[UIStackView alloc] init];
        self.colorStackView.axis = UILayoutConstraintAxisVertical;
        self.colorStackView.alignment = UIStackViewAlignmentCenter;
        self.colorStackView.distribution = UIStackViewDistributionFill;
        self.colorStackView.spacing = 10.0;
        self.colorStackView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.colorStackView addArrangedSubview:self.firstColorRow];
        [self.colorStackView addArrangedSubview:self.secondColorRow];
        [self.contentView addSubview:self.colorStackView];

        [NSLayoutConstraint activateConstraints:@[
            [self.colorStackView.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
            [self.colorStackView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [self.heightAnchor constraintEqualToConstant:kCellHeight],
        ]];
    }
    return self;
}

- (void)updateCircles {
    NSArray<DottoColorItemView *> *items = [self.firstColorRow.arrangedSubviews
                                            arrayByAddingObjectsFromArray:self.secondColorRow.arrangedSubviews];
    UIColor *selectedColour = [DottoColorRowStackView selectedColor];
    for (DottoColorItemView *item in items) {
        if (item.type == 1) {
            // Custom picker swatch: outlined when the selection is a custom color.
            if (![[DottoColorRowStackView standardColors] containsObject:selectedColour]) {
                if (![item.subviews containsObject:item.outlineView]) {
                    [item addOutlineView];
                }
            } else {
                [item.outlineView removeFromSuperview];
            }
        } else {
            if (![selectedColour isEqual:item.color]) {
                [item.outlineView removeFromSuperview];
            } else {
                if (![item.subviews containsObject:item.outlineView]) {
                    [item addOutlineView];
                }
            }
        }
    }
}

- (double)preferredHeightForWidth:(double)width {
    return kCellHeight;
}

- (double)preferredHeightForWidth:(double)width inTableView:(UITableView *)tableView {
    return [self preferredHeightForWidth:width];
}

@end
