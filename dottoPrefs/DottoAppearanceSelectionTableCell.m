#import "DottoAppearanceSelectionTableCell.h"

#import <Preferences/PSSpecifier.h>

#import "DottoPreferences.h"

static NSString *const kAppearanceStyle = @"kAppearanceStyle";

// Faithful reimplementation of the original me.conorthedev.libappearancecell
// AppearanceSelectionTableCell (iOS 13-style appearance selector): 60pt icon
// examples, 17pt captions, circle checkmark, haptics, direct pref write.
@interface DottoAppearanceTypeStackView : UIStackView
@property (nonatomic, assign) NSInteger type;
@property (nonatomic, weak) DottoAppearanceSelectionTableCell *hostController;
@property (nonatomic, strong) UIButton *checkmarkButton;
- (instancetype)initWithType:(NSInteger)type
               forController:(DottoAppearanceSelectionTableCell *)controller
                   withImage:(UIImage *)image
                     andText:(NSString *)text;
@end

@implementation DottoAppearanceTypeStackView

- (instancetype)initWithType:(NSInteger)type
               forController:(DottoAppearanceSelectionTableCell *)controller
                   withImage:(UIImage *)image
                     andText:(NSString *)text {
    if ((self = [super init])) {
        self.type = type;
        self.hostController = controller;

        self.axis = UILayoutConstraintAxisVertical;
        self.alignment = UIStackViewAlignmentCenter;
        self.distribution = UIStackViewDistributionEqualSpacing;
        self.spacing = 8;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.userInteractionEnabled = YES;

        UIImageView *iconView = [[UIImageView alloc] init];
        iconView.clipsToBounds = YES;
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        iconView.image = image;
        [self addArrangedSubview:iconView];
        [iconView.widthAnchor constraintEqualToConstant:60].active = YES;

        UILabel *captionLabel = [[UILabel alloc] init];
        captionLabel.text = text;
        [captionLabel setFont:[UIFont systemFontOfSize:17.0]];
        captionLabel.textColor = [UIColor labelColor];
        [captionLabel.heightAnchor constraintEqualToConstant:20].active = YES;
        [self addArrangedSubview:captionLabel];

        self.checkmarkButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.checkmarkButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self.checkmarkButton.heightAnchor constraintEqualToConstant:22].active = YES;
        [self.checkmarkButton.widthAnchor constraintEqualToConstant:22].active = YES;

        // UIKit's classic appearance-selector checkmark assets; fall back to
        // SF Symbols if the private assets are unavailable on this iOS.
        UIImage *uncheckedImage = [UIImage imageNamed:@"UIRemoveControlMultiNotCheckedImage.png"
                                              inBundle:[NSBundle bundleForClass:[UIView class]]
                         compatibleWithTraitCollection:nil];
        UIImage *checkedImage = [UIImage imageNamed:@"UITintedCircularButtonCheckmark.png"
                                            inBundle:[NSBundle bundleForClass:[UIView class]]
                       compatibleWithTraitCollection:nil];
        if (!uncheckedImage) {
            uncheckedImage = [UIImage systemImageNamed:@"circle"];
        }
        if (!checkedImage) {
            checkedImage = [UIImage systemImageNamed:@"checkmark.circle.fill"];
        }
        [self.checkmarkButton setImage:[uncheckedImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                              forState:UIControlStateNormal];
        [self.checkmarkButton setImage:[checkedImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                              forState:UIControlStateSelected];
        [self.checkmarkButton addTarget:self action:@selector(checkmarkTapped)
                       forControlEvents:UIControlEventTouchUpInside];
        [self addArrangedSubview:self.checkmarkButton];

        UILongPressGestureRecognizer *tap = [[UILongPressGestureRecognizer alloc]
                                             initWithTarget:self action:@selector(buttonTapped:)];
        tap.minimumPressDuration = 0;
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)buttonTapped:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        [UIView animateWithDuration:0.1 delay:0 options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{ self.alpha = 0.5; } completion:nil];
    } else if (sender.state == UIGestureRecognizerStateEnded) {
        [UIView animateWithDuration:0.1 delay:0 options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{ self.alpha = 1; } completion:nil];
        [self selectType];
    }
}

- (void)checkmarkTapped {
    // The checkmark is a visual affordance; tapping anywhere selects.
    [self selectType];
}

- (void)selectType {
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc]
                                           initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];
    [[DottoPreferences sharedInstance] writeValue:@(self.type) forKey:kAppearanceStyle];
    [self.hostController updateForType:self.type];
}

@end

@implementation DottoAppearanceSelectionTableCell {
    UIStackView *_containerStackView;
}

- (instancetype)initWithSpecifier:(PSSpecifier *)specifier {
    return [self initWithStyle:UITableViewCellStyleDefault
               reuseIdentifier:@"AppearanceSelectionTableCell"
                     specifier:specifier];
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
                    specifier:(PSSpecifier *)specifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier])) {
        NSArray<NSDictionary *> *options = [specifier propertyForKey:@"options"];
        if (!options) {
            options = @[
                @{ @"text" : @"dotto", @"image" : @"__dotto_ignore_normal" },
                @{ @"text" : @"dotto O's", @"image" : @"__dotto_ignore_circle" },
            ];
        }
        NSBundle *prefsBundle = [NSBundle bundleForClass:[self class]];

        _containerStackView = [[UIStackView alloc] init];
        _containerStackView.axis = UILayoutConstraintAxisHorizontal;
        _containerStackView.alignment = UIStackViewAlignmentCenter;
        _containerStackView.distribution = UIStackViewDistributionEqualSpacing;
        _containerStackView.spacing = 60;
        _containerStackView.translatesAutoresizingMaskIntoConstraints = NO;

        [options enumerateObjectsUsingBlock:^(NSDictionary *option, NSUInteger idx, BOOL *stop) {
            UIImage *image = [UIImage imageNamed:option[@"image"]
                                        inBundle:prefsBundle
                   compatibleWithTraitCollection:nil];
            DottoAppearanceTypeStackView *stack = [[DottoAppearanceTypeStackView alloc]
                                                   initWithType:(NSInteger)idx
                                                   forController:self
                                                       withImage:image
                                                         andText:option[@"text"]];
            [_containerStackView addArrangedSubview:stack];
            [stack.topAnchor constraintEqualToAnchor:_containerStackView.topAnchor constant:16].active = YES;
            [stack.bottomAnchor constraintEqualToAnchor:_containerStackView.bottomAnchor constant:-16].active = YES;
        }];

        [self.contentView addSubview:_containerStackView];
        [_containerStackView.heightAnchor constraintEqualToAnchor:self.heightAnchor].active = YES;
        [_containerStackView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor].active = YES;
        [_containerStackView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor].active = YES;

        [self updateForType:(NSInteger)[[DottoPreferences sharedInstance] appearanceStyle]];
    }
    return self;
}

- (void)updateForType:(NSInteger)type {
    for (DottoAppearanceTypeStackView *stack in _containerStackView.arrangedSubviews) {
        stack.checkmarkButton.selected = (stack.type == type);
        stack.checkmarkButton.tintColor = (stack.checkmarkButton.selected) ? [UIColor systemBlueColor]
                                                                            : [UIColor systemGrayColor];
    }
}

@end
