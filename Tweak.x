// dotto+ — iOS 17 rebuild.
// Faithful port of dotto.dylib 1.0.6 (see docs/ANALYSIS.md for the full decompilation).
// Changes for iOS 17:
//  - _frameForAccessoryView: hook removed (selector gone from SBIconView)
//  - accessoryCenterForIconBounds: hook added conditionally for iOS 17
//  - stock restore captures and restores all dotto-owned view state instead of
//    relying on the removed backgroundImageTuple KVC path

#import "DottoPlusPlusPrivate.h"

#import <objc/runtime.h>
#import <math.h>
#import <rootless.h>

#import "DottoPlusPlusPreferences.h"
#import "UIColor+dottoPlusPlus.h"

static NSHashTable<SBIconBadgeView *> *dppBadgeViews;
static DottoPlusPlusPreferences *dppPrefs;
// Adaptive colour cache: icon uniqueIdentifier -> colour. Computing the
// dominant colour scans pixels, so cache per icon and only recompute on
// preference reloads (badge/icon colours are stable within a session).
static NSMutableDictionary<NSString *, UIColor *> *dppColourCache;
// Folder colours depend on the current set of badged apps. Cache only by a
// signature of that set; preference/icon reconfiguration clears this cache.
static NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *dppFolderColourCache;
// SnowBoard (and other badge themers) may hook the same methods and load after
// dotto (alphabetical dylib order), so their changes win within a layout pass.
// Re-assert dotto once per pass on the next runloop turn to have the last word.
static BOOL dppReapplyScheduled;
static BOOL dppApplyingBadge;

static void DottoPlusPlusRegisterBadgeView(SBIconBadgeView *badgeView) {
    if (!badgeView) {
        return;
    }
    if (!dppBadgeViews) {
        dppBadgeViews = [NSHashTable weakObjectsHashTable];
    }
    [dppBadgeViews addObject:badgeView];
}

static BOOL DottoPlusPlusShouldOwnBadges(void);
static BOOL DottoPlusPlusBadgeNeedsApply(SBIconBadgeView *badgeView);
static NSArray<SBIconBadgeView *> *DottoPlusPlusCurrentBadgeViews(void);
static SBIconView *DottoPlusPlusIconViewForBadge(SBIconBadgeView *badgeView);
static void DottoPlusPlusInvalidateBadgeHierarchy(SBIconBadgeView *badgeView,
                                                   BOOL layoutImmediately);

static NSString *const DottoNormalBadgePath =
    @"/Library/Application Support/dottoplusplus/badges/normal/SBBadgeBG@3x.png";
static NSString *const DottoCircleBadgePath =
    @"/Library/Application Support/dottoplusplus/badges/circle/SBBadgeBG@3x.png";

// The shipped badge art occupies only the top-right corner of its 95x95 canvas
// (~36x36 px). Crop it to its opaque bounding box so the dot fills the frame.
// Deriving the position from the art itself keeps placement exact if the assets
// ever change.
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

static UIColor *DottoPlusPlusColorFromLayerColor(CGColorRef color) {
    return color ? [UIColor colorWithCGColor:color] : nil;
}

static UIColor *DottoPlusPlusCopyColor(UIColor *color) {
    return color ? [color copy] : nil;
}

static id DottoPlusPlusValueForKeySafely(id object, NSString *key) {
    if (!object || !key.length) {
        return nil;
    }
    @try {
        return [object valueForKey:key];
    } @catch (NSException *exception) {
        (void)exception;
        return nil;
    }
}

static char const kDottoPlusPlusApplicationIconKey;
static char const kDottoPlusPlusInfoProviderKey;
static char const kDottoPlusPlusBadgeStateKey;
static char const kDottoPlusPlusBadgeOverlayKey;

