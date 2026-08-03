#import "DottoPlusPlusLinksListController.h"

static NSString *const DottoSourceURL = @"https://github.com/hadobedo/dotto-";
static NSString *const DottoTwitterURL = @"https://twitter.com/Nicks_Works";
static NSString *const DottoInstagramURL = @"https://instagram.com/Nicks_Works";
static NSString *const DottoYouTubeURL = @"https://www.youtube.com/@NicksWorks";

@implementation DottoPlusPlusLinksListController

- (instancetype)init {
    if ((self = [super init])) {
        self.title = @"Links";
    }
    return self;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [NSMutableArray array];
        [_specifiers addObject:[self linkSpecifier:@"Source on GitHub"
                                               key:@"kSource"
                                              icon:@"chevron.left.forwardslash.chevron.right"]];
        [_specifiers addObject:[self linkSpecifier:@"X (Twitter)"
                                               key:@"kTwitter"
                                              icon:@"at"]];
        [_specifiers addObject:[self linkSpecifier:@"Instagram"
                                               key:@"kInstagram"
                                              icon:@"camera"]];
        [_specifiers addObject:[self linkSpecifier:@"YouTube"
                                               key:@"kYouTube"
                                              icon:@"play.rectangle"]];
    }
    return _specifiers;
}

- (PSSpecifier *)linkSpecifier:(NSString *)name key:(NSString *)key icon:(NSString *)symbolName {
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:name
                                                            target:self
                                                               set:NULL
                                                               get:NULL
                                                            detail:nil
                                                              cell:PSLinkCell
                                                              edit:nil];
    [specifier setProperty:key forKey:@"key"];
    if (symbolName) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20
                                                                                            weight:UIImageSymbolWeightRegular];
        UIImage *icon = [[UIImage systemImageNamed:symbolName withConfiguration:config]
                         imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [specifier setProperty:icon forKey:PSIconImageKey];
    }
    return specifier;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    PSSpecifier *specifier = [self specifierAtIndexPath:indexPath];
    NSString *url = nil;
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:@"kSource"]) {
        url = DottoSourceURL;
    } else if ([key isEqualToString:@"kTwitter"]) {
        url = DottoTwitterURL;
    } else if ([key isEqualToString:@"kInstagram"]) {
        url = DottoInstagramURL;
    } else if ([key isEqualToString:@"kYouTube"]) {
        url = DottoYouTubeURL;
    }
    if (url) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]
                                           options:@{} completionHandler:nil];
    }
}

@end
