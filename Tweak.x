// dotto+ — iOS 17 rebuild.
// Faithful port of dotto.dylib 1.0.6 (see ANALYSIS.md for the full decompilation).
// Changes for iOS 17:
//  - _frameForAccessoryView: hook removed (selector gone from SBIconView)
//  - accessoryCenterForIconBounds: hook added (iOS 17 accessory positioning protocol)
//  - stock restore uses a captured stock background image instead of the removed
//    backgroundImageTuple KVC path (which would throw NSUndefinedKeyException)

#import "DottoPrivate.h"

#import <objc/runtime.h>
#import <roothide.h>

#import "DottoPreferences.h"
#import "UIColor+dotto.h"

static NSMutableArray *dottoBadgeViews;
static DottoPreferences *dottoPrefs;
// SnowBoard (and other badge themers) may hook the same methods and load after
// dotto (alphabetical dylib order), so their changes win within a layout pass.
// Re-assert dotto once per pass on the next runloop turn to have the last word.
static BOOL dottoReapplyScheduled;

static NSString *const DottoReloadNotification = @"me.conorthedev.dotto/ReloadPrefs";
static NSString *const DottoNormalBadgePath =
    @"/Library/Application Support/dotto/badges/normal/SBBadgeBG@3x.png";
static NSString *const DottoCircleBadgePath =
    @"/Library/Application Support/dotto/badges/circle/SBBadgeBG@3x.png";

#pragma mark - Diagnostics (temporary, gated by DottoDebug prefs key)

// Debug builds log by default; set me.conorthedev.dotto.prefs DottoDebug=NO to silence.
static BOOL DottoDebugEnabled(void) {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"me.conorthedev.dotto.prefs"];
    if ([defaults objectForKey:@"DottoDebug"] == nil) {
        return YES;
    }
    return [defaults boolForKey:@"DottoDebug"];
}

#define DOTTOLOG(...) do { if (DottoDebugEnabled()) { \
    NSLog(@"[dotto+] " __VA_ARGS__); \
} } while (0)

#pragma mark - Badge art

// The shipped badge art occupies only the top-right corner of its 95x95 canvas
// (~36x36 px). Crop it to its opaque bounding box so the dot fills the frame.
static UIImage *DottoCroppedBadgeImage(NSString *path) {
    static NSMutableDictionary<NSString *, UIImage *> *cache = nil;
    if (!cache) {
        cache = [NSMutableDictionary dictionary];
    }
    UIImage *cached = cache[path];
    if (cached) {
        return cached;
    }
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    CGImageRef cgImage = image.CGImage;
    if (!cgImage) {
        return image;
    }
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *pixels = calloc(width * height * 4, sizeof(unsigned char));
    if (pixels) {
        CGContextRef ctx = CGBitmapContextCreate(pixels, width, height, 8, width * 4,
                                                 colorSpace, kCGImageAlphaPremultipliedLast);
        if (ctx) {
            CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), cgImage);
            size_t minX = width, minY = height, maxX = 0, maxY = 0;
            for (size_t y = 0; y < height; y++) {
                for (size_t x = 0; x < width; x++) {
                    if (pixels[(y * width + x) * 4 + 3] > 16) {
                        if (x < minX) minX = x;
                        if (x > maxX) maxX = x;
                        if (y < minY) minY = y;
                        if (y > maxY) maxY = y;
                    }
                }
            }
            CGContextRelease(ctx);
            if (maxX > minX && maxY > minY) {
                CGRect crop = CGRectMake(minX, minY, maxX - minX + 1, maxY - minY + 1);
                CGImageRef cropped = CGImageCreateWithImageInRect(cgImage, crop);
                if (cropped) {
                    UIImage *result = [UIImage imageWithCGImage:cropped
                                                          scale:image.scale
                                                    orientation:image.imageOrientation];
                    CGImageRelease(cropped);
                    cache[path] = result;
                    free(pixels);
                    CGColorSpaceRelease(colorSpace);
                    return result;
                }
            }
        }
        free(pixels);
    }
    CGColorSpaceRelease(colorSpace);
    cache[path] = image;
    return image;
}

