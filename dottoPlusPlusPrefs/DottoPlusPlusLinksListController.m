#import "DottoPlusPlusCreditCells.h"
#import "DottoPlusPlusLinksListController.h"
#import "DottoPlusPlusLocalization.h"

static NSString *const DottoSourceURL = @"https://github.com/hadobedo/dotto-";
static NSString *const DottoTwitterURL = @"https://twitter.com/Nicks_Works";
static NSString *const DottoInstagramURL = @"https://instagram.com/Nicks_Works";
static NSString *const DottoYouTubeURL = @"https://www.youtube.com/@NicksWorks";
static NSString *const DottoKoFiURL = @"https://ko-fi.com/nicksworks";

@implementation DottoPlusPlusLinksListController

- (instancetype)init {
    if ((self = [super init])) {
        self.title = DottoL(@"Links");
    }
    return self;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [NSMutableArray array];

        // Support section: source + Ko-fi.
        [_specifiers addObject:[self linkSpecifier:DottoL(@"dotto++ source on GitHub")
                                               key:@"kSource"
                                              icon:[self brandIconNamed:@"icon_github"]]];
        PSSpecifier *kofi = [self linkSpecifier:DottoL(@"Support future tweaks & updates!")
                                            key:@"kKoFi"
                                           icon:[self brandIconNamed:@"icon_kofi"]];
        // PSListController expects the cellClass property to be a Class object
        // (strings only work when read from plist specifiers).
        [kofi setProperty:[DottoPlusPlusSubtitleLinkCell class] forKey:PSCellClassKey];
        [kofi setProperty:DottoL(@"Buy me a tea!") forKey:@"subtitle"];
        [_specifiers addObject:kofi];

        // Social Links section.
        PSSpecifier *socialGroup = [PSSpecifier groupSpecifierWithName:DottoL(@"Social Links")];
        [socialGroup setProperty:DottoL(@"Got a tweak idea, or an older tweak you wish was "
                                                @"ported to modern iOS? Send it to me, I might "
                                                @"take a look!")
                          forKey:PSFooterTextGroupKey];
        [_specifiers addObject:socialGroup];
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
// at the standard 20pt settings-icon size in system blue so they read as
// tappable links in both appearances and match the other row icons.
- (UIImage *)brandIconNamed:(NSString *)name {
    UIImage *image = [UIImage imageNamed:name
                                 inBundle:[NSBundle bundleForClass:[self class]]
            compatibleWithTraitCollection:nil];
    if (!image) {
        return nil;
    }
    const CGFloat iconSize = 20.0;
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = [UIScreen mainScreen].scale;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc]
                                         initWithSize:CGSizeMake(iconSize, iconSize)
                                               format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGRect rect = CGRectMake(0, 0, iconSize, iconSize);
        [image drawInRect:rect];
        CGContextSetBlendMode(context.CGContext, kCGBlendModeSourceIn);
        [[UIColor systemBlueColor] setFill];
        CGContextFillRect(context.CGContext, rect);
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
    } else if ([key isEqualToString:@"kKoFi"]) {
        url = DottoKoFiURL;
    }
    if (url) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]
                                           options:@{} completionHandler:nil];
    }
}

@end
