#import "DottoPlusPlusColorRowStackView.h"

#import "DottoPlusPlusColorItemView.h"
#import "DottoPlusPlusColorSelectionTableCell.h"

static NSArray<UIColor *> *dppStandardColors;
static UIColor *dppSelectedColor;

@implementation DottoPlusPlusColorRowStackView

+ (NSArray<UIColor *> *)standardColors {
    return dppStandardColors;
}

+ (UIColor *)selectedColor {
    return dppSelectedColor;
}

+ (void)setSelectedColor:(UIColor *)color {
    dppSelectedColor = color;
}

- (instancetype)initWithColors:(NSArray<UIColor *> *)colors forController:(id)controller {
    if ((self = [super init])) {
        self.colorPicker = [NSClassFromString(@"UIColorPickerViewController") new];

        // The 11 standard colors (original __const table: iOS system palette +
        // white + dark gray). Shared globally; both rows contribute.
        dppStandardColors = @[
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
        // Even gaps with 16pt side margins: (width - 2*16 - 6*30) / 5.
        self.spacing = (screenWidth - 32.0 - 180.0) / 5.0;

        for (UIColor *color in colors) {
            DottoPlusPlusColorItemView *item = [[DottoPlusPlusColorItemView alloc] initWithColor:color
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
