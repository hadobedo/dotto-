// dotto+ — iOS 17 rebuild.
// Faithful port of dotto.dylib 1.0.6 (see ANALYSIS.md for the full decompilation).
// Changes for iOS 17:
//  - _frameForAccessoryView: hook removed (selector gone from SBIconView)
//  - accessoryCenterForIconBounds: hook added (iOS 17 accessory positioning protocol)
//  - stock restore uses a captured stock background image instead of the removed
//    backgroundImageTuple KVC path (which would throw NSUndefinedKeyException)

#import "DottoPrivate.h"

#import <objc/runtime.h>

#import "DottoPreferences.h"
#import "UIColor+dotto.h"

static NSMutableArray *dottoBadgeViews;
static DottoPreferences *dottoPrefs;

static NSString *const DottoReloadNotification = @"me.conorthedev.dotto/ReloadPrefs";
static NSString *const DottoNormalBadgePath =
    @"/Library/Application Support/dotto/badges/normal/SBBadgeBG@3x.png";
static NSString *const DottoCircleBadgePath =
    @"/Library/Application Support/dotto/badges/circle/SBBadgeBG@3x.png";

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

// Adaptive colour: folder icons, force-touch providers and providers without an
// icon image fall back to the user-selected colour; otherwise the icon image's
// dominant colour is used.
- (UIColor *)dottoBadgeColour {
    if ([self.dottoApplicationIcon isKindOfClass:[SBFolderIcon class]]) {
        return [dottoPrefs dottoSelectedColour];
    }
    if ([self.dottoInfoProvider isKindOfClass:[SBForceTouchAppIconInfoProvider class]]) {
        return [dottoPrefs dottoSelectedColour];
    }
    UIView *imageView = [self.dottoInfoProvider valueForKey:@"iconImageView"];
    if ([imageView respondsToSelector:@selector(contentsImage)]) {
        UIImage *contentsImage = [(SBIconImageView *)imageView contentsImage];
        if (contentsImage) {
            return [contentsImage dottoAverageColor];
        }
    }
    return [dottoPrefs dottoSelectedColour];
}

- (void)applyDotto {
    UIImageView *backgroundView = [self valueForKey:@"backgroundView"];
    UIImageView *textView = [self valueForKey:@"textView"];

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

    NSString *path = [dottoPrefs appearanceStyle] != 0 ? DottoCircleBadgePath
                                                       : DottoNormalBadgePath;
    UIImage *badgeImage = [[UIImage imageWithContentsOfFile:path]
                           imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

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
    [backgroundView setFrame:CGRectMake(0, 0, 26, 26)];
    [backgroundView setCenter:CGPointMake(13, 13)];
    [backgroundView setAlpha:[dottoPrefs transparency]];
    [textView setHidden:YES];
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
    self.dottoApplicationIcon = icon;
    self.dottoInfoProvider = provider;
    [self applyDotto];
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
    }
}
