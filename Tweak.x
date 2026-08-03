// dotto+ — iOS 17 rebuild.
// Faithful port of dotto.dylib 1.0.6 (see ANALYSIS.md for the full decompilation).
// Changes for iOS 17:
//  - _frameForAccessoryView: hook removed (selector gone from SBIconView)
//  - accessoryCenterForIconBounds: hook added (iOS 17 accessory positioning protocol)
//  - stock restore uses a captured stock background image instead of the removed
//    backgroundImageTuple KVC path (which would throw NSUndefinedKeyException)

#import "DottoPlusPlusPrivate.h"

#import <objc/runtime.h>
#import <roothide.h>

#import "DottoPlusPlusPreferences.h"
#import "UIColor+dottoPlusPlus.h"

static NSMutableArray *dppBadgeViews;
static DottoPlusPlusPreferences *dppPrefs;
// Adaptive colour cache: icon uniqueIdentifier -> colour. Computing the
// dominant colour scans pixels, so cache per icon and only recompute on
// preference reloads (badge/icon colours are stable within a session).
static NSMutableDictionary<NSString *, UIColor *> *dppColourCache;
// SnowBoard (and other badge themers) may hook the same methods and load after
// dotto (alphabetical dylib order), so their changes win within a layout pass.
// Re-assert dotto once per pass on the next runloop turn to have the last word.
static BOOL dppReapplyScheduled;

static NSString *const DottoReloadNotification = @"me.conorthedev.dotto/ReloadPrefs";
static NSString *const DottoNormalBadgePath =
    @"/Library/Application Support/dotto/badges/normal/SBBadgeBG@3x.png";
static NSString *const DottoCircleBadgePath =
    @"/Library/Application Support/dotto/badges/circle/SBBadgeBG@3x.png";

#pragma mark - Diagnostics (temporary, gated by DottoDebug prefs key)

// Debug builds log by default; set me.conorthedev.dotto.prefs DottoDebug=NO to silence.
static BOOL DottoPlusPlusDebugEnabled(void) {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"me.conorthedev.dotto.prefs"];
    return [defaults boolForKey:@"DottoDebug"];
}

#define DPP_LOG(...) do { if (DottoPlusPlusDebugEnabled()) { \
    NSLog(@"[dotto++] " __VA_ARGS__); \
} } while (0)

#pragma mark - Badge art

// The shipped badge art occupies only the top-right corner of its 95x95 canvas
// (~36x36 px). Crop it to its opaque bounding box so the dot fills the frame.
// Load a badge art image, crop it to its opaque bounding box, and return the
// art's center mapped into the 26x26 badge view (canvas center / canvas size
// * 26). Deriving the position from the art itself keeps the placement exact
// if the assets ever change.
static NSDictionary *DottoPlusPlusBadgeArt(NSString *path) {
    static NSMutableDictionary<NSString *, NSDictionary *> *cache = nil;
    if (!cache) {
        cache = [NSMutableDictionary dictionary];
    }
    NSDictionary *cached = cache[path];
    if (cached) {
        return cached;
    }
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    CGImageRef cgImage = image.CGImage;
    if (!cgImage) {
        NSDictionary *fallback = @{
            @"image" : image ?: [UIImage new],
            @"center" : [NSValue valueWithCGPoint:CGPointMake(13, 13)],
        };
        cache[path] = fallback;
        return fallback;
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
                    // Art center within the canvas, scaled into the 26pt badge view.
                    CGFloat centerX = (minX + maxX + 1) / 2.0 / (double)width * 26.0;
                    CGFloat centerY = (minY + maxY + 1) / 2.0 / (double)height * 26.0;
                    NSDictionary *art = @{
                        @"image" : result,
                        @"center" : [NSValue valueWithCGPoint:CGPointMake(centerX, centerY)],
                    };
                    cache[path] = art;
                    free(pixels);
                    CGColorSpaceRelease(colorSpace);
                    return art;
                }
            }
        }
        free(pixels);
    }
    CGColorSpaceRelease(colorSpace);
    NSDictionary *fallback = @{
        @"image" : image ?: [UIImage new],
        @"center" : [NSValue valueWithCGPoint:CGPointMake(13, 13)],
    };
    cache[path] = fallback;
    return fallback;
}

#pragma mark - SBIconBadgeView associated state + new methods