// Declarations for methods implemented by %hook below (Logos emits no class
// interface for hooked classes) or defined in this category.
@interface DottoPlusPlusBadgeState : NSObject
@property (nonatomic, strong) UIImage *backgroundImage;
@property (nonatomic, strong) UIColor *backgroundTintColor;
@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, strong) UIColor *backgroundLayerColor;
@property (nonatomic, assign) CGRect backgroundFrame;
@property (nonatomic, assign) CGPoint backgroundCenter;
@property (nonatomic, assign) CGFloat backgroundAlpha;
@property (nonatomic, strong) UIColor *badgeBackgroundColor;
@property (nonatomic, strong) UIColor *badgeLayerColor;
@property (nonatomic, strong) id badgeLayerContents;
@property (nonatomic, assign) CGRect badgeLayerBounds;
@property (nonatomic, assign) CGPoint badgeLayerPosition;
@property (nonatomic, assign) BOOL hasBadgeLayerGeometry;
@property (nonatomic, strong) NSArray<NSDictionary<NSString *, id> *> *subviewHiddenStates;
@end

@implementation DottoPlusPlusBadgeState
@end

@interface DottoPlusPlusBadgeOverlayView : UIView
@property (nonatomic, strong) UIImageView *imageView;
- (void)configureWithImage:(UIImage *)image
                      color:(UIColor *)color
                      alpha:(CGFloat)alpha
                       size:(CGSize)size
                     center:(CGPoint)center;
@end

@implementation DottoPlusPlusBadgeOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = UIColor.clearColor;
        self.layer.zPosition = 1000.0;
        self.imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        self.imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.imageView.contentMode = UIViewContentModeScaleToFill;
        self.imageView.userInteractionEnabled = NO;
        [self addSubview:self.imageView];
    }
    return self;
}

- (void)configureWithImage:(UIImage *)image
                      color:(UIColor *)color
                      alpha:(CGFloat)alpha
                       size:(CGSize)size
                     center:(CGPoint)center {
    self.frame = CGRectMake(0, 0, size.width, size.height);
    self.center = center;
    self.alpha = alpha;
    self.imageView.image = image;
    self.imageView.tintColor = color;
    self.hidden = NO;
    [self.superview bringSubviewToFront:self];
}

@end

@interface SBIconBadgeView (DottoPlusPlus)

@property (nonatomic, strong) SBApplicationIcon *dottoPlusPlusApplicationIcon;
@property (nonatomic, strong) id dottoPlusPlusInfoProvider;
@property (nonatomic, strong) DottoPlusPlusBadgeState *dottoPlusPlusBadgeState;
@property (nonatomic, strong) DottoPlusPlusBadgeOverlayView *dottoPlusPlusBadgeOverlay;

- (CGSize)badgeSize;
- (void)configureForIcon:(id)icon infoProvider:(id)provider;
- (UIColor *)dottoPlusPlusBadgeColour;
- (void)dottoPlusPlusCaptureStateIfNeededWithBackgroundView:(UIImageView *)backgroundView;
- (void)dottoPlusPlusRestoreState;
- (void)dottoPlusPlusApply;
- (void)dottoPlusPlusRestoreAndReconfigureStock;
- (void)dottoPlusPlusRemoveOverlay;
- (void)_resizeForTextImage:(UIImage *)image;

@end

static void DottoPlusPlusScheduleReapply(void) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            DottoPlusPlusScheduleReapply();
        });
        return;
    }
    if (dppReapplyScheduled) {
        return;
    }
    dppReapplyScheduled = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        dppReapplyScheduled = NO;
        for (SBIconBadgeView *badgeView in DottoPlusPlusCurrentBadgeViews()) {
            if (!DottoPlusPlusBadgeNeedsApply(badgeView)) {
                continue;
            }
            [badgeView dottoPlusPlusApply];
        }
    });
}


// The original badge anchor is a 2pt trailing inset in SBIconView
// coordinates: 60pt icons resolve to (58, 2), while wider dock/large-device
// icon views use their actual width.
static BOOL DottoPlusPlusShouldOwnBadges(void) {
    // The master toggle is the only public ownership control. When disabled,
    // dotto restores its snapshot and SnowBoard/native badges remain visible.
    return [dppPrefs tweakEnabled];
}

static SBIconView *DottoPlusPlusIconViewForBadge(SBIconBadgeView *badgeView) {
    UIView *ancestor = badgeView.superview;
    while (ancestor && ![ancestor isKindOfClass:[SBIconView class]]) {
        ancestor = ancestor.superview;
    }
    return [ancestor isKindOfClass:[SBIconView class]] ? (SBIconView *)ancestor : nil;
}

