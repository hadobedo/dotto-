#import "DottoPlusPlusColorSelectionTableCell.h"

#import "DottoPlusPlusColorItemView.h"
#import "DottoPlusPlusColorRowStackView.h"

#import <Preferences/PSSpecifier.h>

static const double kCellHeight = 90.0;

@implementation DottoPlusPlusColorSelectionTableCell

- (instancetype)initWithSpecifier:(PSSpecifier *)specifier {
    return [self initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil specifier:specifier];
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
                    specifier:(PSSpecifier *)specifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier])) {
        self.preferences = [DottoPlusPlusPreferences sharedInstance];
        [self.preferences reloadPreferences];

        NSArray<UIColor *> *palette = [DottoPlusPlusColorRowStackView standardColors];
        NSArray<UIColor *> *firstRowColors = [palette subarrayWithRange:NSMakeRange(0, 6)];
        NSMutableArray<UIColor *> *secondRowColors = [[palette subarrayWithRange:NSMakeRange(6, 5)] mutableCopy];
        [secondRowColors addObject:[UIColor clearColor]];

        self.firstColorRow = [[DottoPlusPlusColorRowStackView alloc] initWithColors:firstRowColors
                                                                         forController:self];
        self.secondColorRow = [[DottoPlusPlusColorRowStackView alloc] initWithColors:secondRowColors
                                                                          forController:self];

        self.colorStackView = [[UIStackView alloc] init];
        self.colorStackView.axis = UILayoutConstraintAxisVertical;
        // Fill so the rows stretch to the cell width; the rows' EqualSpacing
        // distribution then derives the gaps from the actual width.
        self.colorStackView.alignment = UIStackViewAlignmentFill;
        self.colorStackView.distribution = UIStackViewDistributionFill;
        self.colorStackView.spacing = 10.0;
        self.colorStackView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.colorStackView addArrangedSubview:self.firstColorRow];
        [self.colorStackView addArrangedSubview:self.secondColorRow];
        [self.contentView addSubview:self.colorStackView];

        [NSLayoutConstraint activateConstraints:@[
            [self.colorStackView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:24],
            [self.colorStackView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-24],
            [self.colorStackView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            [self.colorStackView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10],
            [self.heightAnchor constraintEqualToConstant:kCellHeight],
        ]];
        [self updateAdaptiveColorEnabled:[self.preferences adaptiveColorEnabled]];
    }
    return self;
}

- (void)updateAdaptiveColorEnabled:(BOOL)adaptiveEnabled {
    BOOL enabled = !adaptiveEnabled;
    self.userInteractionEnabled = enabled;
    self.contentView.userInteractionEnabled = enabled;
    self.contentView.alpha = enabled ? 1.0 : 0.439216;
    self.colorStackView.userInteractionEnabled = enabled;

    for (DottoPlusPlusColorRowStackView *row in @[self.firstColorRow, self.secondColorRow]) {
        row.userInteractionEnabled = enabled;
        for (UIView *itemView in row.arrangedSubviews) {
            itemView.userInteractionEnabled = enabled;
            if ([itemView isKindOfClass:[DottoPlusPlusColorItemView class]]) {
                [(DottoPlusPlusColorItemView *)itemView updateAdaptiveColorEnabled:adaptiveEnabled];
            }
        }
    }
}

- (void)updateCircles {
    NSArray<DottoPlusPlusColorItemView *> *items = [self.firstColorRow.arrangedSubviews
                                            arrayByAddingObjectsFromArray:self.secondColorRow.arrangedSubviews];
    [self.preferences reloadPreferences];
    UIColor *selectedColour = [self.preferences dottoSelectedColour];
    for (DottoPlusPlusColorItemView *item in items) {
        if (item.type == 1) {
            // Custom picker swatch: outlined when the selection is a custom color.
            if (![[DottoPlusPlusColorRowStackView standardColors] containsObject:selectedColour]) {
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