static char const kDottoPlusPlusIsIconFolderKey;
static char const kDottoPlusPlusApplicationIconKey;
static char const kDottoPlusPlusInfoProviderKey;
static char const kDottoPlusPlusStockBackgroundImageKey;

// Declarations for methods implemented by %hook below (Logos emits no class
// interface for hooked classes) or defined in this category.
@interface SBIconBadgeView (DottoPlusPlus)

@property (nonatomic, assign) BOOL dottoPlusPlusIsIconFolder;
@property (nonatomic, strong) SBApplicationIcon *dottoPlusPlusApplicationIcon;
@property (nonatomic, strong) id dottoPlusPlusInfoProvider;
@property (nonatomic, strong) UIImage *dottoPlusPlusStockBackgroundImage;

- (CGSize)badgeSize;
- (void)configureForIcon:(id)icon infoProvider:(id)provider;
- (UIColor *)dottoPlusPlusBadgeColour;
- (void)dottoPlusPlusApply;

@end

static void DottoPlusPlusScheduleReapply(void) {
    if (dppReapplyScheduled) {
        return;
    }
    dppReapplyScheduled = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        dppReapplyScheduled = NO;
        for (SBIconBadgeView *badgeView in dppBadgeViews) {
            [badgeView dottoPlusPlusApply];
        }
    });
}

