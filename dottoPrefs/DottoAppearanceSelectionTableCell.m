#import "DottoAppearanceSelectionTableCell.h"

#import <Preferences/PSSpecifier.h>

#import "DottoPreferences.h"

static NSString *const kAppearanceStyle = @"kAppearanceStyle";

@implementation DottoAppearanceSelectionTableCell {
    UIStackView *_optionsStack;
    NSMutableArray<UIButton *> *_optionButtons;
    NSArray<NSDictionary *> *_options;
}

- (instancetype)initWithSpecifier:(PSSpecifier *)specifier {
    return [self initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil specifier:specifier];
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
                    specifier:(PSSpecifier *)specifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier])) {
        _optionButtons = [NSMutableArray array];
        _options = [specifier propertyForKey:@"options"];
        if (!_options) {
            _options = @[
                @{ @"text" : @"dotto", @"image" : @"__dotto_ignore_normal" },
                @{ @"text" : @"dotto O's", @"image" : @"__dotto_ignore_circle" },
            ];
        }
        [self _buildOptions];
        [[DottoPreferences sharedInstance] reloadPreferences];
        [self _refreshSelection];
    }
    return self;
}

- (void)_buildOptions {
    _optionsStack = [[UIStackView alloc] init];
    _optionsStack.axis = UILayoutConstraintAxisHorizontal;
    _optionsStack.alignment = UIStackViewAlignmentCenter;
    _optionsStack.distribution = UIStackViewDistributionFillEqually;
    _optionsStack.spacing = 16;
    _optionsStack.translatesAutoresizingMaskIntoConstraints = NO;

    [_options enumerateObjectsUsingBlock:^(NSDictionary *option, NSUInteger idx, BOOL *stop __unused) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = (NSInteger)idx;
        button.translatesAutoresizingMaskIntoConstraints = NO;

        UIImageView *imageView = [[UIImageView alloc] init];
        imageView.image = [UIImage imageNamed:option[@"image"]];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.translatesAutoresizingMaskIntoConstraints = NO;
        [button addSubview:imageView];

        UILabel *label = [[UILabel alloc] init];
        label.text = option[@"text"];
        label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        label.textAlignment = NSTextAlignmentCenter;
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [button addSubview:label];

        UIImageView *checkmark = [[UIImageView alloc] init];
        checkmark.image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
        checkmark.contentMode = UIViewContentModeScaleAspectFit;
        checkmark.tag = 1001;
        checkmark.translatesAutoresizingMaskIntoConstraints = NO;
        [button addSubview:checkmark];

        [NSLayoutConstraint activateConstraints:@[
            [imageView.topAnchor constraintEqualToAnchor:button.topAnchor],
            [imageView.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
            [imageView.widthAnchor constraintEqualToConstant:124],
            [imageView.heightAnchor constraintEqualToConstant:110],
            [label.topAnchor constraintEqualToAnchor:imageView.bottomAnchor constant:6],
            [label.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
            [label.bottomAnchor constraintEqualToAnchor:button.bottomAnchor],
            [checkmark.topAnchor constraintEqualToAnchor:button.topAnchor constant:-4],
            [checkmark.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:4],
            [checkmark.widthAnchor constraintEqualToConstant:26],
            [checkmark.heightAnchor constraintEqualToConstant:26],
        ]];

        [button addTarget:self action:@selector(_optionTapped:)
         forControlEvents:UIControlEventTouchUpInside];
        [_optionsStack addArrangedSubview:button];
        [_optionButtons addObject:button];
    }];

    [self.contentView addSubview:_optionsStack];
    [NSLayoutConstraint activateConstraints:@[
        [_optionsStack.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [_optionsStack.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_optionsStack.widthAnchor constraintEqualToConstant:124 * 2 + 16],
        [_optionsStack.heightAnchor constraintEqualToConstant:138],
    ]];
}

- (void)_optionTapped:(UIButton *)button {
    [[DottoPreferences sharedInstance] writeValue:@(button.tag) forKey:kAppearanceStyle];
    [self _refreshSelection];
}

- (void)_refreshSelection {
    NSInteger selected = [[DottoPreferences sharedInstance] appearanceStyle];
    [_optionButtons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger idx, BOOL *stop __unused) {
        UIImageView *checkmark = [button viewWithTag:1001];
        checkmark.tintColor = [UIColor systemBlueColor];
        checkmark.hidden = ((NSInteger)idx != selected);
    }];
}

@end
