#import "DottoPlusPlusCreditsFooterView.h"

static NSString *const DottoTwitterURL = @"https://twitter.com/Nicks_Works";
static NSString *const DottoInstagramURL = @"https://instagram.com/Nicks_Works";
static NSString *const DottoYouTubeURL = @"https://www.youtube.com/@NicksWorks";
static NSString *const DottoSourceURL = @"https://github.com/hadobedo/dotto-";
static NSString *const DottoOriginalURL = @"https://repo.dynastic.co/dotto";

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
    _stackView.alignment = UIStackViewAlignmentCenter;
    _stackView.distribution = UIStackViewDistributionFill;
    _stackView.spacing = 8;
    _stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_stackView];

    [NSLayoutConstraint activateConstraints:@[
        [_stackView.topAnchor constraintEqualToAnchor:self.topAnchor constant:20],
        [_stackView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_stackView.widthAnchor constraintLessThanOrEqualToAnchor:self.widthAnchor constant:-32],
    ]];

    // App icon.
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"icon@3x.png"]];
    iconView.layer.cornerRadius = 16;
    iconView.clipsToBounds = YES;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [iconView.widthAnchor constraintEqualToConstant:72],
        [iconView.heightAnchor constraintEqualToConstant:72],
    ]];
    [_stackView addArrangedSubview:iconView];

    // Title + subtitle.
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"dotto+ for iOS 17";
    titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    titleLabel.textColor = [UIColor labelColor];
    [_stackView addArrangedSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.text = @"Rebuild by Nicks_Works";
    subtitleLabel.font = [UIFont systemFontOfSize:13];
    subtitleLabel.textColor = [UIColor secondaryLabelColor];
    [_stackView addArrangedSubview:subtitleLabel];

    // Social links.
    UIStackView *socialRow = [[UIStackView alloc] init];
    socialRow.axis = UILayoutConstraintAxisHorizontal;
    socialRow.alignment = UIStackViewAlignmentCenter;
    socialRow.spacing = 10;
    socialRow.translatesAutoresizingMaskIntoConstraints = NO;
    [socialRow addArrangedSubview:[self pillButtonWithTitle:@"Twitter"
                                                    action:@selector(openTwitter)]];
    [socialRow addArrangedSubview:[self pillButtonWithTitle:@"Instagram"
                                                    action:@selector(openInstagram)]];
    [socialRow addArrangedSubview:[self pillButtonWithTitle:@"YouTube"
                                                    action:@selector(openYouTube)]];
    [_stackView addArrangedSubview:socialRow];
    [socialRow.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:10].active = YES;

    // Original tweak credit.
    UIButton *originalButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [originalButton setTitle:@"Original dotto+ by Mirac & ConorTheDev" forState:UIControlStateNormal];
    originalButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [originalButton setImage:[UIImage systemImageNamed:@"chevron.right"] forState:UIControlStateNormal];
    originalButton.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [originalButton addTarget:self action:@selector(openOriginal) forControlEvents:UIControlEventTouchUpInside];
    [_stackView addArrangedSubview:originalButton];
    [originalButton.topAnchor constraintEqualToAnchor:socialRow.bottomAnchor constant:14].active = YES;

    UILabel *originalCaption = [[UILabel alloc] init];
    originalCaption.text = @"Mirac (@thatmirac) · ConorTheDev (@conrothedev)";
    originalCaption.font = [UIFont systemFontOfSize:11];
    originalCaption.textColor = [UIColor tertiaryLabelColor];
    [_stackView addArrangedSubview:originalCaption];

    // Source link.
    UIButton *sourceButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [sourceButton setTitle:@"Source on GitHub" forState:UIControlStateNormal];
    sourceButton.titleLabel.font = [UIFont systemFontOfSize:13];
    [sourceButton setImage:[UIImage systemImageNamed:@"chevron.right"] forState:UIControlStateNormal];
    sourceButton.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [sourceButton addTarget:self action:@selector(openSource) forControlEvents:UIControlEventTouchUpInside];
    [_stackView addArrangedSubview:sourceButton];

    // Footer note.
    UILabel *noteLabel = [[UILabel alloc] init];
    noteLabel.text = @"A respring is recommended after disabling.";
    noteLabel.font = [UIFont systemFontOfSize:12];
    noteLabel.textColor = [UIColor secondaryLabelColor];
    [_stackView addArrangedSubview:noteLabel];
    [noteLabel.topAnchor constraintEqualToAnchor:sourceButton.bottomAnchor constant:12].active = YES;
}

- (UIButton *)pillButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(7, 16, 7, 16);
    configuration.title = title;
    configuration.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> * _Nonnull(
        NSDictionary<NSAttributedStringKey, id> * _Nonnull titleAttributes) {
        NSMutableDictionary *attributes = [titleAttributes mutableCopy];
        attributes[NSFontAttributeName] = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        return attributes;
    };
    button.configuration = configuration;
    button.backgroundColor = [UIColor secondarySystemFillColor];
    button.layer.cornerRadius = 15;
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
    return 292;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width inTableView:(UITableView *)tableView {
    return [self preferredHeightForWidth:width];
}

@end