static CGPoint DottoPlusPlusBadgeCenterForIconWidth(CGFloat iconWidth) {
    // The original dotto anchor leaves a 2pt inset from the icon's trailing
    // edge: 60pt icons resolve to (58, 2), while wider dock/large-device icon
    // views move the dot with their actual bounds.
    if (iconWidth > 0.0) {
        return CGPointMake(iconWidth - 2.0, 2.0);
    }
    return CGPointMake(58, 2);
}

static CGPoint DottoPlusPlusBadgeCenterInSuperview(SBIconBadgeView *badgeView) {
    UIView *superview = badgeView.superview;
    if (!superview) {
        return DottoPlusPlusBadgeCenterForIconWidth(0.0);
    }

    SBIconView *iconView = DottoPlusPlusIconViewForBadge(badgeView);
    CGFloat iconWidth = iconView ? CGRectGetWidth(iconView.bounds) : 0.0;
    CGPoint target = DottoPlusPlusBadgeCenterForIconWidth(iconWidth);
    if (iconView && superview != iconView) {
        target = [iconView convertPoint:target toView:superview];
    }
    return target;
}

static void DottoPlusPlusApplyRootGeometry(SBIconBadgeView *badgeView) {
    if (!badgeView || !badgeView.superview) {
        return;
    }

    CGRect dotBounds = CGRectMake(0, 0, 26, 26);
    CGPoint dotCenter = DottoPlusPlusBadgeCenterInSuperview(badgeView);
    // SBIconBadgeView's public geometry setters can be intercepted by the
    // badge/theming stack. Write the layer geometry last so the actual render
    // container cannot remain zero-sized while our getters report 26×26.
    badgeView.bounds = dotBounds;
    badgeView.center = dotCenter;
    badgeView.layer.bounds = dotBounds;
    badgeView.layer.position = dotCenter;
}

static void DottoPlusPlusInvalidateBadgeHierarchy(SBIconBadgeView *badgeView,
                                                   BOOL layoutImmediately) {
    if (!badgeView) {
        return;
    }
    [badgeView invalidateIntrinsicContentSize];
    [badgeView setNeedsLayout];
    UIView *ancestor = badgeView.superview;
    NSUInteger depth = 0;
    while (ancestor && depth++ < 6) {
        [ancestor setNeedsLayout];
        ancestor = ancestor.superview;
    }
    if (layoutImmediately) {
        SBIconView *iconView = DottoPlusPlusIconViewForBadge(badgeView);
        [iconView layoutIfNeeded];
    }
}

static void DottoPlusPlusCollectBadgeViews(UIView *root,
                                            NSMutableArray<SBIconBadgeView *> *result) {
    if (!root) {
        return;
    }
    if ([root isKindOfClass:[SBIconBadgeView class]]) {
        SBIconBadgeView *badgeView = (SBIconBadgeView *)root;
        if (![result containsObject:badgeView]) {
            [result addObject:badgeView];
        }
        return;
    }
    for (UIView *subview in root.subviews) {
        DottoPlusPlusCollectBadgeViews(subview, result);
    }
}

static BOOL DottoPlusPlusBadgeNeedsApply(SBIconBadgeView *badgeView) {
    if (!badgeView || !DottoPlusPlusShouldOwnBadges()) {
        return NO;
    }

    DottoPlusPlusBadgeOverlayView *overlay = badgeView.dottoPlusPlusBadgeOverlay;
    if (!overlay || overlay.superview != badgeView || overlay.hidden || !overlay.imageView.image) {
        return YES;
    }

    if (badgeView.layer.contents != nil ||
        (badgeView.backgroundColor && ![badgeView.backgroundColor isEqual:UIColor.clearColor])) {
        return YES;
    }

    CGRect expectedBounds = CGRectMake(0, 0, 26, 26);
    if (!CGRectEqualToRect(badgeView.layer.bounds, expectedBounds)) {
        return YES;
    }

    CGPoint expectedCenter = DottoPlusPlusBadgeCenterInSuperview(badgeView);
    CGPoint actualCenter = badgeView.layer.position;
    if (fabs(actualCenter.x - expectedCenter.x) > 0.01 ||
        fabs(actualCenter.y - expectedCenter.y) > 0.01) {
        return YES;
    }

    for (UIView *subview in badgeView.subviews) {
        if (subview != overlay && !subview.hidden) {
            return YES;
        }
    }
    return NO;
}

