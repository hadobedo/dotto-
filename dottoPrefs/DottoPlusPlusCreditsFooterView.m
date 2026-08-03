#import "DottoPlusPlusCreditsFooterView.h"

static NSString *const DottoTwitterURL = @"https://twitter.com/Nicks_Works";
static NSString *const DottoInstagramURL = @"https://instagram.com/Nicks_Works";
static NSString *const DottoYouTubeURL = @"https://www.youtube.com/@NicksWorks";
static NSString *const DottoSourceURL = @"https://github.com/hadobedo/dotto-";
static NSString *const DottoOriginalURL = @"https://repo.dynastic.co/dotto";

// HIG-style ABOUT & LINKS footer: an inset-grouped card of settings rows with
// consistently sized SF Symbol icons, hairline separators, and a disclosure
// chevron on each row. "By: Nick's Works" presents the social links in an
// action sheet.
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
    [headerLabel.leadingAnchor constraintEqualToAnchor:_stackView.leadingAnchor].active = YES;
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
    UIView *sourceRow = [self settingsRowWithIcon:@"chevron.left.forwardslash.chevron.right"
                                            title:@"Source on GitHub"
                                           action:@selector(openSource)];
    [rows addArrangedSubview:sourceRow];
    [sourceRow.heightAnchor constraintEqualToConstant:44].active = YES;

    [rows addArrangedSubview:[self separator]];

    // Row 2: author, presents the social links.
    UIView *authorRow = [self settingsRowWithIcon:@"person.crop.circle"
                                            title:@"By: Nick's Works"
                                           action:@selector(openSocialMenu)];
    [rows addArrangedSubview:authorRow];
    [authorRow.heightAnchor constraintEqualToConstant:44].active = YES;

    [rows addArrangedSubview:[self separator]];

    // Row 3: original tweak with stacked author credit.
    UIView *originalRow = [self creditsRowWithIcon:@"link"
                                             title:@"Original tweak (dotto+)"
                                          subtitle:@"by Mirac & ConorTheDev"
                                            action:@selector(openOriginal)];
    [rows addArrangedSubview:originalRow];
    [originalRow.heightAnchor constraintEqualToConstant:58].active = YES;

    [self.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:16].active = YES;
}

- (UIView *)separator {
    UIView *line = [[UIView alloc] init];
    line.backgroundColor = [UIColor separatorColor];
    line.translatesAutoresizingMaskIntoConstraints = NO;
    [line.heightAnchor constraintEqualToConstant:0.5].active = YES;
    return line;
}

// Standard settings row: fixed-size leading icon, left title, chevron.
- (UIView *)settingsRowWithIcon:(NSString *)symbolName title:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor clearColor];
    button.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular];
    UIImageView *iconView = [[UIImageView alloc] initWithImage:
                             [[UIImage systemImageNamed:symbolName withConfiguration:symbolConfig]
                              imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    iconView.tintColor = [UIColor labelColor];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [button addSubview:iconView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    titleLabel.textColor = [UIColor labelColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [button addSubview:titleLabel];

    UIImageView *chevron = [[UIImageView alloc] initWithImage:
                            [[UIImage systemImageNamed:@"chevron.right"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    chevron.tintColor = [UIColor tertiaryLabelColor];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    [button addSubview:chevron];

    [NSLayoutConstraint activateConstraints:@[
        [iconView.leadingAnchor constraintEqualToAnchor:button.leadingAnchor constant:16],
        [iconView.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:20],
        [iconView.heightAnchor constraintEqualToConstant:20],
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:14],
        [titleLabel.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:chevron.leadingAnchor constant:-8],
        [chevron.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:-16],
        [chevron.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
    ]];

    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

// Developer credits row: stacked title + wrapped footnote subtitle.
- (UIView *)creditsRowWithIcon:(NSString *)symbolName
                         title:(NSString *)title
                      subtitle:(NSString *)subtitle
                        action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor clearColor];
    button.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageView *iconView = [[UIImageView alloc] initWithImage:
                             [[UIImage systemImageNamed:symbolName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    iconView.tintColor = [UIColor labelColor];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
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
        [iconView.heightAnchor constraintEqualToConstant:20],
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

- (void)openSocialMenu {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"By: Nick's Works"
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[self actionWithTitle:@"Twitter" urlString:DottoTwitterURL]];
    [sheet addAction:[self actionWithTitle:@"Instagram" urlString:DottoInstagramURL]];
    [sheet addAction:[self actionWithTitle:@"YouTube" urlString:DottoYouTubeURL]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

    UIViewController *presenter = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]] &&
            scene.activationState == UISceneActivationStateForegroundActive) {
            presenter = [(UIWindowScene *)scene keyWindow].rootViewController;
            if (presenter) {
                break;
            }
        }
    }
    while (presenter.presentedViewController) {
        presenter = presenter.presentedViewController;
    }
    if (presenter) {
        [presenter presentViewController:sheet animated:YES completion:nil];
    }
}

- (UIAlertAction *)actionWithTitle:(NSString *)title urlString:(NSString *)urlString {
    return [UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self openURLString:urlString];
    }];
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
