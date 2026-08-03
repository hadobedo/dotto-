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
                                              icon:[self brandIconNamed:@"icon_github"]]];
        [_specifiers addObject:[self linkSpecifier:@"X (Twitter)"
                                               key:@"kTwitter"
                                              icon:[self brandIconNamed:@"icon_x"]]];
        [_specifiers addObject:[self linkSpecifier:@"Instagram"
                                               key:@"kInstagram"
                                              icon:[self brandIconNamed:@"icon_instagram"]]];
        [_specifiers addObject:[self linkSpecifier:@"YouTube"
                                               key:@"kYouTube"
                                              icon:[self brandIconNamed:@"icon_youtube"]]];
    }
    return _specifiers;
}

- (PSSpecifier *)linkSpecifier:(NSString *)name key:(NSString *)key icon:(UIImage *)icon {
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:name
                                                            target:self
                                                               set:NULL
                                                               get:NULL
                                                            detail:nil
                                                              cell:PSLinkCell
                                                              edit:nil];
    [specifier setProperty:key forKey:@"key"];
    if (icon) {
        [specifier setProperty:icon forKey:PSIconImageKey];
    }
    return specifier;
}

// Simple Icons brand marks (MIT) bundled as black-alpha PNGs; re-render them
// in system blue so they read as tappable links in both appearances.
- (UIImage *)brandIconNamed:(NSString *)name {
    UIImage *image = [UIImage imageNamed:name
                                 inBundle:[NSBundle bundleForClass:[self class]]
            compatibleWithTraitCollection:nil];
    if (!image) {
        return nil;
    }
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:image.size];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [image drawAtPoint:CGPointZero];
        CGContextSetBlendMode(context.CGContext, kCGBlendModeSourceIn);
        [[UIColor systemBlueColor] setFill];
        CGContextFillRect(context.CGContext, CGRectMake(0, 0, image.size.width, image.size.height));
    }];
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