static void DottoPlusPlusCollectWindowBadgeViews(NSMutableArray<SBIconBadgeView *> *result) {
    if (!result || ![NSThread isMainThread]) {
        return;
    }

    UIApplication *application = UIApplication.sharedApplication;
    BOOL foundWindowScene = NO;
    for (UIScene *scene in application.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }
        foundWindowScene = YES;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            DottoPlusPlusCollectBadgeViews(window, result);
        }
    }

    // UIApplication.windows remains a useful fallback on iOS 15/16 and for
    // the short interval in which SpringBoard has no connected scene yet.
    if (!foundWindowScene) {
        NSArray<UIWindow *> *legacyWindows =
            DottoPlusPlusValueForKeySafely(application, @"windows");
        if ([legacyWindows isKindOfClass:[NSArray class]]) {
            for (UIWindow *window in legacyWindows) {
                DottoPlusPlusCollectBadgeViews(window, result);
            }
        }
    }
}

static NSArray<SBIconBadgeView *> *DottoPlusPlusCurrentBadgeViews(void) {
    NSMutableArray<SBIconBadgeView *> *result = [NSMutableArray array];
    for (SBIconBadgeView *badgeView in dppBadgeViews.allObjects) {
        if (![result containsObject:badgeView]) {
            [result addObject:badgeView];
        }
    }
    DottoPlusPlusCollectWindowBadgeViews(result);
    for (SBIconBadgeView *badgeView in result) {
        [dppBadgeViews addObject:badgeView];
    }
    return result.copy;
}

static void DottoPlusPlusRefreshStockBadgeLayout(SBIconBadgeView *badgeView) {
    if (!badgeView || DottoPlusPlusShouldOwnBadges()) {
        return;
    }
    UIView *textView = DottoPlusPlusValueForKeySafely(badgeView, @"textView");
    UIImage *textImage = DottoPlusPlusValueForKeySafely(textView, @"image");
    if ([textImage isKindOfClass:[UIImage class]] &&
        [badgeView respondsToSelector:@selector(_resizeForTextImage:)]) {
        [badgeView _resizeForTextImage:textImage];
    }
    [badgeView invalidateIntrinsicContentSize];
    [badgeView setNeedsLayout];
    [badgeView.superview setNeedsLayout];
}

static void DottoPlusPlusUpdateBadges(CFNotificationCenterRef center __unused,
                              void *observer __unused,
                              CFStringRef name __unused,
                              const void *object __unused,
                              CFDictionaryRef userInfo __unused) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            [dppPrefs reloadPreferences];
            [dppColourCache removeAllObjects];
            [dppFolderColourCache removeAllObjects];
            NSArray<SBIconBadgeView *> *badgeViews = DottoPlusPlusCurrentBadgeViews();
            for (SBIconBadgeView *badgeView in badgeViews) {
                [badgeView dottoPlusPlusRestoreAndReconfigureStock];
                DottoPlusPlusInvalidateBadgeHierarchy(badgeView, NO);
            }
            DottoPlusPlusScheduleReapply();
        }
    });
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation SBIconBadgeView (DottoPlusPlus)

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

- (DottoPlusPlusBadgeState *)dottoPlusPlusBadgeState {
    return objc_getAssociatedObject(self, &kDottoPlusPlusBadgeStateKey);
}

