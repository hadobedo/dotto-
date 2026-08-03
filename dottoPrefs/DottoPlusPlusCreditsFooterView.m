#import "DottoPlusPlusCreditsFooterView.h"

static NSString *const DottoTwitterURL = @"https://twitter.com/Nicks_Works";
static NSString *const DottoInstagramURL = @"https://instagram.com/Nicks_Works";
static NSString *const DottoYouTubeURL = @"https://www.youtube.com/@NicksWorks";
static NSString *const DottoSourceURL = @"https://github.com/hadobedo/dotto-";
static NSString *const DottoOriginalURL = @"https://repo.dynastic.co/dotto";

// HIG-style ABOUT & LINKS footer: an inset-grouped card of settings rows with
// leading SF Symbol icons and chevron affordances, a stacked developer-credits
// row, and a floating blurred dock with compact social handles.
@implementation DottoPlusPlusCreditsFooterView {
    UIStackView *_stackView;
}

- (instancetype)initWithSpecifier:(PSSpecifier *)specifier {
    if ((self = [super initWithFrame:CGRectZero])) {
        [self build];
    }
    return self;
}

- (void)build {
    _stackView = [[UIStackView alloc] init];
    _stackView.axis = UILayoutConstraintAxisVertical;
    _stackView.alignment = UIStackViewAlignmentFill;
    _stackView.distribution = UIStackViewDistributionFill;
    _stackView.spacing = 0;
    _stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_stackView];

    [NSLayoutConstraint activateConstraints:@[
        [_stackView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_stackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [_stackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
    ]];

    // Section header.
    UILabel *headerLabel = [[UILabel alloc] init];
    headerLabel.text = @"ABOUT & LINKS";
    headerLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    headerLabel.textColor = [UIColor secondaryLabelColor];
    headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_stackView addArrangedSubview:headerLabel];
    [headerLabel.leadingAnchor constraintEqualToAnchor:_stackView.leadingAnchor constant:0].active = YES;
    [headerLabel.topAnchor constraintEqualToAnchor:_stackView.topAnchor constant:8].active = YES;

    // Card container.
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 12;
    card.clipsToBounds = YES;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [_stackView addArrangedSubview:card];
    [card.topAnchor constraintEqualToAnchor:headerLabel.bottomAnchor constant:8].active = YES;

    UIStackView *rows = [[UIStackView alloc] init];
    rows.axis = UILayoutConstraintAxisVertical;
    rows.alignment = UIStackViewAlignmentFill;
    rows.spacing = 0;
    rows.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:rows];
    [NSLayoutConstraint activateConstraints:@[
        [rows.topAnchor constraintEqualToAnchor:card.topAnchor],
        [rows.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [rows.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [rows.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
    ]];

    // Row 1: source.
    UIButton *sourceRow = [self settingsRowWithIcon:@"chevron.left.forwardslash.chevron.right"
                                              title:@"Source on GitHub"
                                             action:@selector(openSource)];
    [rows addArrangedSubview:sourceRow];
    [sourceRow.heightAnchor constraintEqualToConstant:44].active = YES;

    [rows addArrangedSubview:[self separator]];

    // Row 2: developer credits (stacked title + subtitle), opens the original.
    UIButton *originalRow = [self creditsRowWithIcon:@"person.crop.circle"
                                               title:@"Original tweak (dotto+)"
                                            subtitle:@"by Mirac & ConorTheDev"
                                              action:@selector(openOriginal)];
    [rows addArrangedSubview:originalRow];
    [originalRow.heightAnchor constraintEqualToConstant:58].active = YES;

    [rows addArrangedSubview:[self separator]];

    // Row 3: source-of-truth duplicate avoided — row 3 is the author dock entry
    // instead: "Nick's Works" links to Twitter.
    UIButton *authorRow = [self settingsRowWithIcon:@"at"
                                              title:@"Nick's Works"
                                             action:@selector(openTwitter)];
    [rows addArrangedSubview:authorRow];
    [authorRow.heightAnchor constraintEqualToConstant:44].active = YES;

    // Floating social dock.
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    UIVisualEffectView *dock = [[UIVisualEffectView alloc] initWithEffect:blur];
    dock.layer.cornerRadius = 18;
    dock.clipsToBounds = YES;
    dock.translatesAutoresizingMaskIntoConstraints = NO;
    [_stackView addArrangedSubview:dock];
    [dock.topAnchor constraintEqualToAnchor:card.bottomAnchor constant:12].active = YES;
    [dock.heightAnchor constraintEqualToConstant:40].active = YES;

    UIStackView *socialRow = [[UIStackView alloc] init];
    socialRow.axis = UILayoutConstraintAxisHorizontal;
    socialRow.distribution = UIStackViewDistributionFillEqually;
    socialRow.alignment = UIStackViewAlignmentCenter;
    socialRow.translatesAutoresizingMaskIntoConstraints = NO;
    [dock.contentView addSubview:socialRow];
    [NSLayoutConstraint activateConstraints:@[
        [socialRow.topAnchor constraintEqualToAnchor:dock.contentView.topAnchor],
        [socialRow.leadingAnchor constraintEqualToAnchor:dock.contentView.leadingAnchor],
        [socialRow.trailingAnchor constraintEqualToAnchor:dock.contentView.trailingAnchor],
        [socialRow.bottomAnchor constraintEqualToAnchor:dock.contentView.bottomAnchor],
    ]];

    [socialRow addArrangedSubview:[self dockButtonWithSymbol:@"at"
                                                     handle:@"@Nicks_Works"
                                                     action:@selector(openTwitter)]];
    [socialRow addArrangedSubview:[self dockButtonWithSymbol:@"camera"
                                                     handle:@"@Nicks_Works"
                                                     action:@selector(openInstagram)]];
    [socialRow addArrangedSubview:[self dockButtonWithSymbol:@"play.rectangle"
                                                     handle:@"@NicksWorks"
                                                     action:@selector(openYouTube)]];

    [self.bottomAnchor constraintEqualToAnchor:dock.bottomAnchor constant:16].active = YES;
}

- (UIView *)separator {
    UIView *line = [[UIView alloc] init];
    line.backgroundColor = [UIColor separatorColor];
    line.translatesAutoresizingMaskIntoConstraints = NO;
    [line.heightAnchor constraintEqualToConstant:0.5].active = YES;
    return line;
}

// Standard settings row: leading mono icon, left-aligned title, chevron.
- (UIButton *)settingsRowWithIcon:(NSString *)symbolName title:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;

    UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(0, 16, 0, 16);
    configuration.title = title;
    configuration.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> * _Nonnull(
        NSDictionary<NSAttributedStringKey, id> * _Nonnull titleAttributes) {
        NSMutableDictionary *attributes = [titleAttributes mutableCopy];
        attributes[NSFontAttributeName] = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        attributes[NSForegroundColorAttributeName] = [UIColor labelColor];
        return attributes;
    };
    UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular];
    UIImage *icon = [[UIImage systemImageNamed:symbolName withConfiguration:symbolConfig]
                     imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    configuration.image = icon;
    configuration.imagePlacement = NSDirectionalRectEdgeLeading;
    configuration.imagePadding = 14;
    configuration.preferredSymbolConfigurationForImage = symbolConfig;
    button.configuration = configuration;

    UIImageView *chevron = [[UIImageView alloc] initWithImage:
                            [[UIImage systemImageNamed:@"chevron.right"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    chevron.tintColor = [UIColor tertiaryLabelColor];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    [button addSubview:chevron];
    [chevron.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:-16].active = YES;
    [chevron.centerYAnchor constraintEqualToAnchor:button.centerYAnchor].active = YES;

    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

// Developer credits row: stacked title + wrapped footnote subtitle.
- (UIButton *)creditsRowWithIcon:(NSString *)symbolName
                           title:(NSString *)title
                        subtitle:(NSString *)subtitle
                          action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor clearColor];
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageView *iconView = [[UIImageView alloc] initWithImage:
                             [[UIImage systemImageNamed:symbolName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    iconView.tintColor = [UIColor labelColor];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [button addSubview:iconView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    titleLabel.textColor = [UIColor labelColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [button addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.text = subtitle;
    subtitleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    subtitleLabel.textColor = [UIColor secondaryLabelColor];
    subtitleLabel.numberOfLines = 2;
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [button addSubview:subtitleLabel];

    UIImageView *chevron = [[UIImageView alloc] initWithImage:
                            [[UIImage systemImageNamed:@"chevron.right"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    chevron.tintColor = [UIColor tertiaryLabelColor];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    [button addSubview:chevron];

    [NSLayoutConstraint activateConstraints:@[
        [iconView.leadingAnchor constraintEqualToAnchor:button.leadingAnchor constant:16],
        [iconView.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:20],
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:14],
        [titleLabel.topAnchor constraintEqualToAnchor:button.topAnchor constant:9],
        [titleLabel.trailingAnchor constraintEqualToAnchor:chevron.leadingAnchor constant:-8],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:1],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:button.bottomAnchor constant:-7],
        [chevron.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:-16],
        [chevron.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
    ]];

    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

// Compact dock item: symbol + handle, evenly distributed.
- (UIButton *)dockButtonWithSymbol:(NSString *)symbolName handle:(NSString *)handle action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];

    UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
    configuration.title = handle;
    configuration.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> * _Nonnull(
        NSDictionary<NSAttributedStringKey, id> * _Nonnull titleAttributes) {
        NSMutableDictionary *attributes = [titleAttributes mutableCopy];
        attributes[NSFontAttributeName] = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
        return attributes;
    };
    UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightMedium];
    configuration.image = [[UIImage systemImageNamed:symbolName withConfiguration:symbolConfig]
                           imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    configuration.imagePlacement = NSDirectionalRectEdgeLeading;
    configuration.imagePadding = 6;
    configuration.preferredSymbolConfigurationForImage = symbolConfig;
    button.configuration = configuration;

    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)openTwitter {
    [self openURLString:DottoTwitterURL];
}

- (void)openInstagram {
    [self openURLString:DottoInstagramURL];
}

- (void)openYouTube {
    [self openURLString:DottoYouTubeURL];
}

- (void)openOriginal {
    [self openURLString:DottoOriginalURL];
}

- (void)openSource {
    [self openURLString:DottoSourceURL];
}

- (void)openURLString:(NSString *)urlString {
    NSURL *url = [NSURL URLWithString:urlString];
    if (url) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width {
    // Measure the stacked content instead of hardcoding a height.
    CGSize fit = [_stackView systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)];
    return fit.height + 4.0;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width inTableView:(UITableView *)tableView {
    return [self preferredHeightForWidth:width];
}

@end
