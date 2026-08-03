#import "DottoPlusPlusCreditsFooterView.h"

static NSString *const DottoTwitterURL = @"https://twitter.com/Nicks_Works";
static NSString *const DottoInstagramURL = @"https://instagram.com/Nicks_Works";
static NSString *const DottoYouTubeURL = @"https://www.youtube.com/@NicksWorks";
static NSString *const DottoSourceURL = @"https://github.com/hadobedo/dotto-";
static NSString *const DottoOriginalURL = @"https://repo.dynastic.co/dotto";

// ABOUT & LINKS footer built from real UITableViewCells so the rows match the
// native settings cells above (grouped card fill, body text, native disclosure
// chevrons, hairline separators inset to the text).
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

    // Card container matching the native grouped cell fill.
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 10;
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
    UITableViewCell *sourceCell = [self settingsCellWithStyle:UITableViewCellStyleDefault
                                                        icon:@"chevron.left.forwardslash.chevron.right"
                                                       title:@"Source on GitHub"
                                                      action:@selector(openSource)];
    [rows addArrangedSubview:sourceCell];
    [sourceCell.heightAnchor constraintEqualToConstant:44].active = YES;

    [rows addArrangedSubview:[self separator]];

    // Row 2: author, presents the social links.
    UITableViewCell *authorCell = [self settingsCellWithStyle:UITableViewCellStyleDefault
                                                        icon:@"person.crop.circle"
                                                       title:@"By: Nick's Works"
                                                      action:@selector(openSocialMenu)];
    [rows addArrangedSubview:authorCell];
    [authorCell.heightAnchor constraintEqualToConstant:44].active = YES;

    [rows addArrangedSubview:[self separator]];

    // Row 3: original tweak with stacked author credit.
    UITableViewCell *originalCell = [self settingsCellWithStyle:UITableViewCellStyleSubtitle
                                                          icon:@"link"
                                                         title:@"Original tweak (dotto+)"
                                                      subtitle:@"by Mirac & ConorTheDev"
                                                        action:@selector(openOriginal)];
    [rows addArrangedSubview:originalCell];
    [originalCell.heightAnchor constraintEqualToConstant:58].active = YES;

    [self.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:16].active = YES;
}

- (UIView *)separator {
    // Container fills the row; the hairline is inset to the text (16 + 20 icon
    // + 14 gap), matching native separators.
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [container.heightAnchor constraintEqualToConstant:0.5].active = YES;
    UIView *line = [[UIView alloc] init];
    line.backgroundColor = [UIColor separatorColor];
    line.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:line];
    [NSLayoutConstraint activateConstraints:@[
        [line.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:50],
        [line.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [line.topAnchor constraintEqualToAnchor:container.topAnchor],
        [line.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];
    return container;
}

// Native-style settings cell with leading icon, title (and optional subtitle),
// disclosure chevron, and a full-size transparent tap target.
- (UITableViewCell *)settingsCellWithStyle:(UITableViewCellStyle)style
                                      icon:(NSString *)symbolName
                                     title:(NSString *)title
                                  subtitle:(NSString *)subtitle
                                    action:(SEL)action {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.textLabel.text = title;
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.textLabel.textColor = [UIColor labelColor];
    if (subtitle) {
        cell.detailTextLabel.text = subtitle;
        cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        cell.detailTextLabel.numberOfLines = 2;
    }
    UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular];
    cell.imageView.image = [[UIImage systemImageNamed:symbolName withConfiguration:symbolConfig]
                            imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    cell.imageView.tintColor = [UIColor labelColor];
    cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.translatesAutoresizingMaskIntoConstraints = NO;

    UIButton *tap = [UIButton buttonWithType:UIButtonTypeCustom];
    tap.backgroundColor = [UIColor clearColor];
    tap.translatesAutoresizingMaskIntoConstraints = NO;
    [tap addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [cell addSubview:tap];
    [NSLayoutConstraint activateConstraints:@[
        [tap.topAnchor constraintEqualToAnchor:cell.topAnchor],
        [tap.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor],
        [tap.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor],
        [tap.bottomAnchor constraintEqualToAnchor:cell.bottomAnchor],
    ]];
    return cell;
}

- (UITableViewCell *)settingsCellWithStyle:(UITableViewCellStyle)style
                                      icon:(NSString *)symbolName
                                     title:(NSString *)title
                                    action:(SEL)action {
    return [self settingsCellWithStyle:style icon:symbolName title:title subtitle:nil action:action];
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
    return [UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action __unused) {
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