- (void)setDottoPlusPlusBadgeState:(DottoPlusPlusBadgeState *)dottoPlusPlusBadgeState {
    objc_setAssociatedObject(self, &kDottoPlusPlusBadgeStateKey, dottoPlusPlusBadgeState,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (DottoPlusPlusBadgeOverlayView *)dottoPlusPlusBadgeOverlay {
    return objc_getAssociatedObject(self, &kDottoPlusPlusBadgeOverlayKey);
}

- (void)setDottoPlusPlusBadgeOverlay:(DottoPlusPlusBadgeOverlayView *)dottoPlusPlusBadgeOverlay {
    objc_setAssociatedObject(self, &kDottoPlusPlusBadgeOverlayKey, dottoPlusPlusBadgeOverlay,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)dottoPlusPlusRemoveOverlay {
    DottoPlusPlusBadgeOverlayView *overlay = self.dottoPlusPlusBadgeOverlay;
    [overlay removeFromSuperview];
    self.dottoPlusPlusBadgeOverlay = nil;
}

- (void)dottoPlusPlusCaptureStateIfNeededWithBackgroundView:(UIImageView *)backgroundView {
    if (self.dottoPlusPlusBadgeState || !backgroundView) {
        return;
    }
    DottoPlusPlusBadgeState *state = [DottoPlusPlusBadgeState new];
    state.backgroundImage = backgroundView.image;
    state.backgroundTintColor = DottoPlusPlusCopyColor(backgroundView.tintColor);
    state.backgroundColor = DottoPlusPlusCopyColor(backgroundView.backgroundColor);
    state.backgroundLayerColor = DottoPlusPlusColorFromLayerColor(backgroundView.layer.backgroundColor);
    state.backgroundFrame = backgroundView.frame;
    state.backgroundCenter = backgroundView.center;
    state.backgroundAlpha = backgroundView.alpha;
    state.badgeBackgroundColor = DottoPlusPlusCopyColor(self.backgroundColor);
    state.badgeLayerColor = DottoPlusPlusColorFromLayerColor(self.layer.backgroundColor);
    state.badgeLayerContents = self.layer.contents;
    state.badgeLayerBounds = self.layer.bounds;
    state.badgeLayerPosition = self.layer.position;
    state.hasBadgeLayerGeometry = YES;

    NSMutableArray<NSDictionary<NSString *, id> *> *hiddenStates = [NSMutableArray array];
    for (UIView *subview in self.subviews) {
        [hiddenStates addObject:@{
            @"view" : subview,
            @"hidden" : @(subview.hidden),
        }];
    }
    state.subviewHiddenStates = hiddenStates.copy;
    self.dottoPlusPlusBadgeState = state;
}

- (void)dottoPlusPlusRestoreState {
    [self dottoPlusPlusRemoveOverlay];
    DottoPlusPlusBadgeState *state = self.dottoPlusPlusBadgeState;
    if (!state) {
        return;
    }
    UIImageView *backgroundView = (UIImageView *)DottoPlusPlusValueForKeySafely(self, @"backgroundView");
    if ([backgroundView isKindOfClass:[UIImageView class]]) {
        backgroundView.image = state.backgroundImage;
        backgroundView.tintColor = state.backgroundTintColor;
        backgroundView.backgroundColor = state.backgroundColor;
        backgroundView.layer.backgroundColor = state.backgroundLayerColor.CGColor;
        backgroundView.frame = state.backgroundFrame;
        backgroundView.center = state.backgroundCenter;
        backgroundView.alpha = state.backgroundAlpha;
        [backgroundView setNeedsLayout];
    }
    if (state.hasBadgeLayerGeometry) {
        self.layer.bounds = state.badgeLayerBounds;
        self.layer.position = state.badgeLayerPosition;
    }
    self.backgroundColor = state.badgeBackgroundColor;
    self.layer.backgroundColor = state.badgeLayerColor.CGColor;
    self.layer.contents = state.badgeLayerContents;
    for (NSDictionary<NSString *, id> *entry in state.subviewHiddenStates) {
        UIView *subview = entry[@"view"];
        if ([subview isKindOfClass:[UIView class]]) {
            subview.hidden = [entry[@"hidden"] boolValue];
        }
    }
    [self setNeedsLayout];
    self.dottoPlusPlusBadgeState = nil;
}

// Adaptive colour: force-touch providers and providers without an icon image
// fall back to the user-selected colour; otherwise the icon image's dominant
// colour is used. Folders average the dominant colours of the apps inside them
// (their own contentsImage is nil on iOS 17).

// Folder badge colour: average only the dominant colours of contained app
// icons whose notification badge value is currently positive. The empty case
// returns nil so the caller uses the selected colour; folder artwork is never
// mixed into a badge-only average.
static NSArray<SBIcon *> *DottoPlusPlusBadgedFolderApps(SBFolderIcon *folderIcon) {
    if (!folderIcon.folder) {
        return @[];
    }

    NSMutableArray<SBIcon *> *apps = [NSMutableArray array];
    for (SBIconListModel *list in folderIcon.folder.lists) {
        for (SBIcon *icon in list.icons) {
            if (![icon isKindOfClass:[SBApplicationIcon class]] ||
                [icon isKindOfClass:[SBFolderIcon class]] ||
                icon.badgeValue <= 0) {
                continue;
            }
            [apps addObject:icon];
        }
    }
    return apps.copy;
}

static NSString *DottoPlusPlusFolderColourSignature(NSArray<SBIcon *> *apps) {
    NSMutableString *signature = [NSMutableString stringWithCapacity:apps.count * 24];
    for (SBIcon *icon in apps) {
        NSString *identifier = icon.uniqueIdentifier;
        if (!identifier.length) {
            identifier = [NSString stringWithFormat:@"ptr:%p", (void *)icon];
        }
        [signature appendFormat:@"%@:%lld;", identifier, icon.badgeValue];
    }
    return signature.copy;
}

static UIColor *DottoPlusPlusAverageFolderColour(SBFolderIcon *folderIcon) {
    NSArray<SBIcon *> *apps = DottoPlusPlusBadgedFolderApps(folderIcon);
    if (apps.count == 0) {
        return nil;
    }

    NSString *folderID = folderIcon.uniqueIdentifier;
    NSString *signature = DottoPlusPlusFolderColourSignature(apps);
    NSDictionary<NSString *, id> *cached = folderID.length
        ? dppFolderColourCache[folderID]
        : nil;
    if ([cached[@"signature"] isEqualToString:signature]) {
        id cachedColour = cached[@"colour"];
        return cachedColour == [NSNull null] ? nil : cachedColour;
    }

    struct SBIconImageInfo info;
    info.size = CGSizeMake(60, 60);
    info.scale = 3.0;
    info.continuousCornerRadius = 20.45;
    CGFloat red = 0, green = 0, blue = 0;
    NSUInteger count = 0;
    for (SBIcon *icon in apps) {
        UIImage *image = [icon iconImageWithInfo:info];
        UIColor *colour = [image dottoAverageColor];
        CGFloat r, g, b, a;
        if ([colour getRed:&r green:&g blue:&b alpha:&a]) {
            red += r;
            green += g;
            blue += b;
            count++;
        }
    }

    UIColor *average = count > 0
        ? [UIColor colorWithRed:red / count green:green / count blue:blue / count alpha:1.0]
        : nil;
    if (folderID.length) {
        dppFolderColourCache[folderID] = @{
            @"signature" : signature,
            @"colour" : average ?: [NSNull null],
        };
    }
    return average;
}

- (UIColor *)dottoPlusPlusBadgeColour {
    BOOL isFolder = [self.dottoPlusPlusApplicationIcon isKindOfClass:[SBFolderIcon class]];
    NSString *iconID = self.dottoPlusPlusApplicationIcon.uniqueIdentifier;
    UIColor *cached = (!isFolder && iconID) ? dppColourCache[iconID] : nil;
    if (cached) {
        return cached;
    }
    UIColor *colour = nil;
    if (isFolder) {
        colour = DottoPlusPlusAverageFolderColour((SBFolderIcon *)self.dottoPlusPlusApplicationIcon);
    } else if (![self.dottoPlusPlusInfoProvider isKindOfClass:[SBForceTouchAppIconInfoProvider class]]) {
        UIView *imageView = DottoPlusPlusValueForKeySafely(self.dottoPlusPlusInfoProvider,
                                                            @"iconImageView");
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
    if (!isFolder && iconID) {
        dppColourCache[iconID] = colour;
    }
    return colour;
}

- (void)dottoPlusPlusApply {
    UIImageView *backgroundView = (UIImageView *)DottoPlusPlusValueForKeySafely(self,
                                                                                 @"backgroundView");
    UIView *textView = DottoPlusPlusValueForKeySafely(self, @"textView");
    if (![backgroundView isKindOfClass:[UIImageView class]] ||
        ![textView isKindOfClass:[UIView class]]) {
        return;
    }
    if (dppApplyingBadge) {
        return;
    }

    dppApplyingBadge = YES;
    @try {
        if (!DottoPlusPlusShouldOwnBadges()) {
            [self dottoPlusPlusRestoreState];
            return;
        }

    NSString *selectedPath = [dppPrefs appearanceStyle] != 0 ? DottoCircleBadgePath
                                                               : DottoNormalBadgePath;
    NSString *path = ROOT_PATH_NS(selectedPath);
    NSDictionary *badgeArt = DottoPlusPlusBadgeArt(path);
    UIImage *badgeImage = [badgeArt[@"image"]
                           imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    CGSize artSize = badgeImage.size;
    if (artSize.width < 1.0 || artSize.height < 1.0) {
        artSize = CGSizeMake(26, 26);
    }

    [self dottoPlusPlusCaptureStateIfNeededWithBackgroundView:backgroundView];
    DottoPlusPlusApplyRootGeometry(self);
    DottoPlusPlusBadgeOverlayView *overlay = self.dottoPlusPlusBadgeOverlay;
    if (!overlay) {
        overlay = [[DottoPlusPlusBadgeOverlayView alloc] initWithFrame:CGRectZero];
        self.dottoPlusPlusBadgeOverlay = overlay;
        [self addSubview:overlay];
    }

    UIColor *colour = [dppPrefs adaptiveColorEnabled]
        ? [self dottoPlusPlusBadgeColour]
        : [dppPrefs dottoSelectedColour];
    if ([dppPrefs pastelColorsEnabled]) {
        UIColor *pastelColour = [dppPrefs perceptualPastelColorsEnabled]
            ? [colour dpp_oklabPastelColor]
            : [colour dpp_faithfulPastelColor];
        if (pastelColour) {
            colour = pastelColour;
        }
    }
    [overlay configureWithImage:badgeImage
                           color:colour
                           alpha:[dppPrefs transparency]
                            size:artSize
                          center:[badgeArt[@"center"] CGPointValue]];

    // Keep SnowBoard's objects intact but out of the visible render path. The
    // overlay is the only view dotto++ owns and is always brought frontmost.
    self.layer.contents = nil;
    self.backgroundColor = UIColor.clearColor;
    for (UIView *subview in self.subviews) {
        subview.hidden = (subview != overlay);
    }
        overlay.hidden = NO;
        [self bringSubviewToFront:overlay];
    } @finally {
        dppApplyingBadge = NO;
    }
}

- (void)dottoPlusPlusRestoreAndReconfigureStock {
    BOOL hadState = (self.dottoPlusPlusBadgeState != nil);
    SBApplicationIcon *icon = self.dottoPlusPlusApplicationIcon;
    id provider = self.dottoPlusPlusInfoProvider;
    [self dottoPlusPlusRestoreState];
    if (!hadState) {
        [self dottoPlusPlusApply];
        DottoPlusPlusRefreshStockBadgeLayout(self);
        return;
    }
    if (icon && provider) {
        [self configureForIcon:icon infoProvider:provider];
    } else {
        [self dottoPlusPlusApply];
        DottoPlusPlusRefreshStockBadgeLayout(self);
    }
}

@end

#pragma clang diagnostic pop

#pragma mark - Hooks

%hook SBIconBadgeView

- (id)init {
    self = %orig;
    DottoPlusPlusRegisterBadgeView(self);
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = %orig;
    DottoPlusPlusRegisterBadgeView(self);
    return self;
}

- (void)_applyParallaxSettings {
    %orig;
    if (dppApplyingBadge) {
        return;
    }
    BOOL needsApply = DottoPlusPlusBadgeNeedsApply(self);
    if (needsApply) {
        [self dottoPlusPlusApply];
        DottoPlusPlusScheduleReapply();
    }
}

- (CGRect)bounds {
    if (DottoPlusPlusShouldOwnBadges()) {
        return CGRectMake(0, 0, 26, 26);
    }
    return %orig;
}

- (CGPoint)center {
    if (DottoPlusPlusShouldOwnBadges()) {
        return DottoPlusPlusBadgeCenterInSuperview(self);
    }
    return %orig;
}

- (CGSize)badgeSize {
    if (DottoPlusPlusShouldOwnBadges()) {
        return CGSizeMake(26, 26);
    }
    return %orig;
}

- (CGSize)sizeThatFits:(CGSize)size {
    if (DottoPlusPlusShouldOwnBadges()) {
        return [self badgeSize];
    }
    return %orig;
}

- (CGSize)intrinsicContentSize {
    if (DottoPlusPlusShouldOwnBadges()) {
        return [self badgeSize];
    }
    return %orig;
}

- (CGSize)intrinsicContentSizeForTextImage:(UIImage *)textImage {
    if (!DottoPlusPlusShouldOwnBadges()) {
        return %orig;
    }
    return CGSizeZero;
}

- (void)_resizeForTextImage:(UIImage *)image {
    if (!DottoPlusPlusShouldOwnBadges()) {
        %orig;
    }
}

- (void)_crossfadeToTextImage:(UIImage *)image animator:(id)animator {
    if (!DottoPlusPlusShouldOwnBadges()) {
        %orig;
    }
}

- (void)_zoomInWithTextImage:(UIImage *)image animator:(id)animator {
    if (!DottoPlusPlusShouldOwnBadges()) {
        %orig;
    }
}

- (void)layoutSubviews {
    %orig;
    if (dppApplyingBadge || !DottoPlusPlusBadgeNeedsApply(self)) {
        return;
    }
    [self dottoPlusPlusApply];
}

- (void)configureAnimatedForIcon:(id)icon infoProvider:(id)provider animator:(id)animator {
    if (DottoPlusPlusShouldOwnBadges()) {
        [self configureForIcon:icon infoProvider:provider];
    } else {
        [self dottoPlusPlusRestoreState];
        %orig;
        DottoPlusPlusRefreshStockBadgeLayout(self);
    }
}

- (void)configureForIcon:(id)icon infoProvider:(id)provider {
    NSString *oldIconID = self.dottoPlusPlusApplicationIcon.uniqueIdentifier;
    if (oldIconID) {
        [dppColourCache removeObjectForKey:oldIconID];
    }
    // A child icon reconfiguration can change the folder's dominant colour
    // without changing its badge membership signature.
    [dppFolderColourCache removeAllObjects];
    [self dottoPlusPlusRestoreState];
    %orig;
    self.dottoPlusPlusApplicationIcon = icon;
    self.dottoPlusPlusInfoProvider = provider;
    NSString *newIconID = [icon respondsToSelector:@selector(uniqueIdentifier)] ? [icon uniqueIdentifier] : nil;
    if (newIconID) {
        [dppColourCache removeObjectForKey:newIconID];
    }
    [self dottoPlusPlusApply];
    DottoPlusPlusRefreshStockBadgeLayout(self);
    DottoPlusPlusInvalidateBadgeHierarchy(self, NO);
    DottoPlusPlusScheduleReapply();
}

%end

%hook SBIconView

- (CGPoint)_centerForAccessoryView {
    if (DottoPlusPlusShouldOwnBadges()) {
        return DottoPlusPlusBadgeCenterForIconWidth(CGRectGetWidth(self.bounds));
    }
    return %orig;
}

%end

// iOS 17 accessory positioning protocol method (stock badges position themselves
// via this); keep it out of iOS 15/16 hook installation.
%group DottoPlusPlusIOS17
%hook SBIconView

- (CGPoint)accessoryCenterForIconBounds:(CGRect)iconBounds {
    if (DottoPlusPlusShouldOwnBadges()) {
        return DottoPlusPlusBadgeCenterForIconWidth(CGRectGetWidth(iconBounds));
    }
    return %orig;
}

%end
%end

#pragma mark - Constructor

%ctor {
    @autoreleasepool {
        dppBadgeViews = [NSHashTable weakObjectsHashTable];
        dppColourCache = [NSMutableDictionary dictionary];
        dppFolderColourCache = [NSMutableDictionary dictionary];
        dppPrefs = [DottoPlusPlusPreferences sharedInstance];
        [dppPrefs reloadPreferences];
        dispatch_async(dispatch_get_main_queue(), ^{
            %init;
            if (@available(iOS 17.0, *)) {
                %init(DottoPlusPlusIOS17);
            }
        });
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL, DottoPlusPlusUpdateBadges,
                                        (CFStringRef)DottoPlusPlusReloadNotification,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
    }
}
