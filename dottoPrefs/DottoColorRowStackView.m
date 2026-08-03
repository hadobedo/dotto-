#import "DottoColorRowStackView.h"

#import "DottoColorItemView.h"
#import "DottoColorSelectionTableCell.h"

static NSArray<UIColor *> *dottoStandardColors;
static UIColor *dottoSelectedColor;

@implementation DottoColorRowStackView

+ (NSArray<UIColor *> *)standardColors {
    return dottoStandardColors;
}

+ (UIColor *)selectedColor {
    return dottoSelectedColor;
}

+ (void)setSelectedColor:(UIColor *)color {
    dottoSelectedColor = color;
}

- (instancetype)initWithColors:(NSArray<UIColor *> *)colors forController:(id)controller {
    if ((self = [super init])) {
        self.colorPicker = [NSClassFromString(@"UIColorPickerViewController") new];

        // The 11 standard colors (original __const table: iOS system palette +
        // white + dark gray). Shared globally; both rows contribute.
        dottoStandardColors = @[
            [UIColor colorWithRed:232.0 / 255.0 green:53.0 / 255.0 blue:83.0 / 255.0 alpha:1.0],  // #E83553
            [UIColor colorWithRed:255.0 / 255.0 green:59.0 / 255.0 blue:48.0 / 255.0 alpha:1.0],  // #FF3B30
            [UIColor colorWithRed:255.0 / 255.0 green:149.0 / 255.0 blue:0.0 / 255.0 alpha:1.0],  // #FF9500
            [UIColor colorWithRed:255.0 / 255.0 green:204.0 / 255.0 blue:0.0 / 255.0 alpha:1.0],  // #FFCC00
            [UIColor colorWithRed:52.0 / 255.0 green:199.0 / 255.0 blue:89.0 / 255.0 alpha:1.0],  // #34C759
            [UIColor colorWithRed:90.0 / 255.0 green:200.0 / 255.0 blue:250.0 / 255.0 alpha:1.0], // #5AC8FA
            [UIColor colorWithRed:0.0 / 255.0 green:122.0 / 255.0 blue:255.0 / 255.0 alpha:1.0],  // #007AFF
            [UIColor colorWithRed:175.0 / 255.0 green:82.0 / 255.0 blue:222.0 / 255.0 alpha:1.0], // #AF52DE
            [UIColor colorWithRed:255.0 / 255.0 green:45.0 / 255.0 blue:85.0 / 255.0 alpha:1.0],  // #FF2D55
            [UIColor whiteColor],
            [UIColor colorWithRed:17.0 / 255.0 green:17.0 / 255.0 blue:17.0 / 255.0 alpha:1.0],   // #111111
        ];

        self.axis = UILayoutConstraintAxisHorizontal;
        self.alignment = UIStackViewAlignmentCenter;
        self.hostController = controller;

        CGFloat screenWidth = CGRectGetWidth([UIScreen mainScreen].bounds);
        self.spacing = screenWidth / 6.0 - 30.0;

        for (UIColor *color in colors) {
            DottoColorItemView *item = [[DottoColorItemView alloc] initWithColor:color
                                                                   forController:self];
            [NSLayoutConstraint activateConstraints:@[
                [item.widthAnchor constraintEqualToConstant:30],
                [item.heightAnchor constraintEqualToConstant:30],
            ]];
            [self addArrangedSubview:item];
        }

        self.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [self.heightAnchor constraintEqualToConstant:30],
            [self.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        ]];
    }
    return self;
}

- (void)updateCircles {
    [self.hostController updateCircles];
}

@end