#pragma mark - SBIconBadgeView associated state + new methods

static char const kDottoIsIconFolderKey;
static char const kDottoApplicationIconKey;
static char const kDottoInfoProviderKey;
static char const kDottoStockBackgroundImageKey;

// Declarations for methods implemented by %hook below (Logos emits no class
// interface for hooked classes) or defined in this category.
@interface SBIconBadgeView (Dotto)

@property (nonatomic, assign) BOOL dottoIsIconFolder;
@property (nonatomic, strong) SBApplicationIcon *dottoApplicationIcon;
@property (nonatomic, strong) id dottoInfoProvider;
@property (nonatomic, strong) UIImage *dottoStockBackgroundImage;

- (CGSize)badgeSize;
- (void)configureForIcon:(id)icon infoProvider:(id)provider;
- (UIColor *)dottoBadgeColour;
- (void)applyDotto;

@end

static void DottoScheduleReapply(void) {
    if (dottoReapplyScheduled) {
        return;
    }
    dottoReapplyScheduled = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        dottoReapplyScheduled = NO;
        for (SBIconBadgeView *badgeView in dottoBadgeViews) {
            [badgeView applyDotto];
        }
    });
}

static void DottoUpdateBadges(CFNotificationCenterRef center __unused,
                              void *observer __unused,
                              CFStringRef name __unused,
                              const void *object __unused,
                              CFDictionaryRef userInfo __unused) {
    @autoreleasepool {
        [dottoPrefs reloadPreferences];
        for (SBIconBadgeView *badgeView in dottoBadgeViews) {
            [badgeView applyDotto];
        }
        DottoScheduleReapply();
    }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation SBIconBadgeView (Dotto)

- (BOOL)dottoIsIconFolder {
    return [objc_getAssociatedObject(self, &kDottoIsIconFolderKey) boolValue];
}

- (void)setDottoIsIconFolder:(BOOL)dottoIsIconFolder {
    objc_setAssociatedObject(self, &kDottoIsIconFolderKey, @(dottoIsIconFolder),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (SBApplicationIcon *)dottoApplicationIcon {
    return objc_getAssociatedObject(self, &kDottoApplicationIconKey);
}

- (void)setDottoApplicationIcon:(SBApplicationIcon *)dottoApplicationIcon {
    objc_setAssociatedObject(self, &kDottoApplicationIconKey, dottoApplicationIcon,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)dottoInfoProvider {
    return objc_getAssociatedObject(self, &kDottoInfoProviderKey);
}

- (void)setDottoInfoProvider:(id)dottoInfoProvider {
    objc_setAssociatedObject(self, &kDottoInfoProviderKey, dottoInfoProvider,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIImage *)dottoStockBackgroundImage {
    return objc_getAssociatedObject(self, &kDottoStockBackgroundImageKey);
}

- (void)setDottoStockBackgroundImage:(UIImage *)dottoStockBackgroundImage {
    objc_setAssociatedObject(self, &kDottoStockBackgroundImageKey, dottoStockBackgroundImage,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// Adaptive colour: force-touch providers and providers without an icon image
// fall back to the user-selected colour; otherwise the icon image's dominant
// colour is used. Folders average the dominant colours of the apps inside them
// (their own contentsImage is nil on iOS 17).

// Average the dominant colour of every app icon inside a folder.
static UIColor *DottoAverageFolderColour(SBFolderIcon *folderIcon) {
    struct SBIconImageInfo info;
    info.size = CGSizeMake(60, 60);
    info.scale = 3.0;
    info.continuousCornerRadius = 20.45;
    CGFloat red = 0, green = 0, blue = 0;
    NSUInteger count = 0;
    for (SBIconListModel *list in folderIcon.folder.lists) {
        for (SBIcon *icon in list.icons) {
            if ([icon isKindOfClass:[SBFolderIcon class]]) {
                continue; // keep it simple: nested folders are skipped
            }
            UIImage *image = [icon iconImageWithInfo:info];
            if (!image) {
                continue;
            }
            UIColor *colour = [image dottoAverageColor];
            CGFloat r, g, b, a;
            if ([colour getRed:&r green:&g blue:&b alpha:&a]) {
                red += r;
                green += g;
                blue += b;
                count++;
            }
        }
    }
    if (count == 0) {
        return nil;
    }
    return [UIColor colorWithRed:red / count green:green / count blue:blue / count alpha:1.0];
}

- (UIColor *)dottoBadgeColour {
    if ([self.dottoApplicationIcon isKindOfClass:[SBFolderIcon class]]) {
        UIColor *folderAverage = DottoAverageFolderColour((SBFolderIcon *)self.dottoApplicationIcon);
        DOTTOLOG(@"badgeColour: folder average=%@", folderAverage);
        if (folderAverage) {
            return folderAverage;
        }
    }
    if ([self.dottoInfoProvider isKindOfClass:[SBForceTouchAppIconInfoProvider class]]) {
        DOTTOLOG(@"badgeColour: force-touch provider -> selected");
        return [dottoPrefs dottoSelectedColour];
    }
    UIView *imageView = [self.dottoInfoProvider valueForKey:@"iconImageView"];
    if ([imageView respondsToSelector:@selector(contentsImage)]) {
        UIImage *contentsImage = [(SBIconImageView *)imageView contentsImage];
        DOTTOLOG(@"badgeColour: icon=%@ provider=%@ imageView=%@ contents=%@",
                 self.dottoApplicationIcon, self.dottoInfoProvider, imageView, contentsImage);
        if (contentsImage) {
            UIColor *average = [contentsImage dottoAverageColor];
            DOTTOLOG(@"badgeColour: average=%@", average);
            return average;
        }
    }
    return [dottoPrefs dottoSelectedColour];
}

- (void)applyDotto {
    UIImageView *backgroundView = [self valueForKey:@"backgroundView"];
    UIImageView *textView = [self valueForKey:@"textView"];

    if (DottoDebugEnabled()) {
        static NSMutableSet *dumpedBadges = nil;
        if (!dumpedBadges) {
            dumpedBadges = [NSMutableSet set];
        }
        BOOL firstDump = ![dumpedBadges containsObject:@((uintptr_t)self)];
        if (firstDump) {
            [dumpedBadges addObject:@((uintptr_t)self)];
            NSMutableArray<NSString *> *siblings = [NSMutableArray array];
            for (UIView *sibling in self.superview.subviews) {
                [siblings addObject:[NSString stringWithFormat:@"%@(%@)hidden=%d alpha=%.2f",
                                     NSStringFromClass([sibling class]), NSStringFromCGRect(sibling.frame),
                                     sibling.hidden, sibling.alpha]];
            }
            NSMutableArray<NSString *> *badgeSublayers = [NSMutableArray array];
            for (CALayer *sublayer in self.layer.sublayers) {
                [badgeSublayers addObject:[NSString stringWithFormat:@"%@ contents=%@ bg=%@",
                                           NSStringFromClass([sublayer class]), sublayer.contents,
                                           sublayer.backgroundColor]];
            }
            NSMutableArray<NSString *> *ancestors = [NSMutableArray array];
            UIView *ancestor = self.superview;
            while (ancestor && ancestors.count < 6) {
                [ancestors addObject:[NSString stringWithFormat:@"%@(%@)", NSStringFromClass([ancestor class]),
                                      NSStringFromCGRect(ancestor.frame)]];
                ancestor = ancestor.superview;
            }
            DOTTOLOG(@"badge %p: subviews=[%@] siblings=[%@] sublayers=[%@] ancestors=[%@]",
                     self,
                     [[self.subviews valueForKey:@"description"] componentsJoinedByString:@","],
                     [siblings componentsJoinedByString:@","],
                     [badgeSublayers componentsJoinedByString:@","],
                     [ancestors componentsJoinedByString:@","]);
        }
        DOTTOLOG(@"applyDotto %p frame=%@ art=%@ tint=%@ alpha=%.2f enabled=%d branch=%@",
                 self, NSStringFromCGRect(self.frame), [backgroundView image],
                 [backgroundView tintColor], [backgroundView alpha], [dottoPrefs tweakEnabled],
                 ([self dottoIsIconFolder] || ![dottoPrefs adaptiveColorEnabled]) ? @"selected" : @"adaptive");
    }

    if (![dottoPrefs tweakEnabled]) {
        // Stock restore. The original read valueForKey:@"backgroundImageTuple",
        // which no longer exists on iOS 17; restore the captured stock image
        // instead (captured in the enabled path before replacement).
        if (self.dottoStockBackgroundImage) {
            [backgroundView setImage:self.dottoStockBackgroundImage];
        }
        [textView setHidden:NO];
        [textView setNeedsLayout];
        [backgroundView setNeedsLayout];
        return;
    }

    NSString *path = jbroot([dottoPrefs appearanceStyle] != 0 ? DottoCircleBadgePath
                                                               : DottoNormalBadgePath);
    UIImage *badgeImage = [DottoCroppedBadgeImage(path)
                           imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    DOTTOLOG(@"badge image: path=%@ exists=%d image=%@ layerContents=%@ textImageTuple=%@",
             path, [[NSFileManager defaultManager] fileExistsAtPath:path], badgeImage,
             self.layer.contents, [[self valueForKey:@"textImageTuple"] valueForKey:@"image"]);

    if (!self.dottoStockBackgroundImage) {
        self.dottoStockBackgroundImage = [backgroundView image];
    }
    [backgroundView setImage:badgeImage];

    UIColor *colour;
    if ([dottoPrefs adaptiveColorEnabled] && ![self dottoIsIconFolder]) {
        colour = [self dottoBadgeColour];
    } else {
        colour = [dottoPrefs dottoSelectedColour];
    }
    if ([dottoPrefs pastelColorsEnabled]) {
        colour = [colour lighterColor];
    }
    [backgroundView setTintColor:colour];
    // Render the badge art at its native point size (crisp, no upscaling);
    // the original stretched the art across a 26pt frame, which pixelates.
    CGSize artSize = badgeImage.size;
    if (artSize.width < 1.0 || artSize.height < 1.0) {
        artSize = CGSizeMake(26, 26);
    }
    [backgroundView setFrame:CGRectMake(0, 0, artSize.width, artSize.height)];
    // Original effective art position: canvas center (66.5, 27.5) of 95 -> 26pt
    // badge view => (18.2, 7.5); places the dot hanging off the icon corner.
    [backgroundView setCenter:CGPointMake(18.2, 7.5)];
    [backgroundView setAlpha:[dottoPrefs transparency]];
    [textView setHidden:YES];
    // Hide any other badge-internal rendering (themed stock pill, incoming
    // crossfade view, layer contents) so only our dot draws.
    self.layer.contents = nil;
    self.backgroundColor = [UIColor clearColor];
    for (UIView *subview in self.subviews) {
        if (subview != backgroundView) {
            [subview setHidden:YES];
        }
    }
    // SnowBoard themes the badge by painting the background view's background
    // colour (the red pill); clear it so only our tinted art draws.
    [backgroundView setBackgroundColor:[UIColor clearColor]];
    [backgroundView.layer setBackgroundColor:nil];
}

@end

#pragma clang diagnostic pop

#pragma mark - Hooks

%hook SBIconBadgeView

- (id)init {
    %orig;
    if (self) {
        if (!dottoBadgeViews) {
            dottoBadgeViews = [NSMutableArray new];
        }
        [dottoBadgeViews addObject:self];
    }
    return self;
}

- (void)dealloc {
    [dottoBadgeViews removeObject:self];
    %orig;
}

- (void)_applyParallaxSettings {
    %orig;
    [self applyDotto];
    DottoScheduleReapply();
}

- (CGRect)bounds {
    if ([dottoPrefs tweakEnabled]) {
        return CGRectMake(0, 0, 26, 26);
    }
    return %orig;
}

- (CGPoint)center {
    if ([dottoPrefs tweakEnabled]) {
        return CGPointMake(58, 2);
    }
    return %orig;
}

- (CGSize)badgeSize {
    if ([dottoPrefs tweakEnabled]) {
        return CGSizeMake(26, 26);
    }
    return %orig;
}

- (CGSize)sizeThatFits:(CGSize)size {
    if ([dottoPrefs tweakEnabled]) {
        return [self badgeSize];
    }
    return %orig;
}

- (CGSize)intrinsicContentSize {
    if ([dottoPrefs tweakEnabled]) {
        return [self badgeSize];
    }
    return %orig;
}

- (CGSize)intrinsicContentSizeForTextImage:(UIImage *)textImage {
    if (![dottoPrefs tweakEnabled]) {
        return %orig;
    }
    return CGSizeZero;
}

- (void)_resizeForTextImage:(UIImage *)image {
    if (![dottoPrefs tweakEnabled]) {
        %orig;
    }
}

- (void)_crossfadeToTextImage:(UIImage *)image animator:(id)animator {
    if (![dottoPrefs tweakEnabled]) {
        %orig;
    }
}

- (void)_zoomInWithTextImage:(UIImage *)image animator:(id)animator {
    if (![dottoPrefs tweakEnabled]) {
        %orig;
    }
}

- (void)layoutSubviews {
    %orig;
    [self applyDotto];
    DottoScheduleReapply();
}

- (void)configureAnimatedForIcon:(id)icon infoProvider:(id)provider animator:(id)animator {
    if ([dottoPrefs tweakEnabled]) {
        [self configureForIcon:icon infoProvider:provider];
    } else {
        %orig;
    }
}

- (void)configureForIcon:(id)icon infoProvider:(id)provider {
    %orig;
    DOTTOLOG(@"configureForIcon icon=%@ provider=%@", icon, provider);
    self.dottoApplicationIcon = icon;
    self.dottoInfoProvider = provider;
    [self applyDotto];
    DottoScheduleReapply();
}

// iOS 17 accessory positioning protocol method (stock badges position themselves
// via this); return the same corner point the original forced through
// _centerForAccessoryView on older iOS.
- (CGPoint)accessoryCenterForIconBounds:(CGRect)iconBounds {
    if ([dottoPrefs tweakEnabled]) {
        return CGPointMake(58, 2);
    }
    return %orig;
}

%end

%hook SBIconView

- (CGPoint)_centerForAccessoryView {
    if ([dottoPrefs tweakEnabled]) {
        return CGPointMake(58, 2);
    }
    return %orig;
}

%end

#pragma mark - Constructor

%ctor {
    @autoreleasepool {
        dottoBadgeViews = [NSMutableArray new];
        dottoPrefs = [DottoPreferences sharedInstance];
        [dottoPrefs reloadPreferences];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL, DottoUpdateBadges,
                                        (CFStringRef)DottoReloadNotification,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        DOTTOLOG(@"ctor: loaded, enabled=%d style=%ld adaptive=%d pastel=%d alpha=%.2f",
                 [dottoPrefs tweakEnabled], (long)[dottoPrefs appearanceStyle],
                 [dottoPrefs adaptiveColorEnabled], [dottoPrefs pastelColorsEnabled],
                 [dottoPrefs transparency]);
    }
}