static void DottoPlusPlusUpdateBadges(CFNotificationCenterRef center __unused,
                              void *observer __unused,
                              CFStringRef name __unused,
                              const void *object __unused,
                              CFDictionaryRef userInfo __unused) {
    @autoreleasepool {
        [dppPrefs reloadPreferences];
        [dppColourCache removeAllObjects];
        for (SBIconBadgeView *badgeView in dppBadgeViews) {
            [badgeView dottoPlusPlusApply];
        }
        DottoPlusPlusScheduleReapply();
    }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation SBIconBadgeView (DottoPlusPlus)

- (BOOL)dottoPlusPlusIsIconFolder {
    return [objc_getAssociatedObject(self, &kDottoPlusPlusIsIconFolderKey) boolValue];
}

- (void)setDottoPlusPlusIsIconFolder:(BOOL)dottoPlusPlusIsIconFolder {
    objc_setAssociatedObject(self, &kDottoPlusPlusIsIconFolderKey, @(dottoPlusPlusIsIconFolder),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (SBApplicationIcon *)dottoPlusPlusApplicationIcon {
    return objc_getAssociatedObject(self, &kDottoPlusPlusApplicationIconKey);
}

- (void)setDottoPlusPlusApplicationIcon:(SBApplicationIcon *)dottoPlusPlusApplicationIcon {
    objc_setAssociatedObject(self, &kDottoPlusPlusApplicationIconKey, dottoPlusPlusApplicationIcon,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)dottoPlusPlusInfoProvider {
    return objc_getAssociatedObject(self, &kDottoPlusPlusInfoProviderKey);
}

- (void)setDottoPlusPlusInfoProvider:(id)dottoPlusPlusInfoProvider {
    objc_setAssociatedObject(self, &kDottoPlusPlusInfoProviderKey, dottoPlusPlusInfoProvider,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIImage *)dottoPlusPlusStockBackgroundImage {
    return objc_getAssociatedObject(self, &kDottoPlusPlusStockBackgroundImageKey);
}

- (void)setDottoPlusPlusStockBackgroundImage:(UIImage *)dottoPlusPlusStockBackgroundImage {
    objc_setAssociatedObject(self, &kDottoPlusPlusStockBackgroundImageKey, dottoPlusPlusStockBackgroundImage,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// Adaptive colour: force-touch providers and providers without an icon image
// fall back to the user-selected colour; otherwise the icon image's dominant
// colour is used. Folders average the dominant colours of the apps inside them
// (their own contentsImage is nil on iOS 17).

// Folder badge colour: average the dominant colours of the contained apps that
// are currently showing a badge (per-app dominant colour with the dark/white
// extremes filtered). Falls back to the folder-art collage dominant colour when
// no badged app images resolve, then to the selected colour.
static UIImage *DottoPlusPlusRenderViewImage(UIView *view) {
    if (!view || CGRectIsEmpty(view.bounds)) {
        return nil;
    }
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, 0);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static UIColor *DottoPlusPlusAverageFolderColour(SBFolderIcon *folderIcon, UIView *folderImageView) {
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
            if (icon.badgeValue <= 0) {
                continue; // only apps currently showing a badge count
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
    if (count > 0) {
        return [UIColor colorWithRed:red / count green:green / count blue:blue / count alpha:1.0];
    }
    UIImage *folderArt = DottoPlusPlusRenderViewImage(folderImageView);
    if (folderArt) {
        return [folderArt dottoAverageColor];
    }
    return nil;
}

- (UIColor *)dottoPlusPlusBadgeColour {
    NSString *iconID = self.dottoPlusPlusApplicationIcon.uniqueIdentifier;
    UIColor *cached = iconID ? dppColourCache[iconID] : nil;
    if (cached) {
        return cached;
    }
    UIColor *colour = nil;
    if ([self.dottoPlusPlusApplicationIcon isKindOfClass:[SBFolderIcon class]]) {
        UIView *imageView = [self.dottoPlusPlusInfoProvider valueForKey:@"iconImageView"];
        colour = DottoPlusPlusAverageFolderColour((SBFolderIcon *)self.dottoPlusPlusApplicationIcon, imageView);
    } else if (![self.dottoPlusPlusInfoProvider isKindOfClass:[SBForceTouchAppIconInfoProvider class]]) {
        UIView *imageView = [self.dottoPlusPlusInfoProvider valueForKey:@"iconImageView"];
        if ([imageView respondsToSelector:@selector(contentsImage)]) {
            UIImage *contentsImage = [(SBIconImageView *)imageView contentsImage];
            if (contentsImage) {
                colour = [contentsImage dottoAverageColor];
            }
        }
    }
    if (!colour) {
        colour = [dppPrefs dottoSelectedColour];
    }
    if (iconID) {
        dppColourCache[iconID] = colour;
    }
    return colour;
}

- (void)dottoPlusPlusApply {
    UIImageView *backgroundView = [self valueForKey:@"backgroundView"];
    UIImageView *textView = [self valueForKey:@"textView"];

    if (DottoPlusPlusDebugEnabled()) {
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
            DPP_LOG(@"badge %p: subviews=[%@] siblings=[%@] sublayers=[%@] ancestors=[%@]",
                     self,
                     [[self.subviews valueForKey:@"description"] componentsJoinedByString:@","],
                     [siblings componentsJoinedByString:@","],
                     [badgeSublayers componentsJoinedByString:@","],
                     [ancestors componentsJoinedByString:@","]);
        }
        DPP_LOG(@"dottoPlusPlusApply %p frame=%@ art=%@ tint=%@ alpha=%.2f enabled=%d branch=%@",
                 self, NSStringFromCGRect(self.frame), [backgroundView image],
                 [backgroundView tintColor], [backgroundView alpha], [dppPrefs tweakEnabled],
                 ([self dottoPlusPlusIsIconFolder] || ![dppPrefs adaptiveColorEnabled]) ? @"selected" : @"adaptive");
    }

    if (![dppPrefs tweakEnabled]) {
        // Stock restore. The original read valueForKey:@"backgroundImageTuple",
        // which no longer exists on iOS 17; restore the captured stock image
        // instead (captured in the enabled path before replacement).
        if (self.dottoPlusPlusStockBackgroundImage) {
            [backgroundView setImage:self.dottoPlusPlusStockBackgroundImage];
        }
        [textView setHidden:NO];
        [textView setNeedsLayout];
        [backgroundView setNeedsLayout];
        return;
    }

    NSString *path = jbroot([dppPrefs appearanceStyle] != 0 ? DottoCircleBadgePath
                                                               : DottoNormalBadgePath);
    NSDictionary *badgeArt = DottoPlusPlusBadgeArt(path);
    UIImage *badgeImage = [badgeArt[@"image"]
                           imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    DPP_LOG(@"badge image: path=%@ exists=%d image=%@ layerContents=%@ textImageTuple=%@",
             path, [[NSFileManager defaultManager] fileExistsAtPath:path], badgeImage,
             self.layer.contents, [[self valueForKey:@"textImageTuple"] valueForKey:@"image"]);

    if (!self.dottoPlusPlusStockBackgroundImage) {
        self.dottoPlusPlusStockBackgroundImage = [backgroundView image];
    }
    [backgroundView setImage:badgeImage];

    UIColor *colour;
    if ([dppPrefs adaptiveColorEnabled] && ![self dottoPlusPlusIsIconFolder]) {
        colour = [self dottoPlusPlusBadgeColour];
    } else {
        colour = [dppPrefs dottoSelectedColour];
    }
    if ([dppPrefs pastelColorsEnabled]) {
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
    // Art center derived from the asset's own geometry (hangs the dot off the
    // icon corner, matching the original's effective placement).
    [backgroundView setCenter:[badgeArt[@"center"] CGPointValue]];
    [backgroundView setAlpha:[dppPrefs transparency]];
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
        if (!dppBadgeViews) {
            dppBadgeViews = [NSMutableArray new];
        }
        [dppBadgeViews addObject:self];
    }
    return self;
}

- (void)dealloc {
    [dppBadgeViews removeObject:self];
    %orig;
}

- (void)_applyParallaxSettings {
    %orig;
    [self dottoPlusPlusApply];
    DottoPlusPlusScheduleReapply();
}

- (CGRect)bounds {
    if ([dppPrefs tweakEnabled]) {
        return CGRectMake(0, 0, 26, 26);
    }
    return %orig;
}

- (CGPoint)center {
    if ([dppPrefs tweakEnabled]) {
        return CGPointMake(58, 2);
    }
    return %orig;
}

- (CGSize)badgeSize {
    if ([dppPrefs tweakEnabled]) {
        return CGSizeMake(26, 26);
    }
    return %orig;
}

- (CGSize)sizeThatFits:(CGSize)size {
    if ([dppPrefs tweakEnabled]) {
        return [self badgeSize];
    }
    return %orig;
}

- (CGSize)intrinsicContentSize {
    if ([dppPrefs tweakEnabled]) {
        return [self badgeSize];
    }
    return %orig;
}

- (CGSize)intrinsicContentSizeForTextImage:(UIImage *)textImage {
    if (![dppPrefs tweakEnabled]) {
        return %orig;
    }
    return CGSizeZero;
}

- (void)_resizeForTextImage:(UIImage *)image {
    if (![dppPrefs tweakEnabled]) {
        %orig;
    }
}

- (void)_crossfadeToTextImage:(UIImage *)image animator:(id)animator {
    if (![dppPrefs tweakEnabled]) {
        %orig;
    }
}

- (void)_zoomInWithTextImage:(UIImage *)image animator:(id)animator {
    if (![dppPrefs tweakEnabled]) {
        %orig;
    }
}

- (void)layoutSubviews {
    %orig;
    [self dottoPlusPlusApply];
    DottoPlusPlusScheduleReapply();
}

- (void)configureAnimatedForIcon:(id)icon infoProvider:(id)provider animator:(id)animator {
    if ([dppPrefs tweakEnabled]) {
        [self configureForIcon:icon infoProvider:provider];
    } else {
        %orig;
    }
}

- (void)configureForIcon:(id)icon infoProvider:(id)provider {
    %orig;
    DPP_LOG(@"configureForIcon icon=%@ provider=%@", icon, provider);
    self.dottoPlusPlusApplicationIcon = icon;
    self.dottoPlusPlusInfoProvider = provider;
    [self dottoPlusPlusApply];
    DottoPlusPlusScheduleReapply();
}

// iOS 17 accessory positioning protocol method (stock badges position themselves
// via this); return the same corner point the original forced through
// _centerForAccessoryView on older iOS.
- (CGPoint)accessoryCenterForIconBounds:(CGRect)iconBounds {
    if ([dppPrefs tweakEnabled]) {
        return CGPointMake(58, 2);
    }
    return %orig;
}

%end

%hook SBIconView

- (CGPoint)_centerForAccessoryView {
    if ([dppPrefs tweakEnabled]) {
        return CGPointMake(58, 2);
    }
    return %orig;
}

%end

#pragma mark - Constructor

%ctor {
    @autoreleasepool {
        dppBadgeViews = [NSMutableArray new];
        dppColourCache = [NSMutableDictionary dictionary];
        dppPrefs = [DottoPlusPlusPreferences sharedInstance];
        [dppPrefs reloadPreferences];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL, DottoPlusPlusUpdateBadges,
                                        (CFStringRef)DottoReloadNotification,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        DPP_LOG(@"ctor: loaded, enabled=%d style=%ld adaptive=%d pastel=%d alpha=%.2f",
                 [dppPrefs tweakEnabled], (long)[dppPrefs appearanceStyle],
                 [dppPrefs adaptiveColorEnabled], [dppPrefs pastelColorsEnabled],
                 [dppPrefs transparency]);
    }
}
